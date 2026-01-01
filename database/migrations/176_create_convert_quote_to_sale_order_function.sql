-- ====================================================
-- Migration: Create function to convert approved Quote to Sale Order
-- ====================================================
-- This function creates a Sale Order from an approved Quote, copying all QuoteLines to SaleOrderLines
-- ====================================================

CREATE OR REPLACE FUNCTION public.convert_quote_to_sale_order(
    p_quote_id uuid,
    p_organization_id uuid,
    p_user_id uuid DEFAULT auth.uid()
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_line_number integer := 1;
    v_quote_line_record RECORD;
    v_subtotal numeric(12,4) := 0;
    v_tax numeric(12,4) := 0;
    v_total numeric(12,4) := 0;
    v_last_order_no text;
    v_next_number integer;
BEGIN
    -- Step 1: Validate quote exists and is approved
    SELECT 
        q.id,
        q.organization_id,
        q.customer_id,
        q.quote_no,
        q.status,
        q.currency,
        q.totals,
        q.notes
    INTO v_quote_record
    FROM "Quotes" q
    WHERE q.id = p_quote_id
    AND q.organization_id = p_organization_id
    AND q.deleted = false;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quote with id % not found or does not belong to organization %', p_quote_id, p_organization_id;
    END IF;

    IF v_quote_record.status != 'approved' THEN
        RAISE EXCEPTION 'Quote % is not approved. Current status: %', p_quote_id, v_quote_record.status;
    END IF;

    -- Step 2: Check if Sale Order already exists for this Quote
    -- If it exists (created by trigger), return it instead of raising an error
    SELECT id INTO v_sale_order_id
    FROM "SaleOrders"
    WHERE quote_id = p_quote_id
    AND organization_id = p_organization_id
    AND deleted = false
    LIMIT 1;

    IF FOUND THEN
        -- Sale Order already exists (probably created by trigger), return it
        RAISE NOTICE 'Sale Order already exists for Quote %. Returning existing Sale Order ID: %', p_quote_id, v_sale_order_id;
        RETURN v_sale_order_id;
    END IF;

    -- Step 3: Generate sale order number using get_next_counter_value (same as trigger)
    -- Check if get_next_counter_value function exists
    IF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'get_next_counter_value' 
        AND pronamespace = 'public'::regnamespace
    ) THEN
        -- Use the safe counter function
        v_next_number := public.get_next_counter_value(p_organization_id, 'sale_order');
        v_sale_order_no := 'SO-' || LPAD(v_next_number::text, 6, '0');
    ELSE
        -- Fallback: Generate sale order number manually (legacy method)
        SELECT sale_order_no INTO v_last_order_no
        FROM "SaleOrders"
        WHERE organization_id = p_organization_id
        AND deleted = false
        ORDER BY created_at DESC
        LIMIT 1;

        IF v_last_order_no IS NULL THEN
            v_next_number := 1;
        ELSE
            -- Extract number from format SO-000001
            v_next_number := COALESCE(
                (SELECT (regexp_match(v_last_order_no, 'SO-(\d+)'))[1]::integer),
                0
            ) + 1;
        END IF;

        v_sale_order_no := 'SO-' || LPAD(v_next_number::text, 6, '0');
    END IF;

    -- Step 4: Extract totals from JSONB
    v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
    v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
    v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);

    -- Step 5: Create Sale Order
    INSERT INTO "SaleOrders" (
        organization_id,
        quote_id,
        customer_id,
        sale_order_no,
        status,
        currency,
        subtotal,
        tax,
        total,
        notes,
        order_date,
        created_by,
        updated_by
    ) VALUES (
        p_organization_id,
        p_quote_id,
        v_quote_record.customer_id,
        v_sale_order_no,
        'Draft',
        v_quote_record.currency,
        v_subtotal,
        v_tax,
        v_total,
        v_quote_record.notes,
        CURRENT_DATE,
        p_user_id,
        p_user_id
    ) RETURNING id INTO v_sale_order_id;

    -- Step 6: Copy QuoteLines to SaleOrderLines
    FOR v_quote_line_record IN
        SELECT 
            ql.id,
            ql.catalog_item_id,
            ql.qty,
            ql.width_m,
            ql.height_m,
            ql.area,
            ql.position,
            ql.collection_name,
            ql.variant_name,
            ql.product_type,
            ql.product_type_id,
            ql.drive_type,
            ql.bottom_rail_type,
            ql.cassette,
            ql.cassette_type,
            ql.side_channel,
            ql.side_channel_type,
            ql.hardware_color,
            ql.unit_price_snapshot,
            ql.line_total
        FROM "QuoteLines" ql
        WHERE ql.quote_id = p_quote_id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        INSERT INTO "SaleOrderLines" (
            organization_id,
            sale_order_id,
            quote_line_id,
            catalog_item_id,
            line_number,
            qty,
            unit_price,
            line_total,
            width_m,
            height_m,
            area,
            position,
            collection_name,
            variant_name,
            product_type,
            product_type_id,
            drive_type,
            bottom_rail_type,
            cassette,
            cassette_type,
            side_channel,
            side_channel_type,
            hardware_color,
            created_by,
            updated_by
        ) VALUES (
            p_organization_id,
            v_sale_order_id,
            v_quote_line_record.id,
            v_quote_line_record.catalog_item_id,
            v_line_number,
            v_quote_line_record.qty,
            v_quote_line_record.unit_price_snapshot,
            v_quote_line_record.line_total,
            v_quote_line_record.width_m,
            v_quote_line_record.height_m,
            v_quote_line_record.area,
            v_quote_line_record.position,
            v_quote_line_record.collection_name,
            v_quote_line_record.variant_name,
            v_quote_line_record.product_type,
            v_quote_line_record.product_type_id,
            v_quote_line_record.drive_type,
            v_quote_line_record.bottom_rail_type,
            v_quote_line_record.cassette,
            v_quote_line_record.cassette_type,
            v_quote_line_record.side_channel,
            v_quote_line_record.side_channel_type,
            v_quote_line_record.hardware_color,
            p_user_id,
            p_user_id
        );

        v_line_number := v_line_number + 1;
    END LOOP;

    -- Step 7: Return Sale Order ID
    RETURN v_sale_order_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error in convert_quote_to_sale_order for Quote %: %', p_quote_id, SQLERRM;
        RAISE;
END;
$$;

COMMENT ON FUNCTION public.convert_quote_to_sale_order IS 
'Converts an approved Quote to a Sale Order, copying all QuoteLines to SaleOrderLines. Returns the new Sale Order ID.';

-- ====================================================
-- Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Created:';
    RAISE NOTICE '   - Function: convert_quote_to_sale_order(uuid, uuid, uuid)';
END $$;


