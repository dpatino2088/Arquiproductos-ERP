-- ====================================================
-- Migration: Diagnose UOM Function Issue
-- ====================================================
-- Diagnostic script to check if get_unit_cost_in_uom function exists
-- and can be executed
-- ====================================================

DO $$
DECLARE
    v_function_count integer;
    v_table_exists boolean;
    v_test_result numeric;
    v_test_uuid uuid := gen_random_uuid();
    rec RECORD;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Diagnostic: Checking get_unit_cost_in_uom function...';
    RAISE NOTICE '';
    
    -- Check if UomConversions table exists
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'UomConversions'
    ) INTO v_table_exists;
    
    RAISE NOTICE '1. UomConversions table exists: %', v_table_exists;
    
    -- Check function count
    SELECT COUNT(*) INTO v_function_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
    AND p.proname = 'get_unit_cost_in_uom';
    
    RAISE NOTICE '2. Functions named get_unit_cost_in_uom found: %', v_function_count;
    
    -- List all functions with that name and their arguments
    RAISE NOTICE '';
    RAISE NOTICE '3. Function signatures found:';
    FOR rec IN
        SELECT pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = 'get_unit_cost_in_uom'
    LOOP
        RAISE NOTICE '   - get_unit_cost_in_uom(%)', rec.args;
    END LOOP;
    
    -- Try to call the function with test parameters (will fail if function doesn't exist)
    BEGIN
        -- This will raise an error if function doesn't exist, but we catch it
        SELECT public.get_unit_cost_in_uom(v_test_uuid, 'm', v_test_uuid) INTO v_test_result;
        RAISE NOTICE '';
        RAISE NOTICE '4. ✅ Function is callable (test returned: %)', v_test_result;
    EXCEPTION
        WHEN undefined_function THEN
            RAISE NOTICE '';
            RAISE WARNING '4. ❌ Function is NOT callable: undefined_function';
        WHEN OTHERS THEN
            RAISE NOTICE '';
            RAISE NOTICE '4. ⚠️  Function exists but test call failed: %', SQLERRM;
            -- This is actually OK - the function exists, it just can't execute with our test params
            RAISE NOTICE '   (This is expected if the test UUID doesn''t exist in CatalogItems)';
    END;
    
    RAISE NOTICE '';
    
    IF v_function_count = 0 THEN
        RAISE EXCEPTION '❌ Function get_unit_cost_in_uom does not exist. Please run migration 168 first.';
    END IF;
    
    RAISE NOTICE '✅ Diagnostic complete. Function appears to be available.';
END $$;

