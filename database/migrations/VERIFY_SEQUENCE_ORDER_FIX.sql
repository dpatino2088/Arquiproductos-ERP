-- ====================================================
-- Verification: Check if sequence_order fix was applied
-- ====================================================
-- Run this to verify that the function no longer references sequence_order
-- ====================================================

SET search_path = public;

-- Check if function exists
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public'
            AND p.proname = 'generate_bom_for_manufacturing_order'
        ) THEN '✅ Function exists'
        ELSE '❌ Function does not exist'
    END AS function_status;

-- Get function definition and check for sequence_order references
DO $$
DECLARE
    v_function_def text;
    v_has_sequence_order boolean := false;
BEGIN
    -- Get function definition
    SELECT pg_get_functiondef('public.generate_bom_for_manufacturing_order'::regproc)
    INTO v_function_def;
    
    IF v_function_def IS NULL THEN
        RAISE NOTICE '❌ Function does not exist';
        RETURN;
    END IF;
    
    -- Check for sequence_order references
    IF v_function_def LIKE '%cibl.sequence_order%' THEN
        v_has_sequence_order := true;
    END IF;
    
    IF v_has_sequence_order THEN
        RAISE NOTICE '❌ Function still contains sequence_order references';
        RAISE NOTICE 'Please run QUICK_FIX_SEQUENCE_ORDER.sql again or migration 405';
    ELSE
        RAISE NOTICE '✅ Function does NOT contain sequence_order references';
        RAISE NOTICE 'The fix has been applied successfully!';
    END IF;
    
    -- Check for created_at in ORDER BY (should be there)
    IF v_function_def LIKE '%ORDER BY cibl.created_at%' THEN
        RAISE NOTICE '✅ Function uses ORDER BY cibl.created_at (correct)';
    ELSE
        RAISE NOTICE '⚠️  Function does not use ORDER BY cibl.created_at';
    END IF;
END $$;


