-- ====================================================
-- Generar BOMs para Manufacturing Orders Existentes
-- ====================================================
-- Este script genera BOMs para Manufacturing Orders
-- que ya existen pero no tienen BOMs generados
-- ====================================================

DO $$
DECLARE
    r_mo RECORD;
    v_quote_line_record RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_count integer := 0;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Generando BOMs para Manufacturing Orders existentes';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    -- Buscar Manufacturing Orders sin BOMs
    FOR r_mo IN
        SELECT 
            mo.id,
            mo.manufacturing_order_no,
            mo.sale_order_id,
            mo.organization_id,
            so.sale_order_no
        FROM "ManufacturingOrders" mo
        INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
        WHERE mo.deleted = false
        AND NOT EXISTS (
            SELECT 1 
            FROM "SalesOrderLines" sol
            INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
            WHERE sol.sale_order_id = mo.sale_order_id
            AND sol.deleted = false
        )
        ORDER BY mo.created_at ASC
    LOOP
        BEGIN
            RAISE NOTICE '📋 Procesando Manufacturing Order % (SO: %)...', r_mo.manufacturing_order_no, r_mo.sale_order_no;
            
            -- Generate BOM for all QuoteLines in this SalesOrder
            FOR v_quote_line_record IN
                SELECT 
                    ql.id as quote_line_id,
                    ql.product_type_id,
                    ql.organization_id,
                    ql.drive_type,
                    ql.bottom_rail_type,
                    ql.cassette,
                    ql.cassette_type,
                    ql.side_channel,
                    ql.side_channel_type,
                    ql.hardware_color,
                    ql.width_m,
                    ql.height_m,
                    ql.qty,
                    sol.id as sale_order_line_id
                FROM "SalesOrderLines" sol
                INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
                WHERE sol.sale_order_id = r_mo.sale_order_id
                    AND sol.deleted = false
                ORDER BY sol.line_number
            LOOP
                -- Skip if no product_type_id
                IF v_quote_line_record.product_type_id IS NULL THEN
                    RAISE NOTICE '  ⚠️ QuoteLine % has no product_type_id, skipping', v_quote_line_record.quote_line_id;
                    CONTINUE;
                END IF;
                
                -- Ensure organization_id is set
                IF v_quote_line_record.organization_id IS NULL THEN
                    UPDATE "QuoteLines"
                    SET organization_id = r_mo.organization_id
                    WHERE id = v_quote_line_record.quote_line_id;
                    v_quote_line_record.organization_id := r_mo.organization_id;
                END IF;
                
                -- Generate BOM for this QuoteLine
                BEGIN
                    RAISE NOTICE '  🔧 Generating BOM for QuoteLine %...', v_quote_line_record.quote_line_id;
                    
                    v_result := public.generate_configured_bom_for_quote_line(
                        v_quote_line_record.quote_line_id,
                        v_quote_line_record.product_type_id,
                        v_quote_line_record.organization_id,
                        v_quote_line_record.drive_type,
                        v_quote_line_record.bottom_rail_type,
                        COALESCE(v_quote_line_record.cassette, false),
                        v_quote_line_record.cassette_type,
                        COALESCE(v_quote_line_record.side_channel, false),
                        v_quote_line_record.side_channel_type,
                        v_quote_line_record.hardware_color,
                        v_quote_line_record.width_m,
                        v_quote_line_record.height_m,
                        v_quote_line_record.qty
                    );
                    
                    -- Create BomInstance for this SaleOrderLine if it doesn't exist
                    SELECT id INTO v_bom_instance_id
                    FROM "BomInstances"
                    WHERE sale_order_line_id = v_quote_line_record.sale_order_line_id
                    AND deleted = false
                    LIMIT 1;
                    
                    IF NOT FOUND THEN
                        INSERT INTO "BomInstances" (
                            organization_id,
                            sale_order_line_id,
                            quote_line_id,
                            configured_product_id,
                            status,
                            created_at,
                            updated_at
                        ) VALUES (
                            r_mo.organization_id,
                            v_quote_line_record.sale_order_line_id,
                            v_quote_line_record.quote_line_id,
                            NULL, -- configured_product_id can be NULL
                            'locked', -- Status: locked because it's for a Manufacturing Order
                            now(),
                            now()
                        ) RETURNING id INTO v_bom_instance_id;
                        
                        RAISE NOTICE '  ✅ Created BomInstance % for SaleOrderLine %', v_bom_instance_id, v_quote_line_record.sale_order_line_id;
                    END IF;
                    
                    RAISE NOTICE '  ✅ BOM generated for QuoteLine %', v_quote_line_record.quote_line_id;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '  ❌ Error generating BOM for QuoteLine %: %', v_quote_line_record.quote_line_id, SQLERRM;
                END;
            END LOOP;
            
            v_count := v_count + 1;
            RAISE NOTICE '✅ Completed BOM generation for Manufacturing Order %', r_mo.manufacturing_order_no;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error processing Manufacturing Order %: %', r_mo.manufacturing_order_no, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Proceso completado!';
    RAISE NOTICE '   Total Manufacturing Orders procesados: %', v_count;
    RAISE NOTICE '====================================================';
END;
$$;

-- Verificar resultados
SELECT 
    mo.manufacturing_order_no,
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as bom_instances_count,
    COUNT(DISTINCT bil.id) as bom_lines_count,
    CASE 
        WHEN COUNT(DISTINCT bi.id) > 0 THEN '✅ Has BOM'
        ELSE '❌ No BOM'
    END as bom_status
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no
ORDER BY mo.created_at DESC;

