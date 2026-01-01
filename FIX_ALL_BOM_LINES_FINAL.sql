-- ====================================================
-- Fix All BOM Lines - Final Complete Solution
-- ====================================================
-- Este script:
-- 1. Encuentra todos los BomInstances sin líneas
-- 2. Verifica y genera QuoteLineComponents si faltan
-- 3. Copia todos los componentes a BomInstanceLines
-- 4. Muestra resultados detallados
-- ====================================================

DO $$
DECLARE
    v_bom_instance RECORD;
    v_quote_line RECORD;
    v_component RECORD;
    v_result jsonb;
    v_canonical_uom text;
    v_unit_cost_exw numeric;
    v_total_cost_exw numeric;
    v_category_code text;
    v_copied_count integer;
    v_generated_count integer;
    v_total_copied integer := 0;
    v_total_instances integer := 0;
    v_total_generated integer := 0;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Fixing All BOM Lines - Final Solution';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';

    -- Encontrar todos los BomInstances sin BomInstanceLines
    FOR v_bom_instance IN
        SELECT DISTINCT
            bi.id as bom_instance_id,
            COALESCE(bi.quote_line_id, sol.quote_line_id) as quote_line_id,
            COALESCE(bi.organization_id, sol.organization_id) as organization_id,
            sol.sale_order_id
        FROM "BomInstances" bi
        INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id AND sol.deleted = false
        WHERE bi.deleted = false
        AND bi.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
        AND NOT EXISTS (
            SELECT 1 
            FROM "BomInstanceLines" bil 
            WHERE bil.bom_instance_id = bi.id 
            AND bil.deleted = false
        )
    LOOP
        BEGIN
            v_total_instances := v_total_instances + 1;
            v_copied_count := 0;
            v_generated_count := 0;
            
            -- Si quote_line_id es NULL, intentar obtenerlo
            IF v_bom_instance.quote_line_id IS NULL THEN
                SELECT quote_line_id INTO v_bom_instance.quote_line_id
                FROM "SalesOrderLines"
                WHERE id = (SELECT sale_order_line_id FROM "BomInstances" WHERE id = v_bom_instance.bom_instance_id)
                AND deleted = false;
            END IF;
            
            IF v_bom_instance.quote_line_id IS NULL THEN
                RAISE WARNING '⚠️ BomInstance % has no quote_line_id, skipping', v_bom_instance.bom_instance_id;
                CONTINUE;
            END IF;
            
            RAISE NOTICE '📋 [%/%] Processing BomInstance % (QuoteLine: %)...', 
                v_total_instances, 
                (SELECT COUNT(*) FROM "BomInstances" WHERE deleted = false AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'),
                v_bom_instance.bom_instance_id, 
                v_bom_instance.quote_line_id;
            
            -- Obtener información del QuoteLine
            SELECT 
                ql.id,
                ql.product_type_id,
                ql.organization_id,
                ql.drive_type,
                ql.bottom_rail_type,
                COALESCE(ql.cassette, false) as cassette,
                ql.cassette_type,
                COALESCE(ql.side_channel, false) as side_channel,
                ql.side_channel_type,
                ql.hardware_color,
                ql.width_m,
                ql.height_m,
                ql.qty
            INTO v_quote_line
            FROM "QuoteLines" ql
            WHERE ql.id = v_bom_instance.quote_line_id
            AND ql.deleted = false;
            
            IF NOT FOUND THEN
                RAISE WARNING '⚠️ QuoteLine % not found, skipping', v_bom_instance.quote_line_id;
                CONTINUE;
            END IF;
            
            -- Actualizar BomInstance con quote_line_id si estaba NULL
            IF (SELECT quote_line_id FROM "BomInstances" WHERE id = v_bom_instance.bom_instance_id) IS NULL THEN
                UPDATE "BomInstances"
                SET quote_line_id = v_bom_instance.quote_line_id
                WHERE id = v_bom_instance.bom_instance_id;
            END IF;
            
            -- Verificar si existen QuoteLineComponents
            SELECT COUNT(*) INTO v_generated_count
            FROM "QuoteLineComponents" 
            WHERE quote_line_id = v_bom_instance.quote_line_id
            AND source = 'configured_component'
            AND deleted = false;
            
            IF v_generated_count = 0 THEN
                -- Generar QuoteLineComponents si no existen
                IF v_quote_line.product_type_id IS NULL THEN
                    RAISE WARNING '⚠️ QuoteLine % has no product_type_id, cannot generate components', v_bom_instance.quote_line_id;
                    CONTINUE;
                END IF;
                
                RAISE NOTICE '  🔧 Generating % QuoteLineComponents...', v_generated_count;
                
                BEGIN
                    v_result := public.generate_configured_bom_for_quote_line(
                        v_quote_line.id,
                        v_quote_line.product_type_id,
                        COALESCE(v_quote_line.organization_id, v_bom_instance.organization_id),
                        v_quote_line.drive_type,
                        v_quote_line.bottom_rail_type,
                        v_quote_line.cassette,
                        v_quote_line.cassette_type,
                        v_quote_line.side_channel,
                        v_quote_line.side_channel_type,
                        v_quote_line.hardware_color,
                        v_quote_line.width_m,
                        v_quote_line.height_m,
                        v_quote_line.qty
                    );
                    
                    SELECT COUNT(*) INTO v_generated_count
                    FROM "QuoteLineComponents"
                    WHERE quote_line_id = v_bom_instance.quote_line_id
                    AND source = 'configured_component'
                    AND deleted = false;
                    
                    v_total_generated := v_total_generated + 1;
                    RAISE NOTICE '  ✅ Generated % QuoteLineComponents', v_generated_count;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '  ❌ Error generating QuoteLineComponents: %', SQLERRM;
                        CONTINUE;
                END;
            ELSE
                RAISE NOTICE '  ✅ Found % existing QuoteLineComponents', v_generated_count;
            END IF;
            
            -- Copiar QuoteLineComponents a BomInstanceLines
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
                        RAISE WARNING '❌ Error copying component %: % (SQLSTATE: %)', v_component.id, SQLERRM, SQLSTATE;
                END;
            END LOOP;
            
            IF v_copied_count > 0 THEN
                RAISE NOTICE '  ✅ Copied % components to BomInstance %', v_copied_count, v_bom_instance.bom_instance_id;
            ELSE
                RAISE WARNING '  ⚠️ No components copied for BomInstance %', v_bom_instance.bom_instance_id;
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
    RAISE NOTICE '   Total QuoteLineComponents generated: %', v_total_generated;
    RAISE NOTICE '   Total components copied: %', v_total_copied;
    RAISE NOTICE '====================================================';
END;
$$;

-- Verificar resultados finales
SELECT 
    'Final Verification' as check_type,
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






