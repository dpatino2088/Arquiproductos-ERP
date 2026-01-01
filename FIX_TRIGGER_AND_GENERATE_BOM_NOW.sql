-- ====================================================
-- SOLUCIÓN DEFINITIVA - Trigger de BOM
-- ====================================================
-- Este script:
-- 1. Recrea el trigger correctamente
-- 2. Genera BOMs para todos los MOs existentes
-- ====================================================

-- ========================================
-- PARTE 1: RECREAR TRIGGER
-- ========================================

-- Eliminar trigger anterior si existe
DROP TRIGGER IF EXISTS trg_mo_insert_generate_bom ON "ManufacturingOrders";

-- Recrear función del trigger
CREATE OR REPLACE FUNCTION public.on_manufacturing_order_insert_generate_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sales_order_record RECORD;
    v_quote_line RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component RECORD;
    v_canonical_uom text;
    v_unit_cost numeric;
    v_total_cost numeric;
    v_category text;
    v_copied integer;
BEGIN
    RAISE NOTICE '🔔 TRIGGER EJECUTADO: MO % creado', NEW.manufacturing_order_no;
    
    -- Obtener SalesOrder
    SELECT * INTO v_sales_order_record
    FROM "SalesOrders"
    WHERE id = NEW.sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '⚠️ SalesOrder no encontrado: %', NEW.sale_order_id;
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '  SO encontrado: %', v_sales_order_record.sale_order_no;
    
    -- Actualizar status del SO
    UPDATE "SalesOrders"
    SET status = 'In Production',
        updated_at = now()
    WHERE id = NEW.sale_order_id
    AND deleted = false
    AND status <> 'Delivered';
    
    -- Procesar cada QuoteLine
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
        WHERE sol.sale_order_id = NEW.sale_order_id
            AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        IF v_quote_line.product_type_id IS NULL THEN
            RAISE WARNING '  ⚠️ QuoteLine % sin product_type_id', v_quote_line.quote_line_id;
            CONTINUE;
        END IF;
        
        IF v_quote_line.organization_id IS NULL THEN
            UPDATE "QuoteLines" SET organization_id = NEW.organization_id
            WHERE id = v_quote_line.quote_line_id;
            v_quote_line.organization_id := NEW.organization_id;
        END IF;
        
        BEGIN
            RAISE NOTICE '  🔧 Generando BOM para QuoteLine %...', v_quote_line.quote_line_id;
            
            -- Generar QuoteLineComponents
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
                    NEW.organization_id,
                    v_quote_line.sale_order_line_id,
                    v_quote_line.quote_line_id,
                    'locked',
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
                
                RAISE NOTICE '  ✅ BomInstance creado: %', v_bom_instance_id;
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
                WHERE qlc.quote_line_id = v_quote_line.quote_line_id
                AND qlc.source = 'configured_component'
                AND qlc.deleted = false
                AND ci.deleted = false
            LOOP
                v_canonical_uom := public.normalize_uom_to_canonical(v_component.uom);
                v_unit_cost := public.get_unit_cost_in_uom(
                    v_component.catalog_item_id,
                    v_canonical_uom,
                    NEW.organization_id
                );
                
                IF v_unit_cost IS NULL OR v_unit_cost = 0 THEN
                    v_unit_cost := COALESCE(v_component.unit_cost_exw, 0);
                END IF;
                
                v_total_cost := v_component.qty * v_unit_cost;
                v_category := public.derive_category_code_from_role(v_component.component_role);
                
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
                    v_canonical_uom,
                    v_component.item_name,
                    v_unit_cost,
                    v_total_cost,
                    v_category,
                    now(),
                    now(),
                    false
                ) ON CONFLICT (bom_instance_id, resolved_part_id, part_role, uom, deleted) 
                DO UPDATE SET
                    qty = EXCLUDED.qty,
                    unit_cost_exw = EXCLUDED.unit_cost_exw,
                    total_cost_exw = EXCLUDED.total_cost_exw,
                    updated_at = now();
                
                v_copied := v_copied + 1;
            END LOOP;
            
            RAISE NOTICE '  ✅ Copiados % componentes', v_copied;
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

-- Crear trigger
CREATE TRIGGER trg_mo_insert_generate_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.on_manufacturing_order_insert_generate_bom();

-- Verificar
DO $$
BEGIN
    RAISE NOTICE '✅ Trigger recreado y activado';
    IF EXISTS (
        SELECT 1 FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        WHERE c.relname = 'ManufacturingOrders'
        AND t.tgname = 'trg_mo_insert_generate_bom'
        AND t.tgenabled = 'O'
    ) THEN
        RAISE NOTICE '✅ Trigger está ACTIVO';
    ELSE
        RAISE WARNING '❌ Trigger NO está activo';
    END IF;
END;
$$;

-- ========================================
-- PARTE 2: GENERAR BOMs PARA MOs EXISTENTES
-- ========================================

DO $$
DECLARE
    v_mo RECORD;
    v_quote_line RECORD;
    v_result jsonb;
    v_bom_instance_id uuid;
    v_component RECORD;
    v_canonical_uom text;
    v_unit_cost numeric;
    v_total_cost numeric;
    v_category text;
    v_copied integer;
    v_total_created integer := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'GENERANDO BOMs PARA MOs EXISTENTES';
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
            IF v_quote_line.product_type_id IS NULL THEN
                RAISE WARNING '  ⚠️ QuoteLine sin product_type_id';
                CONTINUE;
            END IF;
            
            IF v_quote_line.organization_id IS NULL THEN
                UPDATE "QuoteLines" SET organization_id = v_mo.organization_id
                WHERE id = v_quote_line.quote_line_id;
                v_quote_line.organization_id := v_mo.organization_id;
            END IF;
            
            BEGIN
                -- Generar QuoteLineComponents
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
                        v_quote_line.quote_line_id,
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
                    WHERE qlc.quote_line_id = v_quote_line.quote_line_id
                    AND qlc.source = 'configured_component'
                    AND qlc.deleted = false
                    AND ci.deleted = false
                LOOP
                    v_canonical_uom := public.normalize_uom_to_canonical(v_component.uom);
                    v_unit_cost := public.get_unit_cost_in_uom(
                        v_component.catalog_item_id,
                        v_canonical_uom,
                        v_mo.organization_id
                    );
                    
                    IF v_unit_cost IS NULL OR v_unit_cost = 0 THEN
                        v_unit_cost := COALESCE(v_component.unit_cost_exw, 0);
                    END IF;
                    
                    v_total_cost := v_component.qty * v_unit_cost;
                    v_category := public.derive_category_code_from_role(v_component.component_role);
                    
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
                        v_canonical_uom,
                        v_component.item_name,
                        v_unit_cost,
                        v_total_cost,
                        v_category,
                        now(),
                        now(),
                        false
                    ) ON CONFLICT (bom_instance_id, resolved_part_id, part_role, uom, deleted) 
                    DO UPDATE SET
                        qty = EXCLUDED.qty,
                        unit_cost_exw = EXCLUDED.unit_cost_exw,
                        total_cost_exw = EXCLUDED.total_cost_exw,
                        updated_at = now();
                    
                    v_copied := v_copied + 1;
                END LOOP;
                
                RAISE NOTICE '  ✅ Copiados % componentes', v_copied;
                v_total_created := v_total_created + v_copied;
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE WARNING '  ❌ Error: % (%)', SQLERRM, SQLSTATE;
            END;
        END LOOP;
        
        RAISE NOTICE '✅ MO % completado', v_mo.manufacturing_order_no;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ PROCESO COMPLETADO';
    RAISE NOTICE 'Total BomInstanceLines creados: %', v_total_created;
    RAISE NOTICE '====================================================';
END;
$$;

-- Verificación final
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
ORDER BY mo.created_at DESC;






