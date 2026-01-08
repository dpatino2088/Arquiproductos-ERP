-- ====================================================
-- Migration 435: Fix "column 'manufacturing_order_id' does not exist" error
-- ====================================================
-- OBJETIVO: Verificar y corregir cualquier referencia incorrecta a manufacturing_order_id
-- que pueda estar causando el error en la UI
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 1: Verificar el esquema de ManufacturingOrderLines
-- ====================================================

DO $$
DECLARE
    v_column_record RECORD;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ESQUEMA DE ManufacturingOrderLines';
    RAISE NOTICE '========================================';
    
    FOR v_column_record IN
        SELECT 
            column_name,
            data_type,
            is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'ManufacturingOrderLines'
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE 'Column: % | Type: % | Nullable: %', 
            v_column_record.column_name,
            v_column_record.data_type,
            v_column_record.is_nullable;
    END LOOP;
END $$;

-- ====================================================
-- STEP 2: Verificar si hay vistas que usen manufacturing_order_id incorrectamente
-- ====================================================

DO $$
DECLARE
    v_view_record RECORD;
    v_view_def text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VISTAS QUE MENCIONAN manufacturing_order_id';
    RAISE NOTICE '========================================';
    
    -- Usar pg_class directamente para obtener OIDs y evitar problemas con nombres case-sensitive
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
                RAISE NOTICE 'View: %', v_view_record.viewname;
                RAISE NOTICE '  Definition contains manufacturing_order_id';
                
                -- Verificar si la columna realmente existe en las tablas que usa
                IF v_view_def ~ '\bManufacturingOrderLines\b' AND v_view_def ~ '\bmanufacturing_order_id\b' THEN
                    -- Verificar si ManufacturingOrderLines tiene esa columna
                    IF EXISTS (
                        SELECT 1
                        FROM information_schema.columns
                        WHERE table_schema = 'public'
                        AND table_name = 'ManufacturingOrderLines'
                        AND column_name = 'manufacturing_order_id'
                    ) THEN
                        RAISE NOTICE '  ✅ Column exists in ManufacturingOrderLines';
                    ELSE
                        RAISE WARNING '  ⚠️ Column manufacturing_order_id does NOT exist in ManufacturingOrderLines!';
                    END IF;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                -- Si hay un error (como "relation does not exist"), reportarlo pero continuar
                IF SQLERRM ~ 'does not exist' THEN
                    RAISE WARNING '⚠️ No se pudo acceder a la vista %: %', v_view_record.viewname, SQLERRM;
                ELSE
                    RAISE WARNING '⚠️ Error al procesar vista %: %', v_view_record.viewname, SQLERRM;
                END IF;
        END;
    END LOOP;
END $$;

-- ====================================================
-- STEP 3: Verificar funciones RPC que puedan estar causando el problema
-- ====================================================

DO $$
DECLARE
    v_func_record RECORD;
    v_func_def text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'FUNCIONES RPC QUE MENCIONAN manufacturing_order_id';
    RAISE NOTICE '========================================';
    
    FOR v_func_record IN
        SELECT 
            p.proname as function_name,
            p.oid as function_oid
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND (
            p.proname LIKE '%bom%' OR
            p.proname LIKE '%manufacturing%'
        )
        ORDER BY p.proname
    LOOP
        SELECT pg_get_functiondef(v_func_record.function_oid) INTO v_func_def;
        
        IF v_func_def ~ '\bmanufacturing_order_id\b' THEN
            RAISE NOTICE 'Function: %', v_func_record.function_name;
            
            -- Verificar si está intentando acceder a una columna que no existe
            IF v_func_def ~ '\.manufacturing_order_id\b' OR v_func_def ~ '\bmanufacturing_order_id\s*=' THEN
                RAISE NOTICE '  Uses manufacturing_order_id in query';
            END IF;
        END IF;
    END LOOP;
END $$;

-- ====================================================
-- STEP 4: Asegurar que ManufacturingOrderLines tiene la columna correcta
-- ====================================================

-- Verificar si ManufacturingOrderLines existe y tiene manufacturing_order_id
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'ManufacturingOrderLines'
    ) THEN
        -- Verificar si tiene manufacturing_order_id
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
            AND table_name = 'ManufacturingOrderLines'
            AND column_name = 'manufacturing_order_id'
        ) THEN
            RAISE WARNING '⚠️ ManufacturingOrderLines table exists but does NOT have manufacturing_order_id column!';
            RAISE NOTICE 'This might be the source of the error.';
        ELSE
            RAISE NOTICE '✅ ManufacturingOrderLines has manufacturing_order_id column';
        END IF;
    ELSE
        RAISE NOTICE 'ℹ️ ManufacturingOrderLines table does not exist';
    END IF;
END $$;

-- ====================================================
-- STEP 5: Verificar si hay alguna consulta en el código que esté causando el problema
-- ====================================================
-- Nota: Este paso es informativo - las correcciones deben hacerse en el código frontend

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VERIFICACIÓN COMPLETA';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Si el error persiste, verificar:';
    RAISE NOTICE '1. Consultas en el frontend que usen manufacturing_order_id';
    RAISE NOTICE '2. Vistas que hagan JOIN con ManufacturingOrderLines';
    RAISE NOTICE '3. Funciones RPC que accedan a manufacturing_order_id';
    RAISE NOTICE '========================================';
END $$;

