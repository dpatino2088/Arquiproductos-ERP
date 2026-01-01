-- Verificar trigger y generar BOM para SO-055812
DO $$
DECLARE
    v_trigger_active boolean;
BEGIN
    -- Verificar si el trigger está activo
    SELECT EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'ManufacturingOrders'
        AND t.tgname = 'trg_mo_insert_generate_bom'
        AND t.tgenabled = 'O'
    ) INTO v_trigger_active;
    
    IF v_trigger_active THEN
        RAISE NOTICE '✅ Trigger está activo';
    ELSE
        RAISE WARNING '❌ Trigger NO está activo - reactivando...';
    END IF;
END;
$$;

-- Recrear trigger (por si se desactivó)
DROP TRIGGER IF EXISTS trg_mo_insert_generate_bom ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_insert_generate_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.on_manufacturing_order_insert_generate_bom();

-- Generar BOM para SO-055812
DO $$
DECLARE
    v_so_id uuid;
    v_org_id uuid;
    v_quote_line RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component RECORD;
    v_total integer := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Generando BOM para SO-055812...';
    
    SELECT id, organization_id INTO v_so_id, v_org_id
    FROM "SalesOrders"
    WHERE sale_order_no = 'SO-055812'
    AND deleted = false;
    
    IF v_so_id IS NULL THEN
        RAISE NOTICE '❌ SO-055812 no encontrado';
        RETURN;
    END IF;
    
    FOR v_quote_line IN
        SELECT 
            ql.*,
            sol.id as sale_order_line_id
        FROM "SalesOrderLines" sol
        INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
        WHERE sol.sale_order_id = v_so_id
            AND sol.deleted = false
    LOOP
        IF v_quote_line.product_type_id IS NULL THEN
            RAISE WARNING '  ⚠️ QuoteLine sin product_type_id';
            CONTINUE;
        END IF;
        
        -- Generar QuoteLineComponents
        IF NOT EXISTS (
            SELECT 1 FROM "QuoteLineComponents"
            WHERE quote_line_id = v_quote_line.id
            AND source = 'configured_component'
            AND deleted = false
        ) THEN
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
        END IF;
        
        -- Copiar componentes
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
                v_total := v_total + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE '✅ BOM generado: % componentes', v_total;
END;
$$;

-- Verificar
SELECT 
    so.sale_order_no,
    COUNT(DISTINCT bil.id) as components
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-055812'
GROUP BY so.id, so.sale_order_no;






