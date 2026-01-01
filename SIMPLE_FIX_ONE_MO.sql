-- ====================================================
-- Fix Simple - Generar BOM para UN MO
-- ====================================================
-- Este script genera el BOM para el último MO
-- mostrando cada paso del proceso
-- ====================================================

DO $$
DECLARE
    v_mo_id uuid;
    v_mo_no text;
    v_so_id uuid;
    v_org_id uuid;
    v_quote_line_id uuid;
    v_sale_order_line_id uuid;
    v_product_type_id uuid;
    v_bom_instance_id uuid;
    v_qlc_count integer;
    v_component RECORD;
    v_copied integer := 0;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'GENERANDO BOM PARA EL ÚLTIMO MO';
    RAISE NOTICE '====================================================';
    
    -- Obtener el último MO
    SELECT mo.id, mo.manufacturing_order_no, mo.sale_order_id, mo.organization_id
    INTO v_mo_id, v_mo_no, v_so_id, v_org_id
    FROM "ManufacturingOrders" mo
    WHERE mo.deleted = false
    ORDER BY mo.created_at DESC
    LIMIT 1;
    
    IF v_mo_id IS NULL THEN
        RAISE NOTICE '❌ No hay Manufacturing Orders';
        RETURN;
    END IF;
    
    RAISE NOTICE 'MO: %', v_mo_no;
    RAISE NOTICE 'SO ID: %', v_so_id;
    RAISE NOTICE 'Org ID: %', v_org_id;
    RAISE NOTICE '';
    
    -- Obtener la primera QuoteLine
    SELECT ql.id, sol.id, ql.product_type_id
    INTO v_quote_line_id, v_sale_order_line_id, v_product_type_id
    FROM "SalesOrderLines" sol
    JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
    WHERE sol.sale_order_id = v_so_id
    AND sol.deleted = false
    ORDER BY sol.line_number
    LIMIT 1;
    
    IF v_quote_line_id IS NULL THEN
        RAISE NOTICE '❌ No hay QuoteLines para este SO';
        RETURN;
    END IF;
    
    RAISE NOTICE 'QuoteLine ID: %', v_quote_line_id;
    RAISE NOTICE 'SaleOrderLine ID: %', v_sale_order_line_id;
    RAISE NOTICE 'ProductType ID: %', v_product_type_id;
    RAISE NOTICE '';
    
    -- Verificar QuoteLineComponents
    SELECT COUNT(*) INTO v_qlc_count
    FROM "QuoteLineComponents"
    WHERE quote_line_id = v_quote_line_id
    AND source = 'configured_component'
    AND deleted = false;
    
    RAISE NOTICE 'QuoteLineComponents existentes: %', v_qlc_count;
    
    IF v_qlc_count = 0 THEN
        RAISE NOTICE '⚠️ No hay QuoteLineComponents. Generándolos...';
        
        -- Generar QuoteLineComponents
        DECLARE
            v_result jsonb;
            v_ql RECORD;
        BEGIN
            SELECT * INTO v_ql
            FROM "QuoteLines"
            WHERE id = v_quote_line_id;
            
            v_result := public.generate_configured_bom_for_quote_line(
                v_quote_line_id,
                v_product_type_id,
                COALESCE(v_ql.organization_id, v_org_id),
                v_ql.drive_type,
                v_ql.bottom_rail_type,
                COALESCE(v_ql.cassette, false),
                v_ql.cassette_type,
                COALESCE(v_ql.side_channel, false),
                v_ql.side_channel_type,
                v_ql.hardware_color,
                v_ql.width_m,
                v_ql.height_m,
                v_ql.qty
            );
            
            -- Verificar cuántos se crearon
            SELECT COUNT(*) INTO v_qlc_count
            FROM "QuoteLineComponents"
            WHERE quote_line_id = v_quote_line_id
            AND source = 'configured_component'
            AND deleted = false;
            
            RAISE NOTICE '✅ QuoteLineComponents generados: %', v_qlc_count;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '❌ Error generando QuoteLineComponents: %', SQLERRM;
                RETURN;
        END;
    END IF;
    
    RAISE NOTICE '';
    
    -- Crear o encontrar BomInstance
    SELECT id INTO v_bom_instance_id
    FROM "BomInstances"
    WHERE sale_order_line_id = v_sale_order_line_id
    AND deleted = false
    LIMIT 1;
    
    IF v_bom_instance_id IS NULL THEN
        RAISE NOTICE 'Creando BomInstance...';
        INSERT INTO "BomInstances" (
            organization_id,
            sale_order_line_id,
            quote_line_id,
            status,
            created_at,
            updated_at
        ) VALUES (
            v_org_id,
            v_sale_order_line_id,
            v_quote_line_id,
            'locked',
            now(),
            now()
        ) RETURNING id INTO v_bom_instance_id;
        
        RAISE NOTICE '✅ BomInstance creado: %', v_bom_instance_id;
    ELSE
        RAISE NOTICE '✅ BomInstance ya existe: %', v_bom_instance_id;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Copiando QuoteLineComponents a BomInstanceLines...';
    
    -- Copiar componentes
    FOR v_component IN
        SELECT
            qlc.id,
            qlc.catalog_item_id,
            qlc.component_role,
            qlc.qty,
            qlc.uom,
            qlc.unit_cost_exw,
            ci.item_name,
            ci.sku
        FROM "QuoteLineComponents" qlc
        INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
        WHERE qlc.quote_line_id = v_quote_line_id
        AND qlc.source = 'configured_component'
        AND qlc.deleted = false
        AND ci.deleted = false
    LOOP
        BEGIN
            RAISE NOTICE '  Copiando: % (SKU: %)', v_component.item_name, v_component.sku;
            
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
            
            v_copied := v_copied + 1;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '    ❌ Error: % (%)', SQLERRM, SQLSTATE;
        END;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ Total copiados: %', v_copied;
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






