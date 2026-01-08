-- ====================================================
-- Migration 434: DEEP DIAGNOSTIC - Find the EXACT source of the error
-- ====================================================
-- OBJETIVO: Encontrar EXACTAMENTE qué trigger/función está causando
-- el error "record 'new' has no field 'sale_order_id'"
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 1: Verificar el esquema REAL de ManufacturingOrders
-- ====================================================

DO $$
DECLARE
    v_column_record RECORD;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ESQUEMA REAL DE ManufacturingOrders';
    RAISE NOTICE '========================================';
    
    FOR v_column_record IN
        SELECT 
            column_name,
            data_type,
            is_nullable,
            column_default
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'ManufacturingOrders'
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE 'Column: % | Type: % | Nullable: % | Default: %', 
            v_column_record.column_name,
            v_column_record.data_type,
            v_column_record.is_nullable,
            v_column_record.column_default;
    END LOOP;
END $$;

-- ====================================================
-- STEP 2: Listar TODOS los triggers (BEFORE y AFTER)
-- ====================================================

DO $$
DECLARE
    v_trigger_record RECORD;
    v_function_def text;
    v_function_source text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TODOS LOS TRIGGERS EN ManufacturingOrders (ORDEN DE EJECUCIÓN)';
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
            END as event,
            CASE 
                WHEN tg.tgtype::integer & 1 = 1 THEN 'ROW'
                ELSE 'STATEMENT'
            END as level
        FROM pg_trigger tg
        JOIN pg_class c ON tg.tgrelid = c.oid
        JOIN pg_proc p ON tg.tgfoid = p.oid
        WHERE c.relname = 'ManufacturingOrders'
        AND NOT tg.tgisinternal
        ORDER BY 
            CASE WHEN tg.tgtype::integer & 2 = 2 THEN 1 ELSE 2 END, -- BEFORE first
            CASE WHEN tg.tgtype::integer & 16 = 16 THEN 1 ELSE 2 END, -- INSERT first
            tg.tgname
    LOOP
        SELECT pg_get_functiondef(v_trigger_record.function_oid) INTO v_function_def;
        
        RAISE NOTICE '---';
        RAISE NOTICE 'Trigger: %', v_trigger_record.trigger_name;
        RAISE NOTICE 'Function: %', v_trigger_record.function_name;
        RAISE NOTICE 'Timing: % | Event: % | Level: %', 
            v_trigger_record.timing,
            v_trigger_record.event,
            v_trigger_record.level;
        
        -- Buscar EXACTAMENTE el patrón problemático
        IF v_function_def ~ '\bNEW\.sale_order_id\b' THEN
            RAISE WARNING '  ❌❌❌ PROBLEMA ENCONTRADO: Function % contains NEW.sale_order_id (without s)!', v_trigger_record.function_name;
            -- Extraer las líneas problemáticas
            RAISE WARNING '  Buscando líneas problemáticas...';
        ELSIF v_function_def ~ '\bOLD\.sale_order_id\b' THEN
            RAISE WARNING '  ❌❌❌ PROBLEMA ENCONTRADO: Function % contains OLD.sale_order_id (without s)!', v_trigger_record.function_name;
        ELSIF v_function_def ~ '\bsale_order_id\b' AND v_function_def !~ '\bsales_order_id\b' THEN
            RAISE WARNING '  ⚠️ Function % contains sale_order_id (without s) somewhere', v_trigger_record.function_name;
        ELSE
            RAISE NOTICE '  ✅ Function % OK: uses sales_order_id (with s)', v_trigger_record.function_name;
        END IF;
    END LOOP;
END $$;

-- ====================================================
-- STEP 3: Buscar funciones que mencionen ManufacturingOrders
-- ====================================================

DO $$
DECLARE
    v_func_record RECORD;
    v_func_def text;
    v_problem_found boolean;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'FUNCIONES QUE MENCIONAN ManufacturingOrders';
    RAISE NOTICE '========================================';
    
    FOR v_func_record IN
        SELECT 
            p.proname as function_name,
            p.oid as function_oid,
            pg_get_function_arguments(p.oid) as function_args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        ORDER BY p.proname
    LOOP
        SELECT pg_get_functiondef(v_func_record.function_oid) INTO v_func_def;
        
        -- Solo mostrar funciones que mencionan ManufacturingOrders
        IF v_func_def ~ '\bManufacturingOrders\b' THEN
            v_problem_found := false;
            
            -- Buscar patrones problemáticos
            IF v_func_def ~ '\bNEW\.sale_order_id\b' THEN
                RAISE WARNING '⚠️ Function %: Contains NEW.sale_order_id (without s)', v_func_record.function_name;
                v_problem_found := true;
            END IF;
            
            IF v_func_def ~ '\bOLD\.sale_order_id\b' THEN
                RAISE WARNING '⚠️ Function %: Contains OLD.sale_order_id (without s)', v_func_record.function_name;
                v_problem_found := true;
            END IF;
            
            IF v_func_def ~ '\bmo\.sale_order_id\b' OR 
               v_func_def ~ '\bv_mo\.sale_order_id\b' OR 
               v_func_def ~ '\bv_manufacturing_order\.sale_order_id\b' THEN
                RAISE WARNING '⚠️ Function %: Contains mo.sale_order_id pattern (without s)', v_func_record.function_name;
                v_problem_found := true;
            END IF;
            
            IF NOT v_problem_found THEN
                RAISE NOTICE 'Function %: OK (mentions ManufacturingOrders but uses sales_order_id)', v_func_record.function_name;
            END IF;
        END IF;
    END LOOP;
END $$;

-- ====================================================
-- STEP 4: Verificar constraints y checks
-- ====================================================

DO $$
DECLARE
    v_constraint_record RECORD;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CONSTRAINTS Y CHECKS EN ManufacturingOrders';
    RAISE NOTICE '========================================';
    
    FOR v_constraint_record IN
        SELECT 
            conname as constraint_name,
            contype as constraint_type,
            pg_get_constraintdef(oid) as constraint_def
        FROM pg_constraint
        WHERE conrelid = 'public."ManufacturingOrders"'::regclass
        ORDER BY contype, conname
    LOOP
        RAISE NOTICE 'Constraint: % | Type: %', 
            v_constraint_record.constraint_name,
            v_constraint_record.constraint_type;
        RAISE NOTICE '  Definition: %', v_constraint_record.constraint_def;
        
        -- Verificar si el constraint menciona sale_order_id
        IF v_constraint_record.constraint_def ~ '\bsale_order_id\b' AND 
           v_constraint_record.constraint_def !~ '\bsales_order_id\b' THEN
            RAISE WARNING '  ⚠️ Constraint % mentions sale_order_id (without s)!', v_constraint_record.constraint_name;
        END IF;
    END LOOP;
END $$;

-- ====================================================
-- STEP 5: Buscar funciones genéricas que puedan acceder a campos
-- ====================================================

DO $$
DECLARE
    v_func_record RECORD;
    v_func_def text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'FUNCIONES GENÉRICAS (set_updated_at, etc.)';
    RAISE NOTICE '========================================';
    
    FOR v_func_record IN
        SELECT 
            p.proname as function_name,
            p.oid as function_oid
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND (
            p.proname LIKE '%updated_at%' OR
            p.proname LIKE '%trigger%' OR
            p.proname LIKE '%set_%'
        )
        ORDER BY p.proname
    LOOP
        SELECT pg_get_functiondef(v_func_record.function_oid) INTO v_func_def;
        
        -- Verificar si accede a campos de ManufacturingOrders
        IF v_func_def ~ '\bNEW\.' OR v_func_def ~ '\bOLD\.' THEN
            RAISE NOTICE 'Function: %', v_func_record.function_name;
            
            IF v_func_def ~ '\bsale_order_id\b' AND v_func_def !~ '\bsales_order_id\b' THEN
                RAISE WARNING '  ⚠️ Function % contains sale_order_id (without s)!', v_func_record.function_name;
            ELSE
                RAISE NOTICE '  ✅ Function % OK', v_func_record.function_name;
            END IF;
        END IF;
    END LOOP;
END $$;

-- ====================================================
-- STEP 6: Verificar si hay triggers en otras tablas que afecten ManufacturingOrders
-- ====================================================

DO $$
DECLARE
    v_trigger_record RECORD;
    v_function_def text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'TRIGGERS EN OTRAS TABLAS QUE MENCIONAN ManufacturingOrders';
    RAISE NOTICE '========================================';
    
    FOR v_trigger_record IN
        SELECT 
            tg.tgname as trigger_name,
            c.relname as table_name,
            p.proname as function_name,
            p.oid as function_oid
        FROM pg_trigger tg
        JOIN pg_class c ON tg.tgrelid = c.oid
        JOIN pg_proc p ON tg.tgfoid = p.oid
        WHERE c.relname != 'ManufacturingOrders'
        AND NOT tg.tgisinternal
        ORDER BY c.relname, tg.tgname
    LOOP
        SELECT pg_get_functiondef(v_trigger_record.function_oid) INTO v_function_def;
        
        -- Solo mostrar si menciona ManufacturingOrders
        IF v_function_def ~ '\bManufacturingOrders\b' THEN
            RAISE NOTICE 'Trigger: % on table: % | Function: %', 
                v_trigger_record.trigger_name,
                v_trigger_record.table_name,
                v_trigger_record.function_name;
            
            IF v_function_def ~ '\bsale_order_id\b' AND v_function_def !~ '\bsales_order_id\b' THEN
                RAISE WARNING '  ⚠️ This trigger/function contains sale_order_id (without s)!';
            END IF;
        END IF;
    END LOOP;
END $$;

-- ====================================================
-- STEP 7: RESUMEN FINAL
-- ====================================================

DO $$
DECLARE
    v_trigger_count integer;
    v_problem_count integer := 0;
    v_func_record RECORD;
    v_func_def text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'RESUMEN FINAL';
    RAISE NOTICE '========================================';
    
    -- Contar triggers
    SELECT COUNT(*) INTO v_trigger_count
    FROM pg_trigger tg
    JOIN pg_class c ON tg.tgrelid = c.oid
    WHERE c.relname = 'ManufacturingOrders'
    AND NOT tg.tgisinternal;
    
    RAISE NOTICE 'Total triggers en ManufacturingOrders: %', v_trigger_count;
    
    -- Contar funciones problemáticas
    FOR v_func_record IN
        SELECT p.oid, p.proname
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
    LOOP
        SELECT pg_get_functiondef(v_func_record.oid) INTO v_func_def;
        
        IF v_func_def ~ '\bNEW\.sale_order_id\b' OR 
           v_func_def ~ '\bOLD\.sale_order_id\b' OR
           (v_func_def ~ '\bManufacturingOrders\b' AND v_func_def ~ '\bsale_order_id\b' AND v_func_def !~ '\bsales_order_id\b') THEN
            v_problem_count := v_problem_count + 1;
            RAISE WARNING '  Problema #%: Function %', v_problem_count, v_func_record.proname;
        END IF;
    END LOOP;
    
    IF v_problem_count = 0 THEN
        RAISE NOTICE '✅ NO SE ENCONTRARON FUNCIONES CON sale_order_id (sin s)';
        RAISE NOTICE '⚠️ Si el error persiste, puede ser un problema de caché o una función que no está en el schema public';
    ELSE
        RAISE WARNING '⚠️ SE ENCONTRARON % FUNCIONES CON PROBLEMAS', v_problem_count;
    END IF;
END $$;

