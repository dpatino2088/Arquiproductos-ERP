-- ====================================================
-- Quick Fix: Create SaleOrder for QT-000025
-- ====================================================
-- This script creates a SaleOrder for the specific approved quote
-- ====================================================

DO $$
DECLARE
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_next_number integer;
    v_last_order_no text;
    v_organization_id uuid;
    v_line_number integer;
    v_quote_line_record RECORD;
    v_sale_order_line_id uuid;
    v_validated_side_channel_type text;
BEGIN
    -- Get the specific quote
    SELECT 
        q.id,
        q.organization_id,
        q.customer_id,
        q.quote_no,
        q.currency,
        q.totals,
        q.notes,
        q.created_by,
        q.updated_by
    INTO v_quote_record
    FROM "Quotes" q
    WHERE q.quote_no = 'QT-000025'
    AND q.status = 'approved'
    AND q.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quote QT-000025 not found or not approved';
    END IF;
    
    -- Check if SaleOrder already exists
    SELECT id INTO v_sale_order_id
    FROM "SaleOrders"
    WHERE quote_id = v_quote_record.id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '✅ SaleOrder already exists for QT-000025: %', v_sale_order_id;
        RETURN;
    END IF;
    
    v_organization_id := v_quote_record.organization_id;
    
    -- Generate sale_order_no
    IF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'get_next_document_number' 
        AND pronamespace = 'public'::regnamespace
    ) THEN
        SELECT public.get_next_document_number(v_organization_id, 'SO') INTO v_sale_order_no;
        RAISE NOTICE '📝 Using get_next_document_number: %', v_sale_order_no;
    ELSE
        SELECT sale_order_no INTO v_last_order_no
        FROM "SaleOrders"
        WHERE organization_id = v_organization_id
        AND deleted = false
        ORDER BY created_at DESC
        LIMIT 1;

        IF v_last_order_no IS NULL THEN
            v_next_number := 1;
        ELSE
            v_next_number := COALESCE(
                (SELECT (regexp_match(v_last_order_no, 'SO-(\d+)'))[1]::integer),
                0
            ) + 1;
        END IF;

        v_sale_order_no := 'SO-' || LPAD(v_next_number::text, 6, '0');
        RAISE NOTICE '📝 Using manual generation: %', v_sale_order_no;
    END IF;
    
    -- Create SaleOrder
    INSERT INTO "SaleOrders" (
        organization_id,
        quote_id,
        customer_id,
        sale_order_no,
        status,
        order_progress_status,
        currency,
        subtotal,
        tax,
        total,
        notes,
        order_date,
        created_by,
        updated_by
    ) VALUES (
        v_quote_record.organization_id,
        v_quote_record.id,
        v_quote_record.customer_id,
        v_sale_order_no,
        'Draft',
        'approved_awaiting_confirmation',
        COALESCE(v_quote_record.currency, 'USD'),
        COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0),
        COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0),
        COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0),
        v_quote_record.notes,
        CURRENT_DATE,
        COALESCE(v_quote_record.created_by, auth.uid()),
        COALESCE(v_quote_record.updated_by, auth.uid())
    ) RETURNING id INTO v_sale_order_id;
    
    RAISE NOTICE '✅ Created SaleOrder % (%) for Quote QT-000025', 
        v_sale_order_id, v_sale_order_no;
    
    -- Create SaleOrderLines
    v_line_number := 1;
    FOR v_quote_line_record IN
        SELECT ql.*
        FROM "QuoteLines" ql
        WHERE ql.quote_id = v_quote_record.id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        SELECT id INTO v_sale_order_line_id
        FROM "SaleOrderLines"
        WHERE sale_order_id = v_sale_order_id
        AND quote_line_id = v_quote_line_record.id
        AND deleted = false
        LIMIT 1;
        
        IF v_sale_order_line_id IS NULL THEN
            IF v_quote_line_record.side_channel_type IS NULL THEN
                v_validated_side_channel_type := NULL;
            ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
            ELSE
                v_validated_side_channel_type := NULL;
            END IF;
            
            INSERT INTO "SaleOrderLines" (
                organization_id,
                sale_order_id,
                quote_line_id,
                catalog_item_id,
                line_number,
                description,
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
                metadata,
                created_by,
                updated_by
            ) VALUES (
                v_quote_record.organization_id,
                v_sale_order_id,
                v_quote_line_record.id,
                v_quote_line_record.catalog_item_id,
                v_line_number,
                v_quote_line_record.description,
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
                v_validated_side_channel_type,
                v_quote_line_record.hardware_color,
                v_quote_line_record.metadata,
                COALESCE(v_quote_record.created_by, auth.uid()),
                COALESCE(v_quote_record.updated_by, auth.uid())
            );
            
            RAISE NOTICE '✅ Created SaleOrderLine % for QuoteLine %', v_line_number, v_quote_line_record.id;
            v_line_number := v_line_number + 1;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Successfully created SaleOrder % with % lines for QT-000025', 
        v_sale_order_no, v_line_number - 1;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error: %', SQLERRM;
        RAISE WARNING '❌ SQL State: %', SQLSTATE;
        RAISE;
END;
$$;

-- Verify the result
SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.status AS quote_status,
    so.id AS sale_order_id,
    so.sale_order_no,
    so.status AS sale_order_status,
    so.order_progress_status,
    (SELECT COUNT(*) FROM "SaleOrderLines" WHERE sale_order_id = so.id AND deleted = false) AS line_count
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000025'
AND q.deleted = false;








