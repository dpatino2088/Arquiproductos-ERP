-- ====================================================
-- Migration 436: Fix "bomlineswithcosts" does not exist and manufacturing_order_id errors
-- ====================================================
-- OBJETIVO: 
-- 1. Corregir el problema de la vista BomLinesWithCosts (case-sensitivity)
-- 2. Verificar y corregir referencias a manufacturing_order_id
-- ====================================================

SET search_path = public;

BEGIN;

-- ====================================================
-- STEP 1: Verificar si la vista BomLinesWithCosts existe
-- ====================================================

DO $$
DECLARE
    v_view_exists boolean;
    v_view_name text;
BEGIN
    -- Verificar si existe con comillas (case-sensitive)
    SELECT EXISTS (
        SELECT 1 
        FROM pg_views 
        WHERE schemaname = 'public' 
        AND viewname = 'BomLinesWithCosts'
    ) INTO v_view_exists;
    
    IF v_view_exists THEN
        RAISE NOTICE '✅ Vista "BomLinesWithCosts" existe';
    ELSE
        -- Verificar si existe sin comillas (lowercase)
        SELECT EXISTS (
            SELECT 1 
            FROM pg_views 
            WHERE schemaname = 'public' 
            AND viewname = 'bomlineswithcosts'
        ) INTO v_view_exists;
        
        IF v_view_exists THEN
            RAISE NOTICE '⚠️ Vista existe como "bomlineswithcosts" (lowercase)';
        ELSE
            RAISE WARNING '❌ Vista BomLinesWithCosts NO existe. Debe crearse en migración 168.';
        END IF;
    END IF;
END $$;

-- ====================================================
-- STEP 2: Asegurar que la vista se puede referenciar correctamente
-- Recrear la vista si es necesario para asegurar consistencia
-- ====================================================

-- Verificar si la vista existe y recrearla si es necesario
DO $$
DECLARE
    v_view_def text;
BEGIN
    -- Intentar obtener la definición de la vista
    BEGIN
        SELECT pg_get_viewdef('"BomLinesWithCosts"'::regclass, true) INTO v_view_def;
        RAISE NOTICE '✅ Vista "BomLinesWithCosts" es accesible';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '⚠️ No se pudo acceder a la vista "BomLinesWithCosts": %', SQLERRM;
            -- La vista debe ser recreada en la migración 168 si no existe
    END;
END $$;

-- ====================================================
-- STEP 3: Verificar estructura de ManufacturingOrderLines
-- ====================================================

DO $$
DECLARE
    v_has_manufacturing_order_id boolean;
    v_columns text;
BEGIN
    -- Verificar si ManufacturingOrderLines tiene manufacturing_order_id
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'ManufacturingOrderLines'
        AND column_name = 'manufacturing_order_id'
    ) INTO v_has_manufacturing_order_id;
    
    IF v_has_manufacturing_order_id THEN
        RAISE NOTICE '✅ ManufacturingOrderLines tiene columna manufacturing_order_id';
    ELSE
        RAISE WARNING '❌ ManufacturingOrderLines NO tiene columna manufacturing_order_id!';
        RAISE NOTICE 'Verificando columnas existentes...';
        
        -- Listar todas las columnas
        SELECT string_agg(column_name, ', ' ORDER BY ordinal_position)
        INTO v_columns
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'ManufacturingOrderLines';
        
        IF v_columns IS NOT NULL THEN
            RAISE NOTICE 'Columnas existentes: %', v_columns;
        ELSE
            RAISE WARNING '⚠️ Tabla ManufacturingOrderLines no existe o no tiene columnas';
        END IF;
    END IF;
END $$;

-- ====================================================
-- STEP 4: Buscar y reportar vistas que referencian manufacturing_order_id
-- ====================================================

DO $$
DECLARE
    v_view_record RECORD;
    v_view_def text;
    v_error_count integer := 0;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Buscando vistas que usan manufacturing_order_id';
    RAISE NOTICE '========================================';
    
    FOR v_view_record IN
        SELECT 
            n.nspname as schemaname,
            c.relname as viewname,
            c.oid as view_oid
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
        AND c.relkind = 'v'  -- 'v' = view
        ORDER BY c.relname
    LOOP
        BEGIN
            -- Usar el OID directamente para evitar problemas con nombres case-sensitive
            SELECT pg_get_viewdef(v_view_record.view_oid, true) INTO v_view_def;
            
            IF v_view_def ~ '\bmanufacturing_order_id\b' THEN
                RAISE NOTICE 'Vista encontrada: %', v_view_record.viewname;
                
                -- Verificar si usa ManufacturingOrderLines
                IF v_view_def ~ '\bManufacturingOrderLines\b' THEN
                    RAISE NOTICE '  → Usa ManufacturingOrderLines';
                    
                    -- Verificar si la columna existe
                    IF NOT EXISTS (
                        SELECT 1
                        FROM information_schema.columns
                        WHERE table_schema = 'public'
                        AND table_name = 'ManufacturingOrderLines'
                        AND column_name = 'manufacturing_order_id'
                    ) THEN
                        RAISE WARNING '  ⚠️ PROBLEMA: Vista % usa manufacturing_order_id pero la columna NO existe!', v_view_record.viewname;
                        v_error_count := v_error_count + 1;
                    END IF;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                -- Si hay un error al obtener la definición (como "relation does not exist")
                -- puede ser porque la vista tiene un nombre case-sensitive
                IF SQLERRM ~ 'does not exist' THEN
                    RAISE WARNING '⚠️ No se pudo acceder a la vista %: %', v_view_record.viewname, SQLERRM;
                ELSE
                    RAISE WARNING '⚠️ Error al procesar vista %: %', v_view_record.viewname, SQLERRM;
                END IF;
        END;
    END LOOP;
    
    IF v_error_count > 0 THEN
        RAISE WARNING '========================================';
        RAISE WARNING 'Se encontraron % vistas con problemas', v_error_count;
        RAISE WARNING '========================================';
    ELSE
        RAISE NOTICE '✅ No se encontraron vistas con problemas de manufacturing_order_id';
    END IF;
END $$;

-- ====================================================
-- STEP 5: Verificar funciones que usan manufacturing_order_id
-- ====================================================

DO $$
DECLARE
    v_func_record RECORD;
    v_func_def text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Verificando funciones que usan manufacturing_order_id';
    RAISE NOTICE '========================================';
    
    FOR v_func_record IN
        SELECT 
            p.proname as function_name,
            p.oid as function_oid,
            n.nspname as schema_name
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND (
            p.proname LIKE '%manufacturing%' OR
            p.proname LIKE '%bom%' OR
            p.proname LIKE '%mo%'
        )
        ORDER BY p.proname
    LOOP
        BEGIN
            SELECT pg_get_functiondef(v_func_record.function_oid) INTO v_func_def;
            
            IF v_func_def ~ '\bmanufacturing_order_id\b' THEN
                RAISE NOTICE 'Función: %', v_func_record.function_name;
                
                -- Verificar si usa ManufacturingOrderLines
                IF v_func_def ~ '\bManufacturingOrderLines\b' THEN
                    RAISE NOTICE '  → Usa ManufacturingOrderLines';
                    
                    -- Verificar si la columna existe
                    IF NOT EXISTS (
                        SELECT 1
                        FROM information_schema.columns
                        WHERE table_schema = 'public'
                        AND table_name = 'ManufacturingOrderLines'
                        AND column_name = 'manufacturing_order_id'
                    ) THEN
                        RAISE WARNING '  ⚠️ PROBLEMA: Función % usa manufacturing_order_id pero la columna NO existe!', v_func_record.function_name;
                    END IF;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE WARNING '⚠️ Error al procesar función %: %', v_func_record.function_name, SQLERRM;
        END;
    END LOOP;
END $$;

-- ====================================================
-- STEP 6: Resumen final
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICACIÓN COMPLETA FINALIZADA';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Si persisten errores:';
    RAISE NOTICE '1. Verificar que la migración 168 creó la vista "BomLinesWithCosts"';
    RAISE NOTICE '2. Verificar que la migración 426 creó ManufacturingOrderLines con manufacturing_order_id';
    RAISE NOTICE '3. Revisar consultas en el frontend que usen manufacturing_order_id';
    RAISE NOTICE '4. Verificar que todas las vistas y funciones usen nombres correctos (con comillas si tienen mayúsculas)';
    RAISE NOTICE '========================================';
END $$;

COMMIT;

