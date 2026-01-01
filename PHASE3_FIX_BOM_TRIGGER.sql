-- ====================================================
-- FASE 3: Activar Trigger de BOM + Generar BOMs
-- ====================================================
-- 1. Activa el trigger para futuros MOs
-- 2. Genera BOMs para los 6 MOs existentes
-- ====================================================

-- Verificar estado actual
DO $$
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'FASE 3: Verificando trigger de BOM';
    RAISE NOTICE '====================================================';
    
    IF EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'ManufacturingOrders'
        AND t.tgname = 'trg_mo_insert_generate_bom'
        AND t.tgenabled = 'O'
    ) THEN
        RAISE NOTICE '✅ Trigger existe y está activo';
    ELSE
        RAISE WARNING '❌ Trigger NO está activo';
    END IF;
END;
$$;

-- Recrear función del trigger
CREATE OR REPLACE FUNCTION public.on_manufacturing_order_insert_generate_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_quote_line RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component RECORD;
    v_copied integer;
BEGIN
    RAISE NOTICE '🔔 MO % creado, generando BOM', NEW.manufacturing_order_no;
    
    -- Actualizar status del SO
    UPDATE "SalesOrders"
    SET status = 'In Production',
        updated_at = now()
    WHERE id = NEW.sale_order_id
    AND deleted = false
    AND status <> 'Delivered';
    
    -- Procesar cada QuoteLine del SO
    FOR v_quote_line IN
        SELECT 
            ql.*,
            sol.id as sale_order_line_id
        FROM "SalesOrderLines" sol
        INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
        WHERE sol.sale_order_id = NEW.sale_order_id
            AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        IF v_quote_line.product_type_id IS NULL THEN
            RAISE NOTICE '  ⚠️ QuoteLine sin product_type_id';
            CONTINUE;
        END IF;
        
        BEGIN
            -- Generar QuoteLineComponents si no existen
            IF NOT EXISTS (
                SELECT 1 FROM "QuoteLineComponents"
                WHERE quote_line_id = v_quote_line.id
                AND source = 'configured_component'
                AND deleted = false
            ) THEN
                RAISE NOTICE '  🔧 Generando QuoteLineComponents...';
                
                v_result := public.generate_configured_bom_for_quote_line(
                    v_quote_line.id,
                    v_quote_line.product_type_id,
                    COALESCE(v_quote_line.organization_id, NEW.organization_id),
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
                    NEW.organization_id,
                    v_quote_line.sale_order_line_id,
                    v_quote_line.id,
                    'locked',
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
            END IF;
            
            -- Copiar QuoteLineComponents a BomInstanceLines
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
                DO NOTHING;
                
                v_copied := v_copied + 1;
            END LOOP;
            
            RAISE NOTICE '  ✅ BOM generado: % componentes', v_copied;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '  ❌ Error: % (%)', SQLERRM, SQLSTATE;
        END;
    END LOOP;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error en trigger: % (%)', SQLERRM, SQLSTATE;
        RETURN NEW;
END;
$$;

-- Recrear trigger
DROP TRIGGER IF EXISTS trg_mo_insert_generate_bom ON "ManufacturingOrders";

CREATE TRIGGER trg_mo_insert_generate_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.on_manufacturing_order_insert_generate_bom();

-- Verificar
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Trigger de BOM activado';
    RAISE NOTICE '====================================================';
END;
$$;

-- PARTE 2: Generar BOMs para los 6 MOs existentes
DO $$
DECLARE
    v_mo RECORD;
    v_quote_line RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component RECORD;
    v_copied integer;
    v_total integer := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Generando BOMs para MOs existentes';
    RAISE NOTICE '====================================================';
    
    FOR v_mo IN
        SELECT 
            mo.id,
            mo.manufacturing_order_no,
            mo.sale_order_id,
            mo.organization_id
        FROM "ManufacturingOrders" mo
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
        RAISE NOTICE '';
        RAISE NOTICE 'MO: %', v_mo.manufacturing_order_no;
        
        FOR v_quote_line IN
            SELECT 
                ql.*,
                sol.id as sale_order_line_id
            FROM "SalesOrderLines" sol
            INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
            WHERE sol.sale_order_id = v_mo.sale_order_id
                AND sol.deleted = false
            ORDER BY sol.line_number
        LOOP
            IF v_quote_line.product_type_id IS NULL THEN
                CONTINUE;
            END IF;
            
            BEGIN
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
                END IF;
                
                -- Copiar a BomInstanceLines
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
                    ) ON CONFLICT DO NOTHING;
                    
                    v_copied := v_copied + 1;
                END LOOP;
                
                v_total := v_total + v_copied;
                RAISE NOTICE '  ✅ BOM: % componentes', v_copied;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '  ❌ Error: % (%)', SQLERRM, SQLSTATE;
            END;
        END LOOP;
        
        RAISE NOTICE '✅ MO % completado', v_mo.manufacturing_order_no;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ FASE 3 COMPLETADA';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Total BomInstanceLines creados: %', v_total;
    RAISE NOTICE '';
END;
$$;

-- Verificar resultado final
SELECT 
    mo.manufacturing_order_no,
    so.sale_order_no,
    COUNT(DISTINCT sol.id) as lines,
    COUNT(DISTINCT bi.id) as boms,
    COUNT(DISTINCT bil.id) as components
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.deleted = false
GROUP BY mo.id, mo.manufacturing_order_no, so.sale_order_no
ORDER BY mo.created_at DESC;






