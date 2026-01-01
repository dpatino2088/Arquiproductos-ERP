-- ====================================================
-- Fix Missing QuoteLineComponents and Generate BOM
-- ====================================================
-- Este script genera QuoteLineComponents para Quotes aprobados
-- y luego genera BOMs para los Manufacturing Orders existentes
-- ====================================================

DO $$
DECLARE
    v_mo RECORD;
    v_quote_line RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component_record RECORD;
    v_canonical_uom text;
    v_unit_cost_exw numeric;
    v_total_cost_exw numeric;
    v_category_code text;
    v_copied_count integer;
    v_total_qlc_created integer := 0;
    v_total_bil_created integer := 0;
    v_qlc_count integer;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'GENERANDO QUOTELINECOMPONENTS Y BOMS PARA MOs';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    -- Procesar cada Manufacturing Order sin BOMs
    FOR v_mo IN
        SELECT 
            mo.id,
            mo.manufacturing_order_no,
            mo.sale_order_id,
            mo.organization_id,
            so.sale_order_no,
            so.quote_id
        FROM "ManufacturingOrders" mo
        JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
        WHERE mo.deleted = false
        AND NOT EXISTS (
            SELECT 1 
            FROM "SalesOrderLines" sol
            JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
            WHERE sol.sale_order_id = mo.sale_order_id
            AND sol.deleted = false
        )
        ORDER BY mo.created_at ASC
    LOOP
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'Procesando MO: % (SO: %)', v_mo.manufacturing_order_no, v_mo.sale_order_no;
        RAISE NOTICE '====================================================';
        
        -- Procesar cada QuoteLine del Sales Order
        FOR v_quote_line IN
            SELECT 
                ql.id as quote_line_id,
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
                ql.qty,
                sol.id as sale_order_line_id
            FROM "SalesOrderLines" sol
            INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
            WHERE sol.sale_order_id = v_mo.sale_order_id
                AND sol.deleted = false
            ORDER BY sol.line_number
        LOOP
            RAISE NOTICE '';
            RAISE NOTICE '  QuoteLine: %', v_quote_line.quote_line_id;
            
            -- Verificar si ya existen QuoteLineComponents
            SELECT COUNT(*) INTO v_qlc_count
            FROM "QuoteLineComponents"
            WHERE quote_line_id = v_quote_line.quote_line_id
            AND source = 'configured_component'
            AND deleted = false;
            
            IF v_qlc_count > 0 THEN
                RAISE NOTICE '  ✅ Ya tiene % QuoteLineComponents', v_qlc_count;
            ELSE
                -- Verificar product_type_id
                IF v_quote_line.product_type_id IS NULL THEN
                    RAISE WARNING '  ⚠️ QuoteLine no tiene product_type_id, saltando';
                    CONTINUE;
                END IF;
                
                -- Asegurar organization_id
                IF v_quote_line.organization_id IS NULL THEN
                    UPDATE "QuoteLines"
                    SET organization_id = v_mo.organization_id
                    WHERE id = v_quote_line.quote_line_id;
                    v_quote_line.organization_id := v_mo.organization_id;
                END IF;
                
                -- Generar QuoteLineComponents
                BEGIN
                    RAISE NOTICE '  🔧 Generando QuoteLineComponents...';
                    v_result := public.generate_configured_bom_for_quote_line(
                        v_quote_line.quote_line_id,
                        v_quote_line.product_type_id,
                        v_quote_line.organization_id,
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
                    
                    -- Verificar cuántos se crearon
                    SELECT COUNT(*) INTO v_qlc_count
                    FROM "QuoteLineComponents"
                    WHERE quote_line_id = v_quote_line.quote_line_id
                    AND source = 'configured_component'
                    AND deleted = false;
                    
                    RAISE NOTICE '  ✅ Generados % QuoteLineComponents', v_qlc_count;
                    v_total_qlc_created := v_total_qlc_created + v_qlc_count;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '  ❌ Error generando QuoteLineComponents: % (%)', SQLERRM, SQLSTATE;
                        CONTINUE;
                END;
            END IF;
            
            -- Encontrar o crear BomInstance
            SELECT id INTO v_bom_instance_id
            FROM "BomInstances"
            WHERE sale_order_line_id = v_quote_line.sale_order_line_id
            AND deleted = false
            LIMIT 1;
            
            IF NOT FOUND THEN
                INSERT INTO "BomInstances" (
                    organization_id,
                    sale_order_line_id,
                    quote_line_id,
                    status,
                    created_at,
                    updated_at
                ) VALUES (
                    v_mo.organization_id,
                    v_quote_line.sale_order_line_id,
                    v_quote_line.quote_line_id,
                    'locked',
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
                
                RAISE NOTICE '  ✅ BomInstance creado: %', v_bom_instance_id;
            ELSE
                RAISE NOTICE '  ✅ BomInstance ya existe: %', v_bom_instance_id;
            END IF;
            
            -- Copiar QuoteLineComponents a BomInstanceLines
            RAISE NOTICE '  🔧 Copiando a BomInstanceLines...';
            v_copied_count := 0;
            
            FOR v_component_record IN
                SELECT
                    qlc.*,
                    ci.item_name,
                    ci.sku
                FROM "QuoteLineComponents" qlc
                INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
                WHERE qlc.quote_line_id = v_quote_line.quote_line_id
                AND qlc.source = 'configured_component'
                AND qlc.deleted = false
                AND ci.deleted = false
            LOOP
                BEGIN
                    v_canonical_uom := public.normalize_uom_to_canonical(v_component_record.uom);
                    
                    v_unit_cost_exw := public.get_unit_cost_in_uom(
                        v_component_record.catalog_item_id,
                        v_canonical_uom,
                        v_mo.organization_id
                    );
                    
                    IF v_unit_cost_exw IS NULL OR v_unit_cost_exw = 0 THEN
                        v_unit_cost_exw := COALESCE(v_component_record.unit_cost_exw, 0);
                    END IF;
                    
                    v_total_cost_exw := v_component_record.qty * v_unit_cost_exw;
                    v_category_code := public.derive_category_code_from_role(v_component_record.component_role);
                    
                    -- Insertar en BomInstanceLines (sin organization_id para compatibilidad)
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
                        v_bom_instance_id,
                        v_component_record.catalog_item_id,
                        v_component_record.sku,
                        v_component_record.component_role,
                        v_component_record.qty,
                        v_canonical_uom,
                        v_component_record.item_name,
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
                    v_total_bil_created := v_total_bil_created + 1;
                EXCEPTION
                    WHEN OTHERS THEN
                        RAISE WARNING '    ❌ Error copiando componente: % (%)', SQLERRM, SQLSTATE;
                END;
            END LOOP;
            
            RAISE NOTICE '  ✅ Copiados % componentes', v_copied_count;
            
        END LOOP;
        
        RAISE NOTICE '✅ MO % completado', v_mo.manufacturing_order_no;
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ PROCESO COMPLETADO';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'QuoteLineComponents generados: %', v_total_qlc_created;
    RAISE NOTICE 'BomInstanceLines copiados: %', v_total_bil_created;
    RAISE NOTICE '';
    
END;
$$;

-- Verificar resultados
SELECT 
    'Resultado Final' as tipo,
    mo.manufacturing_order_no,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines,
    COUNT(DISTINCT qlc.id) as quote_line_components
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false AND qlc.source = 'configured_component'
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no
ORDER BY mo.created_at DESC;






