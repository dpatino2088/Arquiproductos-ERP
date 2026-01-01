-- ====================================================
-- Fix BOM Lines - Simple Direct Approach
-- ====================================================
-- Script simple que copia directamente QuoteLineComponents a BomInstanceLines
-- ====================================================

DO $$
DECLARE
    v_bom_instance RECORD;
    v_component RECORD;
    v_copied integer;
    v_total_copied integer := 0;
    v_total_processed integer := 0;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Fixing BOM Lines - Simple Direct Approach';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    -- Encontrar todos los BomInstances sin líneas
    FOR v_bom_instance IN
        SELECT 
            bi.id,
            COALESCE(bi.quote_line_id, sol.quote_line_id) as quote_line_id,
            bi.organization_id
        FROM "BomInstances" bi
        INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id AND sol.deleted = false
        WHERE bi.deleted = false
        AND bi.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
        AND NOT EXISTS (
            SELECT 1 FROM "BomInstanceLines" bil 
            WHERE bil.bom_instance_id = bi.id AND bil.deleted = false
        )
    LOOP
        BEGIN
            v_total_processed := v_total_processed + 1;
            v_copied := 0;
            
            RAISE NOTICE 'Processing BomInstance % (QuoteLine: %)...', 
                v_bom_instance.id, 
                v_bom_instance.quote_line_id;
            
            IF v_bom_instance.quote_line_id IS NULL THEN
                RAISE WARNING '  ⚠️ No quote_line_id, skipping';
                CONTINUE;
            END IF;
            
            -- Copiar directamente los QuoteLineComponents
            FOR v_component IN
                SELECT
                    qlc.catalog_item_id,
                    ci.sku,
                    ci.item_name,
                    qlc.component_role,
                    qlc.qty,
                    qlc.uom,
                    COALESCE(qlc.unit_cost_exw, 0) as unit_cost_exw
                FROM "QuoteLineComponents" qlc
                INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
                WHERE qlc.quote_line_id = v_bom_instance.quote_line_id
                AND qlc.source = 'configured_component'
                AND qlc.deleted = false
                AND ci.deleted = false
            LOOP
                BEGIN
                    INSERT INTO "BomInstanceLines" (
                        bom_instance_id,
                        resolved_part_id,
                        resolved_sku,
                        part_role,
                        qty,
                        uom,
                        description,
                        unit_cost_exw,
                        total_cost_exw,
                        category_code,
                        created_at,
                        updated_at,
                        deleted
                    ) VALUES (
                        v_bom_instance.id,
                        v_component.catalog_item_id,
                        v_component.sku,
                        v_component.component_role,
                        v_component.qty,
                        v_component.uom,
                        v_component.item_name,
                        v_component.unit_cost_exw,
                        v_component.qty * v_component.unit_cost_exw,
                        'accessory',
                        now(),
                        now(),
                        false
                    ) ON CONFLICT (bom_instance_id, resolved_part_id, part_role, uom, deleted) DO NOTHING;
                    
                    v_copied := v_copied + 1;
                    v_total_copied := v_total_copied + 1;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '  ❌ Error: %', SQLERRM;
                END;
            END LOOP;
            
            IF v_copied > 0 THEN
                RAISE NOTICE '  ✅ Copied % components', v_copied;
            ELSE
                RAISE WARNING '  ⚠️ No components found for QuoteLine %', v_bom_instance.quote_line_id;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error processing BomInstance %: %', v_bom_instance.id, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Completed!';
    RAISE NOTICE '   Processed: %', v_total_processed;
    RAISE NOTICE '   Copied: %', v_total_copied;
    RAISE NOTICE '====================================================';
END;
$$;

-- Verificar
SELECT 
    'Verification' as check_type,
    mo.manufacturing_order_no,
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines,
    CASE
        WHEN COUNT(DISTINCT bil.id) > 0 THEN '✅ Has Lines'
        ELSE '❌ No Lines'
    END as status
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
AND mo.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no
ORDER BY mo.created_at DESC
LIMIT 20;






