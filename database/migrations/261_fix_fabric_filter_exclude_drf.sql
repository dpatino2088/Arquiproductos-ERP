-- ====================================================
-- Migration 261: Fix Fabric Filter to Exclude DRF (Dual Shade)
-- ====================================================
-- Updates resolve_bom_role_to_sku() to exclude DRF-prefixed SKUs
-- (Dual Shade fabrics) when resolving Roller Shade fabric
-- ====================================================

BEGIN;

-- Drop and recreate function with improved fabric filter
DROP FUNCTION IF EXISTS public.resolve_bom_role_to_sku CASCADE;

-- Get the current function and modify just the fabric section
DO $$
DECLARE
    v_func_sql text;
BEGIN
    -- Get function definition
    SELECT pg_get_functiondef(oid) INTO v_func_sql
    FROM pg_proc
    WHERE proname = 'resolve_bom_role_to_sku'
    AND pronamespace = 'public'::regnamespace;
    
    IF v_func_sql IS NULL THEN
        RAISE EXCEPTION 'Function resolve_bom_role_to_sku not found. Please run migration 260 first.';
    END IF;
    
    -- Replace the fabric filter to exclude DRF-prefixed SKUs
    v_func_sql := replace(v_func_sql,
        E'            AND NOT (sku ILIKE ''%DUAL%'' OR item_name ILIKE ''%DUAL%'')',
        E'            AND NOT (sku ILIKE ''%DUAL%'' OR item_name ILIKE ''%DUAL%'' OR sku ILIKE ''DRF%'' OR item_name ILIKE ''DRF%'')');
    
    -- Also update the condition to be more explicit
    v_func_sql := replace(v_func_sql,
        E'            AND NOT (p_product_type_name ILIKE ''%roller%shade%'' AND (sku ILIKE ''%DUAL%'' OR item_name ILIKE ''%DUAL%''))',
        E'            AND NOT (p_product_type_name ILIKE ''%roller%shade%'' AND (sku ILIKE ''%DUAL%'' OR item_name ILIKE ''%DUAL%'' OR sku ILIKE ''DRF%'' OR item_name ILIKE ''DRF%''))');
    
    -- Execute the modified function
    EXECUTE v_func_sql;
    
    RAISE NOTICE '✅ Updated fabric filter to exclude DRF-prefixed SKUs (Dual Shade)';
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Failed to auto-update function: %', SQLERRM;
        RAISE NOTICE 'Please manually update the fabric section to exclude DRF-prefixed SKUs.';
        RAISE;
END $$;

COMMIT;


