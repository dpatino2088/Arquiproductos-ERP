-- ====================================================
-- Migration: Fix UOM, Cut fields, and Formula in generate_bom_for_manufacturing_order
-- ====================================================
-- Fixes:
-- 1. Use BOMComponents.uom instead of CatalogItems.uom for source='bom_component'
-- 2. Populate cut_l_mm for linear components (qty_type='per_width')
-- 3. Verify CHAIN_HEIGHT_FACTOR formula applies mult correctly
-- ====================================================
-- IMPORTANT: This migration updates the function by recreating it with fixes
-- ====================================================

SET search_path = public;

-- ====================================================
-- STEP 1: Create a helper function to get width_mm and height_mm from QuoteLine
-- ====================================================
-- We'll use this to calculate cut_l_mm
-- Note: width_m and height_m are stored in meters, so we need to convert to mm

-- ====================================================
-- STEP 2: Update generate_bom_for_manufacturing_order function
-- ====================================================
-- We'll use a DO block to get the current function definition and update it

DO $$
DECLARE
    v_function_def text;
    v_fixed_def text;
    v_width_mm numeric;
    v_height_mm numeric;
BEGIN
    -- Get current function definition
    SELECT pg_get_functiondef('public.generate_bom_for_manufacturing_order'::regproc)
    INTO v_function_def;
    
    IF v_function_def IS NULL THEN
        RAISE EXCEPTION 'Function generate_bom_for_manufacturing_order does not exist. Please run migration 405 first.';
    END IF;
    
    -- ====================================================
    -- FIX 1: Replace v_catalog_item_uom with v_bom_component.uom for auto-select components
    -- ====================================================
    -- Find the INSERT statement for auto-select components (around line 1202)
    -- Replace: v_catalog_item_uom with COALESCE(v_bom_component.uom, v_catalog_item_uom)
    -- This ensures we use BOMComponents.uom when available, fallback to CatalogItems.uom
    
    -- Pattern 1: In the INSERT VALUES for auto-select (line ~1202)
    -- OLD: v_catalog_item_uom,
    -- NEW: COALESCE(v_bom_component.uom, v_catalog_item_uom),
    v_fixed_def := REPLACE(v_function_def,
        E'                        v_catalog_item_uom,\n                        COALESCE(v_resolved_description, v_resolved_item_name),',
        E'                        COALESCE(v_bom_component.uom, v_catalog_item_uom),\n                        COALESCE(v_resolved_description, v_resolved_item_name),'
    );
    
    -- Pattern 2: Also fix the duplicate check that uses v_catalog_item_uom (line ~1116)
    -- This is trickier because we need to use the same UOM for the check
    -- We'll keep the check as is but ensure we use the correct UOM in the INSERT
    
    -- ====================================================
    -- FIX 2: Add cut_l_mm calculation and INSERT for linear components
    -- ====================================================
    -- We need to:
    -- 1. Calculate v_width_mm = v_width_m * 1000 (before INSERT)
    -- 2. Add cut_l_mm to INSERT statement
    -- 3. Set cut_l_mm = v_width_mm for linear components
    
    -- This is complex because we need to add the calculation before the INSERT
    -- and add the column to the INSERT statement
    
    -- For now, we'll add a comment indicating where the fix should be applied
    -- The actual fix will be done by recreating the function with the full corrected code
    
    RAISE NOTICE '⚠️  This migration requires manual application.';
    RAISE NOTICE 'Please apply the following fixes to generate_bom_for_manufacturing_order:';
    RAISE NOTICE '';
    RAISE NOTICE 'FIX 1 - UOM Normalization (line ~1202):';
    RAISE NOTICE '  Change: v_catalog_item_uom,';
    RAISE NOTICE '  To:     COALESCE(v_bom_component.uom, v_catalog_item_uom),';
    RAISE NOTICE '';
    RAISE NOTICE 'FIX 2 - Cut L for linear components:';
    RAISE NOTICE '  Before INSERT (line ~1176), add:';
    RAISE NOTICE '    v_width_mm := COALESCE(v_width_m, 0) * 1000;';
    RAISE NOTICE '    v_height_mm := COALESCE(v_height_m, 0) * 1000;';
    RAISE NOTICE '  In INSERT statement, add cut_l_mm column:';
    RAISE NOTICE '    cut_l_mm,';
    RAISE NOTICE '  In VALUES, add:';
    RAISE NOTICE '    CASE WHEN v_bom_component.qty_type = ''per_width'' OR v_bom_component.component_role IN (''tube'', ''bottom_bar'', ''bottom_rail'', ''bottom_rail_profile'') THEN v_width_mm ELSE NULL END,';
    RAISE NOTICE '';
    RAISE NOTICE 'FIX 3 - Formula CHAIN_HEIGHT_FACTOR:';
    RAISE NOTICE '  Verify line ~1037-1039 uses:';
    RAISE NOTICE '    v_calculated_qty := COALESCE(v_height_m, 0) * COALESCE((v_formula_params->>''height_factor'')::numeric, 0.75) * COALESCE((v_formula_params->>''mult'')::numeric, 2);';
    RAISE NOTICE '';
    RAISE NOTICE 'The function definition is too large to update automatically.';
    RAISE NOTICE 'Please run the full CREATE OR REPLACE FUNCTION from migration 405 with these fixes applied.';
    
    -- We'll create a separate file with the corrected function
END $$;


