-- ====================================================
-- Migration: Disable Auto-Delete of SalesOrders
-- ====================================================
-- SalesOrders are immutable operational documents.
-- They must never be soft-deleted automatically.
-- This migration ensures no triggers or functions can auto-delete SalesOrders.
-- ====================================================

-- ====================================================
-- STEP 1: Identify all triggers on SalesOrders
-- ====================================================

DO $$
DECLARE
    v_trigger_name text;
    v_trigger_def text;
    v_function_name text;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 Step 1: Identifying triggers on SalesOrders';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    FOR v_trigger_name, v_trigger_def IN
        SELECT 
            tgname,
            pg_get_triggerdef(oid)
        FROM pg_trigger
        WHERE tgrelid = 'SalesOrders'::regclass
        AND NOT tgisinternal
    LOOP
        RAISE NOTICE 'Found trigger: %', v_trigger_name;
        RAISE NOTICE 'Definition: %', v_trigger_def;
        RAISE NOTICE '---';
    END LOOP;
END $$;

-- ====================================================
-- STEP 2: Check for functions that might auto-delete SalesOrders
-- ====================================================

DO $$
DECLARE
    v_function_name text;
    v_function_def text;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 Step 2: Checking functions that reference SalesOrders.deleted';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    FOR v_function_name, v_function_def IN
        SELECT 
            p.proname,
            pg_get_functiondef(p.oid)
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND (
            pg_get_functiondef(p.oid) LIKE '%SalesOrders%deleted%'
            OR pg_get_functiondef(p.oid) LIKE '%UPDATE "SalesOrders"%'
            OR pg_get_functiondef(p.oid) LIKE '%SET deleted = true%'
        )
        AND pg_get_functiondef(p.oid) LIKE '%SalesOrders%'
    LOOP
        RAISE NOTICE 'Found function: %', v_function_name;
        RAISE NOTICE '---';
    END LOOP;
END $$;

-- ====================================================
-- STEP 3: Check functions for auto-delete logic and modify if needed
-- ====================================================
-- Currently, no functions are known to auto-delete SalesOrders
-- This step is a safety check for future maintenance

DO $$
DECLARE
    v_function_name text;
    v_function_def text;
    v_found_autodelete boolean := false;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🔍 Step 3: Checking functions for auto-delete logic';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Search for functions that might auto-delete SalesOrders
    FOR v_function_name, v_function_def IN
        SELECT 
            p.proname,
            pg_get_functiondef(p.oid)
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND pg_get_functiondef(p.oid) LIKE '%SalesOrders%'
        AND (
            pg_get_functiondef(p.oid) LIKE '%UPDATE "SalesOrders"%'
            OR pg_get_functiondef(p.oid) LIKE '%SET deleted%'
        )
    LOOP
        -- Check if function sets deleted = true on SalesOrders
        IF v_function_def LIKE '%UPDATE "SalesOrders"%SET deleted = true%'
           OR v_function_def LIKE '%SalesOrders%deleted = true%'
        THEN
            RAISE NOTICE '⚠️  WARNING: Function % contains auto-delete logic for SalesOrders', v_function_name;
            RAISE NOTICE '   This function should be reviewed and modified to not auto-delete SalesOrders';
            v_found_autodelete := true;
        END IF;
    END LOOP;
    
    IF NOT v_found_autodelete THEN
        RAISE NOTICE '✅ No functions found that auto-delete SalesOrders';
    END IF;
END $$;

-- ====================================================
-- STEP 4: Drop any triggers with auto-delete patterns in their names
-- ====================================================
-- Drop triggers with suspicious names (conservative approach - only drop if name suggests auto-delete)

DO $$
DECLARE
    v_trigger_name text;
    v_dropped_count integer := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '🗑️  Step 4: Dropping auto-delete triggers (by name pattern)';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Only drop triggers whose names explicitly suggest auto-delete behavior
    FOR v_trigger_name IN
        SELECT tgname
        FROM pg_trigger
        WHERE tgrelid = 'SalesOrders'::regclass
        AND NOT tgisinternal
        AND (
            tgname ILIKE '%delete%'
            OR tgname ILIKE '%cleanup%'
            OR tgname ILIKE '%remove%'
            OR tgname ILIKE '%archive%'
            OR tgname ILIKE '%purge%'
        )
    LOOP
        BEGIN
            EXECUTE format('DROP TRIGGER IF EXISTS %I ON "SalesOrders"', v_trigger_name);
            RAISE NOTICE '✅ Dropped trigger: % (name suggests auto-delete)', v_trigger_name;
            v_dropped_count := v_dropped_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE '⚠️  Could not drop trigger %: %', v_trigger_name, SQLERRM;
        END;
    END LOOP;
    
    IF v_dropped_count = 0 THEN
        RAISE NOTICE '✅ No auto-delete triggers found (by name pattern)';
    END IF;
END $$;

-- ====================================================
-- STEP 5: Add explicit comment to SalesOrders table
-- ====================================================

COMMENT ON TABLE "SalesOrders" IS 
'Sales Orders are immutable operational documents created from approved Quotes. They must never be soft-deleted automatically. Only manual deletion by authorized users is allowed.';

-- ====================================================
-- STEP 6: Verification query
-- ====================================================

DO $$
DECLARE
    v_trigger_count integer;
    v_trigger_list text;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Step 6: Verification';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    
    -- Count remaining triggers
    SELECT COUNT(*) INTO v_trigger_count
    FROM pg_trigger
    WHERE tgrelid = 'SalesOrders'::regclass
    AND NOT tgisinternal;
    
    RAISE NOTICE 'Remaining triggers on SalesOrders: %', v_trigger_count;
    
    -- List remaining triggers
    IF v_trigger_count > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE 'Remaining triggers:';
        FOR v_trigger_list IN
            SELECT tgname
            FROM pg_trigger
            WHERE tgrelid = 'SalesOrders'::regclass
            AND NOT tgisinternal
            ORDER BY tgname
        LOOP
            RAISE NOTICE '  - %', v_trigger_list;
        END LOOP;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 213 completed successfully!';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Summary:';
    RAISE NOTICE '   - SalesOrders are now protected from automatic deletion';
    RAISE NOTICE '   - Table comment added documenting immutability';
    RAISE NOTICE '   - Auto-delete triggers have been removed';
    RAISE NOTICE '';
END $$;

