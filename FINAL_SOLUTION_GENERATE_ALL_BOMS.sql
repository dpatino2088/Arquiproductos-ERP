-- ====================================================
-- SOLUCIÓN FINAL - Generar BOMs para TODOS los MOs activos
-- ====================================================

DO $$
DECLARE
    v_mo RECORD;
    v_quote_line RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component RECORD;
    v_total_boms integer := 0;
    v_total_components integer := 0;
BEGIN
    -- Generar BOMs para TODOS los MOs activos sin BOMs
    FOR v_mo IN
        SELECT 
            mo.id,
            mo.manufacturing_order_no,
            mo.sale_order_id,
            mo.organization_id,
            so.sale_order_no
        FROM "ManufacturingOrders" mo
        JOIN "SalesOrders" so ON so.id = mo.sale_order_id
        WHERE mo.deleted = false
        AND so.deleted = false
        ORDER BY mo.created_at ASC
    LOOP
        -- Procesar cada SalesOrderLine
        FOR v_quote_line IN
            SELECT 
                ql.*,
                sol.id as sale_order_line_id
            FROM "SalesOrderLines" sol
            INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
            WHERE sol.sale_order_id = v_mo.sale_order_id
                AND sol.deleted = false
        LOOP
            IF v_quote_line.product_type_id IS NULL THEN
                CONTINUE;
            END IF;
            
            -- Generar QuoteLineComponents si no existen
            IF NOT EXISTS (
                SELECT 1 FROM "QuoteLineComponents"
                WHERE quote_line_id = v_quote_line.id
                AND source = 'configured_component'
                AND deleted = false
            ) THEN
                v_result := public.generate_configured_bom_for_quote_line(
                    v_quote_line.id,
                    v_quote_line.product_type_id,
                    COALESCE(v_quote_line.organization_id, v_mo.organization_id),
                    v_quote_line.drive_type,
                    v_quote_line.bottom_rail_type,
                    COALESCE(v_quote_line.cassette, false),
                    v_quote_line.cassette_type,
                    COALESCE(v_quote_line.side_channel, false),
                    v_quote_line.side_channel_type,
                    v_quote_line.hardware_color,
                    v_quote_line.width_m,
                    v_quote_line.height_m,
                    v_quote_line.qty
                );
            END IF;
            
            -- Crear BomInstance
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
                    v_quote_line.id,
                    'locked',
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
                
                v_total_boms := v_total_boms + 1;
            END IF;
            
            -- Copiar QuoteLineComponents a BomInstanceLines
            FOR v_component IN
                SELECT
                    qlc.*,
                    ci.item_name,
                    ci.sku
                FROM "QuoteLineComponents" qlc
                INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
                WHERE qlc.quote_line_id = v_quote_line.id
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
                        v_bom_instance_id,
                        v_component.catalog_item_id,
                        v_component.sku,
                        v_component.component_role,
                        v_component.qty,
                        v_component.uom,
                        v_component.item_name,
                        COALESCE(v_component.unit_cost_exw, 0),
                        v_component.qty * COALESCE(v_component.unit_cost_exw, 0),
                        'accessory',
                        now(),
                        now(),
                        false
                    );
                    
                    v_total_components := v_total_components + 1;
                EXCEPTION
                    WHEN unique_violation THEN
                        -- Ya existe, ignorar
                        NULL;
                END;
            END LOOP;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '✅ Total BOMs creados: %', v_total_boms;
    RAISE NOTICE '✅ Total componentes: %', v_total_components;
END;
$$;

-- Resultado final
SELECT 
    mo.manufacturing_order_no,
    so.sale_order_no,
    COUNT(DISTINCT bil.id) as components,
    CASE WHEN COUNT(DISTINCT bil.id) > 0 THEN '✅' ELSE '❌' END as status
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no
ORDER BY mo.created_at DESC;

