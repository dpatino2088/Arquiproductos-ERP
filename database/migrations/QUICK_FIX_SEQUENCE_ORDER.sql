-- ====================================================
-- QUICK FIX: Remove sequence_order from generate_bom_for_manufacturing_order
-- ====================================================
-- Execute this in Supabase SQL Editor to fix the function immediately
-- ====================================================

SET search_path = public;

-- This script will:
-- 1. Get the current function definition
-- 2. Replace ORDER BY cibl.sequence_order with ORDER BY cibl.created_at
-- 3. Recreate the function with the fix

DO $$
DECLARE
    v_function_def text;
    v_fixed_def text;
BEGIN
    -- Get current function definition
    SELECT pg_get_functiondef('public.generate_bom_for_manufacturing_order'::regproc)
    INTO v_function_def;
    
    IF v_function_def IS NULL THEN
        RAISE EXCEPTION 'Function generate_bom_for_manufacturing_order does not exist. Please run migration 405 first.';
    END IF;
    
    -- Replace all variations of sequence_order in ORDER BY
    v_fixed_def := v_function_def;
    v_fixed_def := REPLACE(v_fixed_def, 'ORDER BY cibl.sequence_order', 'ORDER BY cibl.created_at');
    v_fixed_def := REPLACE(v_fixed_def, 'ORDER BY cibl.sequence_order ASC', 'ORDER BY cibl.created_at');
    v_fixed_def := REPLACE(v_fixed_def, 'ORDER BY cibl.sequence_order DESC', 'ORDER BY cibl.created_at');
    v_fixed_def := REPLACE(v_fixed_def, 'ORDER BY COALESCE(cibl.sequence_order, 0)', 'ORDER BY cibl.created_at');
    v_fixed_def := REPLACE(v_fixed_def, 'ORDER BY COALESCE(cibl.sequence_order, 0), cibl.created_at', 'ORDER BY cibl.created_at');
    
    -- Check if any replacement was made
    IF v_fixed_def = v_function_def THEN
        RAISE NOTICE '⚠️  No sequence_order references found. Function might already be fixed.';
        RAISE NOTICE 'Current function definition does not contain sequence_order references.';
    ELSE
        -- Execute the fixed function definition
        EXECUTE v_fixed_def;
        RAISE NOTICE '✅ Function updated successfully! Removed all sequence_order references.';
        RAISE NOTICE 'You can now try generating the BOM again.';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '❌ Error updating function: %', SQLERRM;
        RAISE NOTICE 'Please run the full CREATE OR REPLACE FUNCTION from migration 405 instead.';
        RAISE;
END $$;


