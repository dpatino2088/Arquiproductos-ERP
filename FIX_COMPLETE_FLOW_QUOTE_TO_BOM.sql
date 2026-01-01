-- ====================================================
-- SOLUCIÓN COMPLETA: Quote -> Sales Order -> BOM
-- ====================================================
-- Este script arregla TODO el flujo:
-- 1. Copia QuoteLines a SalesOrderLines (faltante)
-- 2. Genera QuoteLineComponents
-- 3. Genera BOMs
-- ====================================================

DO $$
DECLARE
    v_so RECORD;
    v_quote_line RECORD;
    v_sale_order_line_id uuid;
    v_line_number integer;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component RECORD;
    v_copied integer;
    v_total_sol_created integer := 0;
    v_total_qlc_created integer := 0;
    v_total_bil_created integer := 0;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'CORRIGIENDO FLUJO COMPLETO: QUOTE -> SO -> BOM';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    
    -- Procesar cada Sales Order sin líneas
    FOR v_so IN
        SELECT 
            so.id,
            so.sale_order_no,
            so.quote_id,
            so.organization_id,
            q.quote_no
        FROM "SalesOrders" so
        JOIN "Quotes" q ON q.id = so.quote_id
        WHERE so.deleted = false
        AND NOT EXISTS (
            SELECT 1 FROM "SalesOrderLines" sol 
            WHERE sol.sale_order_id = so.id 
            AND sol.deleted = false
        )
        ORDER BY so.created_at ASC
    LOOP
        RAISE NOTICE '====================================================';
        RAISE NOTICE 'SO: % (Quote: %)', v_so.sale_order_no, v_so.quote_no;
        RAISE NOTICE '====================================================';
        
        -- PASO 1: Copiar QuoteLines a SalesOrderLines
        RAISE NOTICE 'Paso 1: Copiando QuoteLines a SalesOrderLines...';
        v_line_number := 0;
        
        FOR v_quote_line IN
            SELECT *
            FROM "QuoteLines"
            WHERE quote_id = v_so.quote_id
            AND deleted = false
            ORDER BY created_at ASC
        LOOP
            v_line_number := v_line_number + 1;
            
            BEGIN
                INSERT INTO "SalesOrderLines" (
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
                    created_at,
                    updated_at
                ) VALUES (
                    v_so.organization_id,
                    v_so.id,
                    v_quote_line.id,
                    v_quote_line.catalog_item_id,
                    v_line_number,
                    v_quote_line.qty,
                    v_quote_line.unit_price_snapshot,
                    v_quote_line.line_total,
                    v_quote_line.width_m,
                    v_quote_line.height_m,
                    v_quote_line.area,
                    v_quote_line.position,
                    v_quote_line.collection_name,
                    v_quote_line.variant_name,
                    v_quote_line.product_type,
                    v_quote_line.product_type_id,
                    v_quote_line.drive_type,
                    v_quote_line.bottom_rail_type,
                    v_quote_line.cassette,
                    v_quote_line.cassette_type,
                    v_quote_line.side_channel,
                    v_quote_line.side_channel_type,
                    v_quote_line.hardware_color,
                    v_quote_line.metadata,
                    now(),
                    now()
                ) RETURNING id INTO v_sale_order_line_id;
                
                RAISE NOTICE '  ✅ SalesOrderLine creado: line %', v_line_number;
                v_total_sol_created := v_total_sol_created + 1;
                
                -- PASO 2: Generar QuoteLineComponents si no existen
                DECLARE
                    v_qlc_count integer;
                BEGIN
                    SELECT COUNT(*) INTO v_qlc_count
                    FROM "QuoteLineComponents"
                    WHERE quote_line_id = v_quote_line.id
                    AND source = 'configured_component'
                    AND deleted = false;
                    
                    IF v_qlc_count = 0 AND v_quote_line.product_type_id IS NOT NULL THEN
                        RAISE NOTICE '  🔧 Generando QuoteLineComponents...';
                        
                        v_result := public.generate_configured_bom_for_quote_line(
                            v_quote_line.id,
                            v_quote_line.product_type_id,
                            COALESCE(v_quote_line.organization_id, v_so.organization_id),
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
                        
                        SELECT COUNT(*) INTO v_qlc_count
                        FROM "QuoteLineComponents"
                        WHERE quote_line_id = v_quote_line.id
                        AND source = 'configured_component'
                        AND deleted = false;
                        
                        RAISE NOTICE '  ✅ QuoteLineComponents generados: %', v_qlc_count;
                        v_total_qlc_created := v_total_qlc_created + v_qlc_count;
                    END IF;
                    
                    -- PASO 3: Crear BomInstance
                    SELECT id INTO v_bom_instance_id
                    FROM "BomInstances"
                    WHERE sale_order_line_id = v_sale_order_line_id
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
                            v_so.organization_id,
                            v_sale_order_line_id,
                            v_quote_line.id,
                            'locked',
                            now(),
                            now()
                        ) RETURNING id INTO v_bom_instance_id;
                        
                        RAISE NOTICE '  ✅ BomInstance creado';
                    END IF;
                    
                    -- PASO 4: Copiar QuoteLineComponents a BomInstanceLines
                    v_copied := 0;
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
                        ) ON CONFLICT (bom_instance_id, resolved_part_id, part_role, uom, deleted) 
                        DO UPDATE SET
                            qty = EXCLUDED.qty,
                            updated_at = now();
                        
                        v_copied := v_copied + 1;
                        v_total_bil_created := v_total_bil_created + 1;
                    END LOOP;
                    
                    RAISE NOTICE '  ✅ BomInstanceLines copiados: %', v_copied;
                END;
                
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '  ❌ Error: % (%)', SQLERRM, SQLSTATE;
            END;
        END LOOP;
        
        RAISE NOTICE '✅ SO % completado', v_so.sale_order_no;
        RAISE NOTICE '';
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ PROCESO COMPLETADO';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'SalesOrderLines creados: %', v_total_sol_created;
    RAISE NOTICE 'QuoteLineComponents generados: %', v_total_qlc_created;
    RAISE NOTICE 'BomInstanceLines copiados: %', v_total_bil_created;
    RAISE NOTICE '';
    
END;
$$;

-- Verificar resultado final
SELECT 
    mo.manufacturing_order_no,
    so.sale_order_no,
    COUNT(DISTINCT sol.id) as sales_order_lines,
    COUNT(DISTINCT bi.id) as bom_instances,
    COUNT(DISTINCT bil.id) as bom_lines
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no
ORDER BY mo.created_at DESC;






