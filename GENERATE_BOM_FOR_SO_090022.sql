-- Generar BOM para SO-090022
DO $$
DECLARE
    v_so_id uuid;
    v_mo_id uuid;
    v_org_id uuid;
    v_quote_line RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component RECORD;
    v_copied integer := 0;
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Generando BOM para SO-090022';
    RAISE NOTICE '====================================================';
    
    -- Obtener SO
    SELECT id, organization_id INTO v_so_id, v_org_id
    FROM "SalesOrders"
    WHERE sale_order_no = 'SO-090022'
    AND deleted = false;
    
    IF v_so_id IS NULL THEN
        RAISE NOTICE '❌ SO-090022 no encontrado';
        RETURN;
    END IF;
    
    RAISE NOTICE 'SO ID: %', v_so_id;
    RAISE NOTICE 'Org ID: %', v_org_id;
    
    -- Obtener MO
    SELECT id INTO v_mo_id
    FROM "ManufacturingOrders"
    WHERE sale_order_id = v_so_id
    AND deleted = false
    LIMIT 1;
    
    IF v_mo_id IS NULL THEN
        RAISE NOTICE '❌ No hay MO para SO-090022';
        RETURN;
    END IF;
    
    RAISE NOTICE 'MO ID: %', v_mo_id;
    RAISE NOTICE '';
    
    -- Procesar cada QuoteLine
    FOR v_quote_line IN
        SELECT 
            ql.*,
            sol.id as sale_order_line_id
        FROM "SalesOrderLines" sol
        INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
        WHERE sol.sale_order_id = v_so_id
            AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        RAISE NOTICE 'QuoteLine: %', v_quote_line.id;
        
        IF v_quote_line.product_type_id IS NULL THEN
            RAISE WARNING '  ⚠️ Sin product_type_id';
            CONTINUE;
        END IF;
        
        -- Generar QuoteLineComponents
        IF NOT EXISTS (
            SELECT 1 FROM "QuoteLineComponents"
            WHERE quote_line_id = v_quote_line.id
            AND source = 'configured_component'
            AND deleted = false
        ) THEN
            RAISE NOTICE '  Generando QuoteLineComponents...';
            
            v_result := public.generate_configured_bom_for_quote_line(
                v_quote_line.id,
                v_quote_line.product_type_id,
                COALESCE(v_quote_line.organization_id, v_org_id),
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
            
            RAISE NOTICE '  ✅ QuoteLineComponents generados';
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
                v_org_id,
                v_quote_line.sale_order_line_id,
                v_quote_line.id,
                'locked',
                now(),
                now()
            ) RETURNING id INTO v_bom_instance_id;
            
            RAISE NOTICE '  ✅ BomInstance creado: %', v_bom_instance_id;
        ELSE
            RAISE NOTICE '  ✅ BomInstance existe: %', v_bom_instance_id;
        END IF;
        
        -- Copiar QuoteLineComponents a BomInstanceLines
        RAISE NOTICE '  Copiando componentes...';
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
            ) ON CONFLICT DO NOTHING;
            
            v_copied := v_copied + 1;
        END LOOP;
        
        RAISE NOTICE '  ✅ Componentes copiados: %', v_copied;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ BOM generado para SO-090022';
    RAISE NOTICE 'Total componentes: %', v_copied;
    RAISE NOTICE '====================================================';
    
END;
$$;

-- Verificar
SELECT 
    so.sale_order_no,
    COUNT(DISTINCT bi.id) as boms,
    COUNT(DISTINCT bil.id) as components
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-090022'
AND so.deleted = false
GROUP BY so.id, so.sale_order_no;






