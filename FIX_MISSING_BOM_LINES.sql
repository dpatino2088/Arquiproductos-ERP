-- ====================================================
-- Fix Missing BOM Lines - Copy QuoteLineComponents to BomInstanceLines
-- ====================================================
-- Este script copia los QuoteLineComponents a BomInstanceLines
-- para todos los BomInstances que no tienen líneas
-- ====================================================

DO $$
DECLARE
    v_bom_instance RECORD;
    v_component RECORD;
    v_canonical_uom text;
    v_unit_cost_exw numeric;
    v_total_cost_exw numeric;
    v_category_code text;
    v_copied_count integer;
    v_total_copied integer := 0;
    v_total_instances integer := 0;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Copying QuoteLineComponents to BomInstanceLines';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    -- Encontrar todos los BomInstances que no tienen BomInstanceLines
    FOR v_bom_instance IN
        SELECT 
            bi.id as bom_instance_id,
            bi.sale_order_line_id,
            bi.quote_line_id,
            bi.organization_id
        FROM "BomInstances" bi
        WHERE bi.deleted = false
        AND bi.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
        AND NOT EXISTS (
            SELECT 1 
            FROM "BomInstanceLines" bil 
            WHERE bil.bom_instance_id = bi.id 
            AND bil.deleted = false
        )
        AND bi.quote_line_id IS NOT NULL
    LOOP
        BEGIN
            v_total_instances := v_total_instances + 1;
            v_copied_count := 0;
            
            RAISE NOTICE '📋 Processing BomInstance % (QuoteLine: %)...', v_bom_instance.bom_instance_id, v_bom_instance.quote_line_id;
            
            -- Copiar todos los QuoteLineComponents para este QuoteLine
            FOR v_component IN
                SELECT
                    qlc.*,
                    ci.item_name,
                    ci.sku
                FROM "QuoteLineComponents" qlc
                INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
                WHERE qlc.quote_line_id = v_bom_instance.quote_line_id
                AND qlc.source = 'configured_component'
                AND qlc.deleted = false
                AND ci.deleted = false
            LOOP
                BEGIN
                    v_canonical_uom := public.normalize_uom_to_canonical(v_component.uom);
                    
                    v_unit_cost_exw := public.get_unit_cost_in_uom(
                        v_component.catalog_item_id,
                        v_canonical_uom,
                        v_bom_instance.organization_id
                    );
                    
                    IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                        v_unit_cost_exw := COALESCE(v_component.unit_cost_exw, 0);
                    END IF;
                    
                    v_total_cost_exw := v_component.qty * v_unit_cost_exw;
                    v_category_code := public.derive_category_code_from_role(v_component.component_role);
                    
                    INSERT INTO "BomInstanceLines" (
                        bom_instance_id,
                        source_template_line_id,
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
                        v_bom_instance.bom_instance_id,
                        NULL,
                        v_component.catalog_item_id,
                        v_component.sku,
                        v_component.component_role,
                        v_component.qty,
                        v_canonical_uom,
                        v_component.item_name,
                        v_unit_cost_exw,
                        v_total_cost_exw,
                        v_category_code,
                        now(),
                        now(),
                        false
                    ) ON CONFLICT (bom_instance_id, resolved_part_id, part_role, uom, deleted) DO UPDATE SET
                        qty = EXCLUDED.qty,
                        unit_cost_exw = EXCLUDED.unit_cost_exw,
                        total_cost_exw = EXCLUDED.total_cost_exw,
                        description = EXCLUDED.description,
                        updated_at = now();
                    
                    v_copied_count := v_copied_count + 1;
                    v_total_copied := v_total_copied + 1;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '❌ Error copying component %: %', v_component.id, SQLERRM;
                END;
            END LOOP;
            
            IF v_copied_count > 0 THEN
                RAISE NOTICE '✅ Copied % components to BomInstance %', v_copied_count, v_bom_instance.bom_instance_id;
            ELSE
                RAISE WARNING '⚠️ No QuoteLineComponents found for QuoteLine %', v_bom_instance.quote_line_id;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '❌ Error processing BomInstance %: %', v_bom_instance.bom_instance_id, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Process completed!';
    RAISE NOTICE '   Total BomInstances processed: %', v_total_instances;
    RAISE NOTICE '   Total components copied: %', v_total_copied;
    RAISE NOTICE '====================================================';
END;
$$;

-- Verificar resultados
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
