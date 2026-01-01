-- ====================================================
-- Migration 288: Complete SalesOrderLines and BOMs for QT-000003
-- ====================================================
-- Creates SalesOrderLines and BOMs for the SalesOrder we just created
-- ====================================================

DO $$
DECLARE
    v_quote_id uuid := 'c5a81f6a-cb1d-4672-bb7e-38b850229aaa'::uuid; -- QT-000003
    v_sale_order_id uuid;
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_quote_line_record RECORD;
    v_bom_instance_id uuid;
    v_validated_side_channel_type text;
    v_created_lines integer := 0;
    v_created_boms integer := 0;
BEGIN
    RAISE NOTICE '🔧 Completing SalesOrderLines and BOMs for QT-000003...';
    RAISE NOTICE '';
    
    -- Get the SalesOrder ID
    SELECT id INTO v_sale_order_id
    FROM "SalesOrders"
    WHERE quote_id = v_quote_id
    AND deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SalesOrder not found for Quote %', v_quote_id;
    END IF;
    
    RAISE NOTICE '✅ Found SalesOrder: %', v_sale_order_id;
    
    -- Create SalesOrderLines for each QuoteLine
    FOR v_quote_line_record IN
        SELECT ql.*
        FROM "QuoteLines" ql
        WHERE ql.quote_id = v_quote_id
        AND ql.deleted = false
        ORDER BY ql.created_at ASC
    LOOP
        -- Check if SalesOrderLine already exists
        IF EXISTS (
            SELECT 1 FROM "SalesOrderLines"
            WHERE sale_order_id = v_sale_order_id
            AND quote_line_id = v_quote_line_record.id
            AND deleted = false
        ) THEN
            RAISE NOTICE '  ⏭️  SalesOrderLine already exists for QuoteLine %', v_quote_line_record.id;
            CONTINUE;
        END IF;
        
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
        BEGIN
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
            
            RAISE NOTICE '  ✅ Created SalesOrderLine % (line_number: %)', v_sale_order_line_id, v_line_number;
            v_created_lines := v_created_lines + 1;
            
            -- Generate QuoteLineComponents if they don't exist
            IF NOT EXISTS (
                SELECT 1 FROM "QuoteLineComponents"
                WHERE quote_line_id = v_quote_line_record.id
                AND source = 'configured_component'
                AND deleted = false
            ) AND v_quote_line_record.product_type_id IS NOT NULL THEN
                BEGIN
                    PERFORM public.generate_configured_bom_for_quote_line(
                        v_quote_line_record.id,
                        v_quote_line_record.product_type_id,
                        (SELECT organization_id FROM "Quotes" WHERE id = v_quote_id),
                        v_quote_line_record.drive_type,
                        v_quote_line_record.bottom_rail_type,
                        v_quote_line_record.cassette,
                        v_quote_line_record.cassette_type,
                        v_quote_line_record.side_channel,
                        v_quote_line_record.side_channel_type,
                        v_quote_line_record.hardware_color,
                        COALESCE(v_quote_line_record.width_m, 0),
                        COALESCE(v_quote_line_record.height_m, 0),
                        v_quote_line_record.qty,
                        v_quote_line_record.tube_type,
                        v_quote_line_record.operating_system_variant
                    );
                    RAISE NOTICE '    ✅ Generated QuoteLineComponents';
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
                    (SELECT organization_id FROM "Quotes" WHERE id = v_quote_id),
                    v_sale_order_line_id,
                    v_quote_line_record.id,
                    NULL,
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
                
                RAISE NOTICE '    ✅ Created BomInstance %', v_bom_instance_id;
                v_created_boms := v_created_boms + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '    ⚠️  Error creating BomInstance: %', SQLERRM;
            END;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error creating SalesOrderLine: %', SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Completed:';
    RAISE NOTICE '   Created % SalesOrderLine(s)', v_created_lines;
    RAISE NOTICE '   Created % BomInstance(s)', v_created_boms;
    
END $$;

-- Verify results
SELECT 
    q.quote_no,
    so.sale_order_no,
    so.status,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as line_count,
    (SELECT COUNT(*) FROM "BomInstances" bi 
     WHERE bi.sale_order_line_id IN (
         SELECT id FROM "SalesOrderLines" 
         WHERE sale_order_id = so.id AND deleted = false
     ) AND bi.deleted = false) as bom_count
FROM "Quotes" q
JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000003'
AND q.deleted = false;


