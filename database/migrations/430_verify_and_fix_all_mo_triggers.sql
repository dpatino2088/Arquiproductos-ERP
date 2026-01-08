-- ====================================================
-- Migration 430: Verify and Fix ALL ManufacturingOrders Triggers
-- ====================================================
-- OBJETIVO: Asegurar que TODOS los triggers/funciones usen sales_order_id (con 's')
-- ERROR ACTUAL: "record 'new' has no field 'sale_order_id'"
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 1: Listar TODOS los triggers en ManufacturingOrders
-- ====================================================

DO $$
DECLARE
    v_trigger_name text;
    v_function_name text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'LISTANDO TODOS LOS TRIGGERS EN ManufacturingOrders';
    RAISE NOTICE '========================================';
    
    FOR v_trigger_name, v_function_name IN
        SELECT 
            tg.tgname as trigger_name,
            p.proname as function_name
        FROM pg_trigger tg
        JOIN pg_class c ON tg.tgrelid = c.oid
        JOIN pg_proc p ON tg.tgfoid = p.oid
        WHERE c.relname = 'ManufacturingOrders'
        AND NOT tg.tgisinternal
    LOOP
        RAISE NOTICE 'Trigger: % → Function: %', v_trigger_name, v_function_name;
    END LOOP;
END $$;

-- ====================================================
-- STEP 2: Verificar funciones que contienen sale_order_id (sin 's')
-- ====================================================

DO $$
DECLARE
    v_func_name text;
    v_func_def text;
    v_has_sale_order_id boolean;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICANDO FUNCIONES CON sale_order_id (SIN s)';
    RAISE NOTICE '========================================';
    
    FOR v_func_name, v_func_def IN
        SELECT 
            p.proname,
            pg_get_functiondef(p.oid)
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND (
            p.proname LIKE '%manufacturing%' 
            OR p.proname LIKE '%mo_%'
            OR p.proname LIKE '%sync_sale_order%'
            OR p.proname LIKE '%create_bom%'
            OR p.proname LIKE '%reset_bom%'
        )
    LOOP
        -- Buscar sale_order_id (sin 's') pero NO sales_order_id (con 's')
        -- Esto detecta si hay referencias a sale_order_id que no sean parte de sales_order_id
        IF v_func_def ~ 'sale_order_id' AND v_func_def !~ 'sales_order_id' THEN
            RAISE WARNING '⚠️ Function % contains sale_order_id (without s) but NOT sales_order_id (with s)', v_func_name;
        ELSIF v_func_def ~ 'sale_order_id' AND v_func_def ~ 'sales_order_id' THEN
            -- Tiene ambos, verificar si sale_order_id está solo (sin 's')
            IF v_func_def ~ '\bsale_order_id\b' AND v_func_def !~ '\bsales_order_id\b' THEN
                RAISE WARNING '⚠️ Function % may have isolated sale_order_id (without s)', v_func_name;
            ELSE
                RAISE NOTICE '✅ Function % verified: uses sales_order_id (with s)', v_func_name;
            END IF;
        ELSE
            RAISE NOTICE '✅ Function % verified: no sale_order_id references', v_func_name;
        END IF;
    END LOOP;
END $$;

-- ====================================================
-- STEP 3: Re-crear TODAS las funciones con sales_order_id
-- ====================================================
-- Esto asegura que todas las funciones estén actualizadas
-- ====================================================

-- Ya están en la migración 429, pero las re-creamos aquí para asegurar

-- FUNCTION: sync_sale_order_progress_from_manufacturing (CRÍTICO - se ejecuta en INSERT)
CREATE OR REPLACE FUNCTION public.sync_sale_order_progress_from_manufacturing()
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
    -- Get sales_order_id from ManufacturingOrder
    v_sale_order_id := COALESCE(NEW.sales_order_id, OLD.sales_order_id);  -- ✅ CORREGIDO
    
    IF v_sale_order_id IS NULL THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Get current order_progress_status
    SELECT order_progress_status INTO v_current_status
    FROM "SalesOrders"
    WHERE id = v_sale_order_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Determine new status based on ManufacturingOrder changes
    IF TG_OP = 'INSERT' THEN
        -- ManufacturingOrder created -> set to 'scheduled'
        v_new_status := 'scheduled';
        RAISE NOTICE '🔔 ManufacturingOrder % created for SaleOrder %, setting order_progress_status to scheduled', 
            COALESCE(NEW.id, 'unknown'), v_sale_order_id;
    ELSIF TG_OP = 'UPDATE' AND TG_LEVEL = 'ROW' THEN
        -- ManufacturingOrder status changed
        v_manufacturing_status := NEW.status;
        
        IF v_manufacturing_status = 'in_production' THEN
            v_new_status := 'in_production';
            RAISE NOTICE '🔔 ManufacturingOrder % status changed to in_production for SaleOrder %, setting order_progress_status to in_production', 
                NEW.id, v_sale_order_id;
        ELSIF v_manufacturing_status = 'completed' THEN
            v_new_status := 'production_completed';
            RAISE NOTICE '🔔 ManufacturingOrder % status changed to completed for SaleOrder %, setting order_progress_status to production_completed', 
                NEW.id, v_sale_order_id;
        ELSE
            -- No status change needed
            RETURN COALESCE(NEW, OLD);
        END IF;
    ELSE
        RETURN COALESCE(NEW, OLD);
    END IF;
    
    -- Update SaleOrder order_progress_status if it would change
    IF v_new_status IS NOT NULL AND v_new_status IS DISTINCT FROM v_current_status THEN
        UPDATE "SalesOrders"
        SET order_progress_status = v_new_status,
            updated_at = now()
        WHERE id = v_sale_order_id
        AND deleted = false;
        
        RAISE NOTICE '✅ Updated SaleOrder % order_progress_status from "%" to "%"', 
            v_sale_order_id, v_current_status, v_new_status;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- FUNCTION: mo_after_insert_populate_lines (CRÍTICO - se ejecuta en INSERT)
CREATE OR REPLACE FUNCTION public.mo_after_insert_populate_lines()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.sales_order_id IS NULL THEN  -- ✅ VERIFICADO: usa sales_order_id
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
    WHERE sol.sales_order_id = NEW.sales_order_id  -- ✅ VERIFICADO: usa sales_order_id
        AND COALESCE(sol.deleted, false) = false
        AND COALESCE(sol.archived, false) = false
    ON CONFLICT (manufacturing_order_id, sales_order_line_id) DO NOTHING;
    
    RETURN NEW;
END;
$$;

-- ====================================================
-- STEP 4: Verificación final
-- ====================================================

DO $$
DECLARE
    v_count integer;
    v_func_name text;
    v_func_def text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICACIÓN FINAL: Funciones con sale_order_id (sin s)';
    RAISE NOTICE '========================================';
    
    v_count := 0;
    
    -- Verificar funciones una por una
    FOR v_func_name, v_func_def IN
        SELECT 
            p.proname,
            pg_get_functiondef(p.oid)
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND (
            p.proname LIKE '%manufacturing%' 
            OR p.proname LIKE '%mo_%'
            OR p.proname LIKE '%sync_sale_order%'
            OR p.proname LIKE '%create_bom%'
            OR p.proname LIKE '%reset_bom%'
        )
    LOOP
        -- Verificar si tiene sale_order_id pero NO sales_order_id
        IF v_func_def ~ '\bsale_order_id\b' AND v_func_def !~ '\bsales_order_id\b' THEN
            v_count := v_count + 1;
            RAISE WARNING '⚠️ Function % contains sale_order_id (without s)', v_func_name;
        END IF;
    END LOOP;
    
    IF v_count > 0 THEN
        RAISE WARNING '⚠️ Aún existen % funciones con sale_order_id (sin s)', v_count;
    ELSE
        RAISE NOTICE '✅ Verificación completa: No se encontraron funciones con sale_order_id (sin s)';
    END IF;
END $$;

