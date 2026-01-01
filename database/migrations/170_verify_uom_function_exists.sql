-- ====================================================
-- Migration: Verify UOM Function Exists
-- ====================================================
-- Quick verification script to check if get_unit_cost_in_uom function exists
-- ====================================================

DO $$
DECLARE
    v_function_exists boolean;
    v_table_exists boolean;
BEGIN
    -- Check if function exists
    SELECT EXISTS (
        SELECT 1 
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = 'get_unit_cost_in_uom'
        AND pg_get_function_arguments(p.oid) LIKE '%uuid, text, uuid%'
    ) INTO v_function_exists;
    
    -- Check if UomConversions table exists
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'UomConversions'
    ) INTO v_table_exists;
    
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Verification Results:';
    RAISE NOTICE '   - UomConversions table exists: %', v_table_exists;
    RAISE NOTICE '   - get_unit_cost_in_uom function exists: %', v_function_exists;
    RAISE NOTICE '';
    
    IF NOT v_table_exists THEN
        RAISE WARNING '⚠️  UomConversions table does not exist. Migration 168 may not have run.';
    END IF;
    
    IF NOT v_function_exists THEN
        RAISE EXCEPTION '❌ get_unit_cost_in_uom function does not exist. Please execute migration 168 first!';
    END IF;
    
    RAISE NOTICE '✅ All prerequisites for migration 169 are met!';
END $$;









