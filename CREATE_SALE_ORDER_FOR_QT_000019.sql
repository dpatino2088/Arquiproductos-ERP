-- ====================================================
-- Create SaleOrder for QT-000019
-- ====================================================
-- This script creates a SaleOrder for the specific quote QT-000019
-- ====================================================

DO $$
DECLARE
    v_quote RECORD;
    v_so_id uuid;
    v_so_no text;
    v_next_num integer;
    v_last_no text;
    v_org_id uuid;
    v_line_num integer;
    v_ql RECORD;
    v_sol_id uuid;
    v_side_channel_type text;
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
    INTO v_quote
    FROM "Quotes" q
    WHERE q.quote_no = 'QT-000019'
    AND q.status = 'approved'
    AND q.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quote QT-000019 not found or not approved';
    END IF;
    
    -- Check if SaleOrder already exists
    SELECT id INTO v_so_id
    FROM "SaleOrders"
    WHERE quote_id = v_quote.id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '✅ SaleOrder already exists for QT-000019: %', v_so_id;
        RETURN;
    END IF;
    
    v_org_id := v_quote.organization_id;
    RAISE NOTICE '📝 Quote organization_id: %', v_org_id;
    
    -- Generate sale order number
    IF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'get_next_document_number'
    ) THEN
        SELECT public.get_next_document_number(v_org_id, 'SO') INTO v_so_no;
        RAISE NOTICE '📝 Using get_next_document_number: %', v_so_no;
    ELSE
        SELECT sale_order_no INTO v_last_no
        FROM "SaleOrders"
        WHERE organization_id = v_org_id
        AND deleted = false
        ORDER BY created_at DESC
        LIMIT 1;

        IF v_last_no IS NULL THEN
            v_next_num := 1;
        ELSE
            v_next_num := COALESCE(
                (SELECT (regexp_match(v_last_no, 'SO-(\d+)'))[1]::integer), 0
            ) + 1;
        END IF;

        v_so_no := 'SO-' || LPAD(v_next_num::text, 6, '0');
        RAISE NOTICE '📝 Using manual generation: %', v_so_no;
    END IF;
    
    RAISE NOTICE '📝 Creating SaleOrder % for Quote QT-000019...', v_so_no;
    
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
        v_quote.organization_id,
        v_quote.id,
        v_quote.customer_id,
        v_so_no,
        'Draft',
        'approved_awaiting_confirmation',
        COALESCE(v_quote.currency, 'USD'),
        COALESCE((v_quote.totals->>'subtotal')::numeric(12,4), 0),
        COALESCE((v_quote.totals->>'tax')::numeric(12,4), 0),
        COALESCE((v_quote.totals->>'total')::numeric(12,4), 0),
        v_quote.notes,
        CURRENT_DATE,
        COALESCE(v_quote.created_by, auth.uid()),
        COALESCE(v_quote.updated_by, auth.uid())
    ) RETURNING id INTO v_so_id;
    
    RAISE NOTICE '✅ Created SaleOrder % (%)', v_so_id, v_so_no;
    
    -- Create SaleOrderLines
    v_line_num := 1;
    FOR v_ql IN
        SELECT * FROM "QuoteLines"
        WHERE quote_id = v_quote.id
        AND deleted = false
        ORDER BY created_at ASC
    LOOP
        SELECT id INTO v_sol_id
        FROM "SaleOrderLines"
        WHERE sale_order_id = v_so_id
        AND quote_line_id = v_ql.id
        AND deleted = false
        LIMIT 1;
        
        IF v_sol_id IS NULL THEN
            IF v_ql.side_channel_type IS NULL THEN
                v_side_channel_type := NULL;
            ELSIF LOWER(v_ql.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
                v_side_channel_type := LOWER(v_ql.side_channel_type);
            ELSE
                v_side_channel_type := NULL;
            END IF;
            
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
                metadata,
                created_by,
                updated_by
            ) VALUES (
                v_quote.organization_id,
                v_so_id,
                v_ql.id,
                v_ql.catalog_item_id,
                v_line_num,
                v_ql.qty,
                v_ql.unit_price_snapshot,
                v_ql.line_total,
                v_ql.width_m,
                v_ql.height_m,
                v_ql.area,
                v_ql.position,
                v_ql.collection_name,
                v_ql.variant_name,
                v_ql.product_type,
                v_ql.product_type_id,
                v_ql.drive_type,
                v_ql.bottom_rail_type,
                v_ql.cassette,
                v_ql.cassette_type,
                v_ql.side_channel,
                v_side_channel_type,
                v_ql.hardware_color,
                v_ql.metadata,
                COALESCE(v_quote.created_by, auth.uid()),
                COALESCE(v_quote.updated_by, auth.uid())
            );
            
            RAISE NOTICE '✅ Created SaleOrderLine %', v_line_num;
            v_line_num := v_line_num + 1;
        END IF;
    END LOOP;
    
    RAISE NOTICE '✅ Successfully created SaleOrder % with % line(s) for QT-000019', 
        v_so_no, v_line_num - 1;
    
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
    so.organization_id AS so_org_id,
    q.organization_id AS quote_org_id,
    (SELECT COUNT(*) FROM "SaleOrderLines" WHERE sale_order_id = so.id AND deleted = false) AS line_count
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000019'
AND q.deleted = false;

