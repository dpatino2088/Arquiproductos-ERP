-- ====================================================
-- Migration: Fix sequence_order reference in generate_bom_for_manufacturing_order
-- ====================================================
-- Problem: Function references cibl.sequence_order which doesn't exist
-- Solution: Update ORDER BY clauses to use created_at instead
-- ====================================================
-- IMPORTANT: This is a quick fix. The full function is in migration 405.
-- This script updates the function body to fix the ORDER BY clauses.
-- ====================================================

SET search_path = public;

-- ====================================================
-- Quick Fix: Update function body using text replacement
-- ====================================================
-- Since we can't directly modify function body, we need to:
-- 1. Get the current function definition
-- 2. Replace the problematic ORDER BY clauses
-- 3. Recreate the function

-- However, the safest approach is to run the full CREATE OR REPLACE FUNCTION
-- from migration 405 (which already has the fix).

-- For immediate fix, run this in Supabase SQL Editor:
-- It will update the function by recreating it with the corrected ORDER BY clauses.

DO $$
DECLARE
    v_function_body text;
    v_updated_body text;
BEGIN
    -- Get current function definition
    SELECT pg_get_functiondef('public.generate_bom_for_manufacturing_order'::regproc)
    INTO v_function_body;
    
    IF v_function_body IS NULL THEN
        RAISE EXCEPTION 'Function generate_bom_for_manufacturing_order does not exist';
    END IF;
    
    -- Replace ORDER BY cibl.sequence_order with ORDER BY cibl.created_at
    v_updated_body := REPLACE(v_function_body, 
        'ORDER BY cibl.sequence_order',
        'ORDER BY cibl.created_at'
    );
    
    -- If no replacement was made, the function might already be fixed
    IF v_updated_body = v_function_body THEN
        RAISE NOTICE '⚠️  No sequence_order references found. Function might already be fixed.';
        RAISE NOTICE '    Checking for other variations...';
        
        -- Try other possible variations
        v_updated_body := REPLACE(v_function_body, 
            'ORDER BY cibl.sequence_order ASC',
            'ORDER BY cibl.created_at'
        );
        v_updated_body := REPLACE(v_updated_body, 
            'ORDER BY cibl.sequence_order DESC',
            'ORDER BY cibl.created_at'
        );
        v_updated_body := REPLACE(v_updated_body, 
            'ORDER BY COALESCE(cibl.sequence_order, 0)',
            'ORDER BY cibl.created_at'
        );
    END IF;
    
    -- Execute the updated function definition
    IF v_updated_body != v_function_body THEN
        EXECUTE v_updated_body;
        RAISE NOTICE '✅ Function updated successfully. Removed sequence_order references.';
    ELSE
        RAISE NOTICE '⚠️  Function body unchanged. Please check manually or run migration 405.';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error updating function: %', SQLERRM;
        RAISE NOTICE 'Please run the full CREATE OR REPLACE FUNCTION from migration 405 instead.';
END $$;
