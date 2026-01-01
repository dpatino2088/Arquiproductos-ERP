-- ====================================================
-- Generar BOM para el último MO manualmente
-- ====================================================
-- Este script genera BOM para el último MO creado
-- útil para cuando el trigger no se ejecutó
-- ====================================================

DO $$
DECLARE
    v_mo RECORD;
    v_so RECORD;
    v_quote_line RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component_record RECORD;
    v_canonical_uom text;
    v_unit_cost_exw numeric;
    v_total_cost_exw numeric;
    v_category_code text;
    v_copied_count integer := 0;
    v_total_copied integer := 0;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Generando BOM para el último Manufacturing Order';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    -- Obtener el último MO sin BOMs
    SELECT mo.* INTO v_mo
    FROM "ManufacturingOrders" mo
    LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = mo.sale_order_id AND sol.deleted = false
    LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
    WHERE mo.deleted = false
    GROUP BY mo.id
    HAVING COUNT(bi.id) = 0
    ORDER BY mo.created_at DESC
    LIMIT 1;
    
    IF v_mo IS NULL THEN
        RAISE NOTICE '⚠️ No hay Manufacturing Orders sin BOMs';
        RAISE NOTICE '   Todos los MOs ya tienen BOMs generados o no hay MOs.';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Manufacturing Order: %', v_mo.manufacturing_order_no;
    
    -- Obtener Sales Order
    SELECT * INTO v_so
    FROM "SalesOrders"
    WHERE id = v_mo.sale_order_id
    AND deleted = false;
    
    IF v_so IS NULL THEN
        RAISE WARNING '❌ Sales Order % no encontrado', v_mo.sale_order_id;
        RETURN;
    END IF;
    
    RAISE NOTICE 'Sales Order: %', v_so.sale_order_no;
    RAISE NOTICE '';
    
    -- Generar BOM para cada QuoteLine
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
        RAISE NOTICE 'Procesando QuoteLine %...', v_quote_line.quote_line_id;
        
        -- Verificar product_type_id
        IF v_quote_line.product_type_id IS NULL THEN
            RAISE WARNING '⚠️ QuoteLine % no tiene product_type_id, saltando', v_quote_line.quote_line_id;
            CONTINUE;
        END IF;
        
        -- Asegurar organization_id
        IF v_quote_line.organization_id IS NULL THEN
            UPDATE "QuoteLines"
            SET organization_id = v_mo.organization_id
            WHERE id = v_quote_line.quote_line_id;
            v_quote_line.organization_id := v_mo.organization_id;
        END IF;
        
        BEGIN
            -- Generar QuoteLineComponents
            RAISE NOTICE '  Generando QuoteLineComponents...';
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
            
            RAISE NOTICE '  ✅ QuoteLineComponents generados';
            
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
            END LOOP;
            
            RAISE NOTICE '  ✅ Copiados % componentes a BomInstanceLines', v_copied_count;
            v_total_copied := v_total_copied + v_copied_count;
            
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error: % (%)', SQLERRM, SQLSTATE;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Proceso completado';
    RAISE NOTICE 'Total de componentes copiados: %', v_total_copied;
    RAISE NOTICE '====================================================';
    
END;
$$;

-- Verificar resultado
SELECT 
    mo.manufacturing_order_no,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines
FROM "ManufacturingOrders" mo
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = mo.sale_order_id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no
ORDER BY mo.created_at DESC
LIMIT 5;






