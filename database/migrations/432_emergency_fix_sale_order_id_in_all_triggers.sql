-- ====================================================
-- Migration 432: EMERGENCY FIX - Find and Fix ALL sale_order_id references
-- ====================================================
-- OBJETIVO: Encontrar y corregir CUALQUIER referencia a sale_order_id (sin 's')
-- en triggers/funciones que se ejecuten durante INSERT de ManufacturingOrders
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 1: Diagnostic - List ALL triggers on ManufacturingOrders
-- ====================================================

DO $$
DECLARE
    v_trigger_record RECORD;
    v_function_def text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DIAGNÓSTICO: TODOS LOS TRIGGERS EN ManufacturingOrders';
    RAISE NOTICE '========================================';
    
    FOR v_trigger_record IN
        SELECT 
            tg.oid as trigger_oid,
            tg.tgname as trigger_name,
            p.proname as function_name,
            p.oid as function_oid,
            CASE 
                WHEN tg.tgtype::integer & 2 = 2 THEN 'BEFORE'
                WHEN tg.tgtype::integer & 64 = 64 THEN 'AFTER'
                ELSE 'UNKNOWN'
            END as timing,
            CASE 
                WHEN tg.tgtype::integer & 16 = 16 THEN 'INSERT'
                WHEN tg.tgtype::integer & 8 = 8 THEN 'DELETE'
                WHEN tg.tgtype::integer & 4 = 4 THEN 'UPDATE'
                ELSE 'UNKNOWN'
            END as event
        FROM pg_trigger tg
        JOIN pg_class c ON tg.tgrelid = c.oid
        JOIN pg_proc p ON tg.tgfoid = p.oid
        WHERE c.relname = 'ManufacturingOrders'
        AND NOT tg.tgisinternal
        ORDER BY 
            CASE WHEN tg.tgtype::integer & 2 = 2 THEN 1 ELSE 2 END, -- BEFORE first
            tg.tgname
    LOOP
        SELECT pg_get_functiondef(v_trigger_record.function_oid) INTO v_function_def;
        
        RAISE NOTICE '---';
        RAISE NOTICE 'Trigger: %', v_trigger_record.trigger_name;
        RAISE NOTICE 'Function: %', v_trigger_record.function_name;
        RAISE NOTICE 'Timing: % | Event: %', v_trigger_record.timing, v_trigger_record.event;
        
        -- Check for sale_order_id (without 's')
        IF v_function_def ~ '\bNEW\.sale_order_id\b' OR 
           v_function_def ~ '\bOLD\.sale_order_id\b' OR
           (v_function_def ~ '\bsale_order_id\b' AND v_function_def !~ '\bsales_order_id\b') THEN
            RAISE WARNING '  ⚠️ PROBLEMA ENCONTRADO: Function % contains sale_order_id (without s)!', v_trigger_record.function_name;
        ELSE
            RAISE NOTICE '  ✅ Function % OK: uses sales_order_id (with s)', v_trigger_record.function_name;
        END IF;
    END LOOP;
END $$;

-- ====================================================
-- STEP 2: Search ALL functions for sale_order_id patterns
-- ====================================================

DO $$
DECLARE
    v_func_record RECORD;
    v_func_def text;
    v_has_issue boolean;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'BÚSQUEDA EXHAUSTIVA: Funciones con sale_order_id';
    RAISE NOTICE '========================================';
    
    FOR v_func_record IN
        SELECT 
            p.proname as function_name,
            p.oid as function_oid,
            n.nspname as schema_name
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        ORDER BY p.proname
    LOOP
        SELECT pg_get_functiondef(v_func_record.function_oid) INTO v_func_def;
        
        v_has_issue := false;
        
        -- Buscar patrones problemáticos específicos
        IF v_func_def ~ '\bNEW\.sale_order_id\b' THEN
            RAISE WARNING '⚠️ Function %: Contains NEW.sale_order_id (without s)', v_func_record.function_name;
            v_has_issue := true;
        END IF;
        
        IF v_func_def ~ '\bOLD\.sale_order_id\b' THEN
            RAISE WARNING '⚠️ Function %: Contains OLD.sale_order_id (without s)', v_func_record.function_name;
            v_has_issue := true;
        END IF;
        
        IF v_func_def ~ '\bmo\.sale_order_id\b' OR v_func_def ~ '\bv_mo\.sale_order_id\b' OR v_func_def ~ '\bv_manufacturing_order\.sale_order_id\b' THEN
            RAISE WARNING '⚠️ Function %: Contains mo.sale_order_id pattern (without s)', v_func_record.function_name;
            v_has_issue := true;
        END IF;
    END LOOP;
END $$;

-- ====================================================
-- STEP 3: FORCE RECREATE ALL CRITICAL FUNCTIONS
-- ====================================================
-- Re-creamos TODAS las funciones que podrían ejecutarse en INSERT
-- ====================================================

-- FUNCTION: sync_sale_order_progress_from_manufacturing
-- CRÍTICA: Se ejecuta en INSERT
DROP FUNCTION IF EXISTS public.sync_sale_order_progress_from_manufacturing() CASCADE;

CREATE FUNCTION public.sync_sale_order_progress_from_manufacturing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_order_id uuid;
    v_new_status text;
    v_current_status text;
    v_manufacturing_status text;
BEGIN
    -- ✅ FORZADO: sales_order_id (con 's')
    v_sale_order_id := COALESCE(NEW.sales_order_id, OLD.sales_order_id);
    
    IF v_sale_order_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    SELECT order_progress_status INTO v_current_status
    FROM "SalesOrders"
    WHERE id = v_sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    IF TG_OP = 'INSERT' THEN
        v_new_status := 'scheduled';
    ELSIF TG_OP = 'UPDATE' AND TG_LEVEL = 'ROW' THEN
        v_manufacturing_status := NEW.status;
        
        IF v_manufacturing_status = 'in_production' THEN
            v_new_status := 'in_production';
        ELSIF v_manufacturing_status = 'completed' THEN
            v_new_status := 'production_completed';
        ELSE
            RETURN COALESCE(NEW, OLD);
        END IF;
    ELSE
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    IF v_new_status IS NOT NULL AND v_new_status IS DISTINCT FROM v_current_status THEN
        UPDATE "SalesOrders"
        SET order_progress_status = v_new_status,
            updated_at = now()
        WHERE id = v_sale_order_id
        AND deleted = false;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- FUNCTION: mo_after_insert_populate_lines
-- CRÍTICA: Se ejecuta en INSERT
DROP FUNCTION IF EXISTS public.mo_after_insert_populate_lines() CASCADE;

CREATE FUNCTION public.mo_after_insert_populate_lines()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- ✅ FORZADO: sales_order_id (con 's')
    IF NEW.sales_order_id IS NULL THEN
        RETURN NEW;
    END IF;
    
    INSERT INTO public."ManufacturingOrderLines"(
        manufacturing_order_id, 
        sales_order_line_id, 
        organization_id
    )
    SELECT
        NEW.id,
        sol.id,
        COALESCE(NEW.organization_id, sol.organization_id)
    FROM public."SalesOrderLines" sol
    WHERE sol.sales_order_id = NEW.sales_order_id  -- ✅ FORZADO: sales_order_id
        AND COALESCE(sol.deleted, false) = false
        AND COALESCE(sol.archived, false) = false
    ON CONFLICT (manufacturing_order_id, sales_order_line_id) DO NOTHING;
    
    RETURN NEW;
END;
$$;

-- FUNCTION: on_manufacturing_order_created_create_bom
-- CRÍTICA: Se ejecuta en INSERT
DROP FUNCTION IF EXISTS public.on_manufacturing_order_created_create_bom() CASCADE;

CREATE FUNCTION public.on_manufacturing_order_created_create_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NEW.deleted = false THEN
        PERFORM public.create_bom_instances_for_manufacturing_order(NEW.id);
    END IF;
    
    RETURN NEW;
END;
$$;

-- FUNCTION: on_manufacturing_order_status_change
DROP FUNCTION IF EXISTS public.on_manufacturing_order_status_change() CASCADE;

CREATE FUNCTION public.on_manufacturing_order_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_order_id uuid;
    v_mapped_status text;
    v_current_so_status text;
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
        RETURN NEW;
    END IF;
    
    -- ✅ FORZADO: sales_order_id (con 's')
    v_sale_order_id := COALESCE(NEW.sales_order_id, OLD.sales_order_id);
    
    IF v_sale_order_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    SELECT status INTO v_current_so_status
    FROM "SalesOrders"
    WHERE id = v_sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    IF v_current_so_status = 'Delivered' THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    v_mapped_status := public.map_mo_status_to_so_status(NEW.status);
    
    IF v_mapped_status IS NOT NULL AND v_mapped_status IS DISTINCT FROM v_current_so_status THEN
        UPDATE "SalesOrders"
        SET status = v_mapped_status,
            updated_at = now()
        WHERE id = v_sale_order_id
        AND deleted = false
        AND status <> 'Delivered';
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- FUNCTION: on_manufacturing_order_deleted_delete_bom
DROP FUNCTION IF EXISTS public.on_manufacturing_order_deleted_delete_bom() CASCADE;

CREATE FUNCTION public.on_manufacturing_order_deleted_delete_bom()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_order_id uuid;
    v_bom_instance_ids uuid[];
    v_deleted_bom_instances_count integer;
    v_deleted_bom_lines_count integer;
BEGIN
    -- ✅ FORZADO: sales_order_id (con 's')
    v_sale_order_id := OLD.sales_order_id;
    
    IF v_sale_order_id IS NULL THEN
        RETURN OLD;
    END IF;
    
    SELECT ARRAY_AGG(bi.id) INTO v_bom_instance_ids
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sales_order_id = v_sale_order_id  -- ✅ FORZADO: sales_order_id
    AND bi.deleted = false;
    
    IF v_bom_instance_ids IS NULL OR array_length(v_bom_instance_ids, 1) = 0 THEN
        RETURN OLD;
    END IF;
    
    UPDATE "BomInstanceLines"
    SET deleted = true, updated_at = now()
    WHERE bom_instance_id = ANY(v_bom_instance_ids)
    AND deleted = false;
    
    GET DIAGNOSTICS v_deleted_bom_lines_count = ROW_COUNT;
    
    UPDATE "BomInstances"
    SET deleted = true, updated_at = now()
    WHERE id = ANY(v_bom_instance_ids)
    AND deleted = false;
    
    GET DIAGNOSTICS v_deleted_bom_instances_count = ROW_COUNT;
    
    RETURN OLD;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error in on_manufacturing_order_deleted_delete_bom: %', SQLERRM;
        RETURN OLD;
END;
$$;

-- FUNCTION: create_bom_instances_for_manufacturing_order
DROP FUNCTION IF EXISTS public.create_bom_instances_for_manufacturing_order(uuid) CASCADE;

CREATE FUNCTION public.create_bom_instances_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mo RECORD;
    v_so RECORD;
    v_sol RECORD;
    v_ql RECORD;
    v_qlc RECORD;
    v_bom_instance_id uuid;
    v_created_instances integer := 0;
    v_created_lines integer := 0;
    v_lines_for_instance integer := 0;
    v_validated_uom text;
BEGIN
    -- ✅ FORZADO: sales_order_id (con 's')
    SELECT mo.id, mo.sales_order_id, mo.organization_id, mo.manufacturing_order_no
    INTO v_mo
    FROM "ManufacturingOrders" mo
    WHERE mo.id = p_manufacturing_order_id
    AND mo.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    -- ✅ FORZADO: sales_order_id (con 's')
    SELECT so.id, so.sale_order_no
    INTO v_so
    FROM "SalesOrders" so
    WHERE so.id = v_mo.sales_order_id
    AND so.deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SaleOrder % not found for ManufacturingOrder %', v_mo.sales_order_id, p_manufacturing_order_id;
    END IF;
    
    FOR v_sol IN
        SELECT sol.id, sol.quote_line_id, sol.line_number, sol.product_type_id
        FROM "SalesOrderLines" sol
        WHERE sol.sales_order_id = v_so.id  -- ✅ FORZADO: sales_order_id
        AND sol.deleted = false
        ORDER BY sol.line_number
    LOOP
        SELECT id INTO v_bom_instance_id
        FROM "BomInstances"
        WHERE sale_order_line_id = v_sol.id
        AND deleted = false
        LIMIT 1;
        
        IF NOT FOUND THEN
            SELECT ql.id, ql.bom_template_id
            INTO v_ql
            FROM "QuoteLines" ql
            WHERE ql.id = v_sol.quote_line_id
            AND ql.deleted = false
            LIMIT 1;
            
            BEGIN
                INSERT INTO "BomInstances" (
                    organization_id,
                    sale_order_line_id,
                    quote_line_id,
                    bom_template_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_mo.organization_id,
                    v_sol.id,
                    v_sol.quote_line_id,
                    COALESCE(v_ql.bom_template_id, NULL),
                    false,
                    now(),
                    now()
                ) RETURNING id INTO v_bom_instance_id;
                
                v_created_instances := v_created_instances + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    CONTINUE;
            END;
        END IF;
        
        v_lines_for_instance := 0;
        
        FOR v_qlc IN
            SELECT 
                qlc.id,
                qlc.catalog_item_id,
                qlc.component_role,
                qlc.qty,
                qlc.uom,
                ci.sku,
                ci.item_name,
                ci.category_code
            FROM "QuoteLineComponents" qlc
            INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
            WHERE qlc.quote_line_id = v_sol.quote_line_id
            AND qlc.deleted = false
            AND qlc.source = 'configured_component'
            ORDER BY qlc.component_role
        LOOP
            IF EXISTS (
                SELECT 1
                FROM "BomInstanceLines" bil
                WHERE bil.bom_instance_id = v_bom_instance_id
                AND bil.resolved_part_id = v_qlc.catalog_item_id
                AND COALESCE(bil.part_role, '') = COALESCE(v_qlc.component_role, '')
                AND bil.deleted = false
            ) THEN
                CONTINUE;
            END IF;
            
            v_validated_uom := CASE 
                WHEN v_qlc.uom = 'm' THEN 'mts'
                ELSE v_qlc.uom
            END;
            
            BEGIN
                INSERT INTO "BomInstanceLines" (
                    bom_instance_id,
                    resolved_part_id,
                    resolved_sku,
                    part_role,
                    qty,
                    uom,
                    description,
                    category_code,
                    organization_id,
                    deleted,
                    created_at,
                    updated_at
                ) VALUES (
                    v_bom_instance_id,
                    v_qlc.catalog_item_id,
                    v_qlc.sku,
                    v_qlc.component_role,
                    v_qlc.qty,
                    v_validated_uom,
                    COALESCE(v_qlc.item_name, ''),
                    v_qlc.category_code,
                    v_mo.organization_id,
                    false,
                    now(),
                    now()
                );
                
                v_lines_for_instance := v_lines_for_instance + 1;
                v_created_lines := v_created_lines + 1;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;
        END LOOP;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'manufacturing_order_id', p_manufacturing_order_id,
        'bom_instances_created', v_created_instances,
        'bom_instance_lines_created', v_created_lines
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

-- FUNCTION: reset_bom_for_manufacturing_order
DROP FUNCTION IF EXISTS public.reset_bom_for_manufacturing_order(uuid) CASCADE;

CREATE FUNCTION public.reset_bom_for_manufacturing_order(
    p_manufacturing_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_manufacturing_order RECORD;
    v_sale_order RECORD;
    v_bom_instance_ids uuid[];
    v_deleted_lines_count integer := 0;
    v_deleted_instances_count integer := 0;
BEGIN
    -- ✅ FORZADO: sales_order_id (con 's')
    SELECT mo.id, mo.organization_id, mo.sales_order_id
    INTO v_manufacturing_order
    FROM "ManufacturingOrders" mo
    WHERE mo.id = p_manufacturing_order_id
    AND mo.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ManufacturingOrder % not found', p_manufacturing_order_id;
    END IF;
    
    -- ✅ FORZADO: sales_order_id (con 's')
    SELECT so.id, so.organization_id
    INTO v_sale_order
    FROM "SalesOrders" so
    WHERE so.id = v_manufacturing_order.sales_order_id
    AND so.deleted = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'SaleOrder % not found for ManufacturingOrder %', v_manufacturing_order.sales_order_id, p_manufacturing_order_id;
    END IF;
    
    SELECT ARRAY_AGG(bi.id)
    INTO v_bom_instance_ids
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    WHERE sol.sales_order_id = v_sale_order.id  -- ✅ FORZADO: sales_order_id
    AND bi.deleted = false;
    
    IF v_bom_instance_ids IS NOT NULL AND array_length(v_bom_instance_ids, 1) > 0 THEN
        UPDATE "BomInstanceLines" bil
        SET deleted = true, updated_at = now()
        WHERE bil.bom_instance_id = ANY(v_bom_instance_ids)
        AND bil.deleted = false;
        
        GET DIAGNOSTICS v_deleted_lines_count = ROW_COUNT;
        
        UPDATE "BomInstances" bi
        SET deleted = true, updated_at = now()
        WHERE bi.id = ANY(v_bom_instance_ids)
        AND bi.deleted = false;
        
        GET DIAGNOSTICS v_deleted_instances_count = ROW_COUNT;
    END IF;
    
    RETURN jsonb_build_object(
        'ok', true,
        'manufacturing_order_id', p_manufacturing_order_id,
        'sale_order_id', v_sale_order.id,
        'deleted_instances', v_deleted_instances_count,
        'deleted_lines', v_deleted_lines_count
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error in reset_bom_for_manufacturing_order: %', SQLERRM;
END;
$$;

-- ====================================================
-- STEP 4: Re-create ALL triggers (drop and recreate)
-- ====================================================

-- Drop ALL existing triggers
DROP TRIGGER IF EXISTS trg_sync_sale_order_progress_on_mo_insert ON "ManufacturingOrders";
DROP TRIGGER IF EXISTS trg_sync_sale_order_progress_on_mo_status_update ON "ManufacturingOrders";
DROP TRIGGER IF EXISTS trg_mo_after_insert_populate_lines ON "ManufacturingOrders";
DROP TRIGGER IF EXISTS trg_manufacturing_order_created_create_bom ON "ManufacturingOrders";
DROP TRIGGER IF EXISTS trg_mo_status_sync_sale_order ON "ManufacturingOrders";
DROP TRIGGER IF EXISTS trg_manufacturing_order_deleted_delete_bom ON "ManufacturingOrders";

-- Re-create triggers
CREATE TRIGGER trg_sync_sale_order_progress_on_mo_insert
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.sync_sale_order_progress_from_manufacturing();

CREATE TRIGGER trg_sync_sale_order_progress_on_mo_status_update
    AFTER UPDATE OF status ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false AND OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.sync_sale_order_progress_from_manufacturing();

CREATE TRIGGER trg_mo_after_insert_populate_lines
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    EXECUTE FUNCTION public.mo_after_insert_populate_lines();

CREATE TRIGGER trg_manufacturing_order_created_create_bom
    AFTER INSERT ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = false)
    EXECUTE FUNCTION public.on_manufacturing_order_created_create_bom();

CREATE TRIGGER trg_mo_status_sync_sale_order
    AFTER UPDATE OF status ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status)
    EXECUTE FUNCTION public.on_manufacturing_order_status_change();

CREATE TRIGGER trg_manufacturing_order_deleted_delete_bom
    AFTER UPDATE OF deleted ON "ManufacturingOrders"
    FOR EACH ROW
    WHEN (NEW.deleted = true AND OLD.deleted = false)
    EXECUTE FUNCTION public.on_manufacturing_order_deleted_delete_bom();

-- ====================================================
-- STEP 5: Final verification - Show what triggers are active
-- ====================================================

DO $$
DECLARE
    v_trigger_record RECORD;
    v_function_def text;
    v_problem_found boolean := false;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICACIÓN FINAL: Triggers activos';
    RAISE NOTICE '========================================';
    
    FOR v_trigger_record IN
        SELECT 
            tg.tgname as trigger_name,
            p.proname as function_name,
            p.oid as function_oid,
            CASE 
                WHEN tg.tgtype::integer & 2 = 2 THEN 'BEFORE'
                WHEN tg.tgtype::integer & 64 = 64 THEN 'AFTER'
                ELSE 'UNKNOWN'
            END as timing,
            CASE 
                WHEN tg.tgtype::integer & 16 = 16 THEN 'INSERT'
                WHEN tg.tgtype::integer & 8 = 8 THEN 'DELETE'
                WHEN tg.tgtype::integer & 4 = 4 THEN 'UPDATE'
                ELSE 'UNKNOWN'
            END as event
        FROM pg_trigger tg
        JOIN pg_class c ON tg.tgrelid = c.oid
        JOIN pg_proc p ON tg.tgfoid = p.oid
        WHERE c.relname = 'ManufacturingOrders'
        AND NOT tg.tgisinternal
        ORDER BY 
            CASE WHEN tg.tgtype::integer & 16 = 16 THEN 1 ELSE 2 END, -- INSERT first
            CASE WHEN tg.tgtype::integer & 2 = 2 THEN 1 ELSE 2 END  -- BEFORE first
    LOOP
        SELECT pg_get_functiondef(v_trigger_record.function_oid) INTO v_function_def;
        
        RAISE NOTICE 'Trigger: % | Function: % | Timing: % | Event: %', 
            v_trigger_record.trigger_name,
            v_trigger_record.function_name,
            v_trigger_record.timing,
            v_trigger_record.event;
        
        -- Check for sale_order_id (without 's')
        IF v_function_def ~ '\bNEW\.sale_order_id\b' THEN
            RAISE WARNING '  ❌ PROBLEMA: Function % contains NEW.sale_order_id (without s)!', v_trigger_record.function_name;
            v_problem_found := true;
        ELSIF v_function_def ~ '\bOLD\.sale_order_id\b' THEN
            RAISE WARNING '  ❌ PROBLEMA: Function % contains OLD.sale_order_id (without s)!', v_trigger_record.function_name;
            v_problem_found := true;
        ELSE
            RAISE NOTICE '  ✅ Function % OK: uses sales_order_id (with s)', v_trigger_record.function_name;
        END IF;
    END LOOP;
    
    IF v_problem_found THEN
        RAISE WARNING '========================================';
        RAISE WARNING '⚠️ SE ENCONTRARON PROBLEMAS - Revisar funciones arriba';
        RAISE WARNING '========================================';
    ELSE
        RAISE NOTICE '========================================';
        RAISE NOTICE '✅ VERIFICACIÓN EXITOSA: Todos los triggers usan sales_order_id (con s)';
        RAISE NOTICE '========================================';
    END IF;
END $$;

