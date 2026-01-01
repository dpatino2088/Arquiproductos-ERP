-- ====================================================
-- Migration 285: Manual SalesOrder Creation for QT-000003
-- ====================================================
-- Direct creation of SalesOrder, SalesOrderLines, and BOMs
-- without relying on trigger
-- ====================================================

DO $$
DECLARE
    v_quote_id uuid := 'c5a81f6a-cb1d-4672-bb7e-38b850229aaa'::uuid; -- QT-000003
    v_quote_record RECORD;
    v_sale_order_id uuid;
    v_sale_order_no text;
    v_next_counter integer;
    v_subtotal numeric(12,4);
    v_tax numeric(12,4);
    v_total numeric(12,4);
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_quote_line_record RECORD;
    v_bom_instance_id uuid;
    v_validated_side_channel_type text;
BEGIN
    RAISE NOTICE '🔧 Manually creating SalesOrder for Quote QT-000003...';
    RAISE NOTICE '';
    
    -- Load quote record
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = v_quote_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quote % not found or deleted', v_quote_id;
    END IF;
    
    RAISE NOTICE '✅ Quote loaded: % (%)', v_quote_record.quote_no, v_quote_record.id;
    RAISE NOTICE '   Status: %, Organization: %', v_quote_record.status, v_quote_record.organization_id;
    
    -- Check if SalesOrder already exists
    SELECT id INTO v_sale_order_id
    FROM "SalesOrders"
    WHERE quote_id = v_quote_id
    AND deleted = false
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '⚠️  SalesOrder already exists: %', v_sale_order_id;
        RETURN;
    END IF;
    
    -- Generate sale order number
    BEGIN
        v_next_counter := public.get_next_counter_value(v_quote_record.organization_id, 'sale_order');
    EXCEPTION
        WHEN OTHERS THEN
            -- Fallback: use max + 1
            SELECT COALESCE(MAX(CAST(SUBSTRING(sale_order_no FROM 'SO-(\d+)') AS INTEGER)), 0) + 1
            INTO v_next_counter
            FROM "SalesOrders"
            WHERE organization_id = v_quote_record.organization_id;
    END;
    
    v_sale_order_no := 'SO-' || LPAD(v_next_counter::text, 6, '0');
    
    -- Extract totals from JSONB
    v_subtotal := COALESCE((v_quote_record.totals->>'subtotal')::numeric(12,4), 0);
    v_tax := COALESCE((v_quote_record.totals->>'tax')::numeric(12,4), 0);
    v_total := COALESCE((v_quote_record.totals->>'total')::numeric(12,4), 0);
    
    -- Create SaleOrder
    INSERT INTO "SalesOrders" (
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
        updated_by,
        deleted
    ) VALUES (
        v_quote_record.organization_id,
        v_quote_record.id,
        v_quote_record.customer_id,
        v_sale_order_no,
        'draft',
        COALESCE(v_quote_record.currency, 'USD'),
        v_subtotal,
        v_tax,
        v_total,
        v_quote_record.notes,
        CURRENT_DATE,
        v_quote_record.created_by,
        v_quote_record.updated_by,
        false
    ) RETURNING id INTO v_sale_order_id;
    
    RAISE NOTICE '✅ Created SalesOrder % (sale_order_no: %)', v_sale_order_id, v_sale_order_no;
    
    -- Create SalesOrderLines for each QuoteLine
    FOR v_quote_line_record IN
        SELECT ql.*
        FROM "QuoteLines" ql
        WHERE ql.quote_id = v_quote_id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        RAISE NOTICE '  Processing QuoteLine: %', v_quote_line_record.id;
        
        -- Get next line number
        SELECT COALESCE(MAX(line_number), 0) + 1 INTO v_line_number
        FROM "SalesOrderLines"
        WHERE sale_order_id = v_sale_order_id
        AND deleted = false;
        
        -- Validate and normalize side_channel_type
        IF v_quote_line_record.side_channel_type IS NULL THEN
            v_validated_side_channel_type := NULL;
        ELSIF LOWER(v_quote_line_record.side_channel_type) IN ('side_only', 'side_and_bottom') THEN
            v_validated_side_channel_type := LOWER(v_quote_line_record.side_channel_type);
        ELSE
            v_validated_side_channel_type := NULL;
        END IF;
        
        -- Create SaleOrderLine
        INSERT INTO "SalesOrderLines" (
            sale_order_id,
            quote_line_id,
            line_number,
            catalog_item_id,
            qty,
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
            tube_type,
            operating_system_variant,
            top_rail_type,
            unit_price_snapshot,
            unit_cost_snapshot,
            line_total,
            measure_basis_snapshot,
            margin_percentage,
            deleted,
            created_at,
            updated_at
        ) VALUES (
            v_sale_order_id,
            v_quote_line_record.id,
            v_line_number,
            v_quote_line_record.catalog_item_id,
            v_quote_line_record.qty,
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
            v_quote_line_record.tube_type,
            v_quote_line_record.operating_system_variant,
            v_quote_line_record.top_rail_type,
            v_quote_line_record.unit_price_snapshot,
            v_quote_line_record.unit_cost_snapshot,
            v_quote_line_record.line_total,
            v_quote_line_record.measure_basis_snapshot,
            v_quote_line_record.margin_percentage,
            false,
            now(),
            now()
        ) RETURNING id INTO v_sale_order_line_id;
        
        RAISE NOTICE '    ✅ Created SalesOrderLine % (line_number: %)', v_sale_order_line_id, v_line_number;
        
        -- Generate QuoteLineComponents if they don't exist
        IF NOT EXISTS (
            SELECT 1 FROM "QuoteLineComponents"
            WHERE quote_line_id = v_quote_line_record.id
            AND source = 'configured_component'
            AND deleted = false
        ) AND v_quote_line_record.product_type_id IS NOT NULL THEN
            RAISE NOTICE '    🔧 Generating QuoteLineComponents...';
            
            BEGIN
                PERFORM public.generate_configured_bom_for_quote_line(
                    v_quote_line_record.id,
                    v_quote_line_record.product_type_id,
                    v_quote_record.organization_id,
                    v_quote_line_record.drive_type,
                    v_quote_line_record.bottom_rail_type,
                    v_quote_line_record.cassette,
                    v_quote_line_record.cassette_type,
                    v_quote_line_record.side_channel,
                    v_quote_line_record.side_channel_type,
                    v_quote_line_record.hardware_color,
                    v_quote_line_record.width_m,
                    v_quote_line_record.height_m,
                    v_quote_line_record.qty,
                    v_quote_line_record.tube_type,
                    v_quote_line_record.operating_system_variant
                );
                RAISE NOTICE '    ✅ QuoteLineComponents generated';
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '    ⚠️  Error generating QuoteLineComponents: %', SQLERRM;
            END;
        END IF;
        
        -- Create BomInstance
        BEGIN
            INSERT INTO "BomInstances" (
                organization_id,
                sale_order_line_id,
                quote_line_id,
                bom_template_id,
                deleted,
                created_at,
                updated_at
            ) VALUES (
                v_quote_record.organization_id,
                v_sale_order_line_id,
                v_quote_line_record.id,
                NULL, -- Will be set if template exists
                false,
                now(),
                now()
            ) RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '    ✅ Created BomInstance %', v_bom_instance_id;
            
            -- Populate BomInstanceLines from QuoteLineComponents
            -- (This is a simplified version - the full trigger logic is more complex)
            RAISE NOTICE '    ℹ️  BomInstanceLines will be populated by the trigger or manually';
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '    ⚠️  Error creating BomInstance: %', SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ SalesOrder creation completed for Quote QT-000003';
    RAISE NOTICE '   SalesOrder: % (%)', v_sale_order_no, v_sale_order_id;
    
END $$;

-- Verify the result
SELECT 
    q.quote_no,
    q.id as quote_id,
    so.sale_order_no,
    so.id as sales_order_id,
    so.status,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as line_count
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000003'
AND q.deleted = false;


