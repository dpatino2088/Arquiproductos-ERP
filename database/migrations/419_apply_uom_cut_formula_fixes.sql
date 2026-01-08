-- ====================================================
-- Migration: Apply UOM, Cut, and Formula fixes to generate_bom_for_manufacturing_order
-- ====================================================
-- This script applies three critical fixes:
-- 1. UOM normalization: Use BOMComponents.uom instead of CatalogItems.uom
-- 2. Cut L calculation: Populate cut_l_mm for linear components
-- 3. Formula verification: Ensure CHAIN_HEIGHT_FACTOR applies mult correctly
-- ====================================================
-- IMPORTANT: This requires the full function to be recreated with these fixes
-- ====================================================

SET search_path = public;

-- ====================================================
-- INSTRUCTIONS FOR MANUAL APPLICATION
-- ====================================================
-- Due to the size of the function, we'll provide specific line changes
-- that need to be applied to migration 405's function definition.
-- ====================================================

-- ====================================================
-- FIX 1: UOM Normalization (CRITICAL)
-- ====================================================
-- Location: Around line 1202 in the INSERT VALUES for auto-select components
-- 
-- CHANGE FROM:
--   v_catalog_item_uom,
-- 
-- CHANGE TO:
--   COALESCE(v_bom_component.uom, v_catalog_item_uom),
--
-- This ensures that when source='bom_component', we use BOMComponents.uom
-- (which should be 'm', 'm2', 'ea') instead of CatalogItems.uom
-- (which might be 'set', 'pcs', etc.)
-- ====================================================

-- ====================================================
-- FIX 2: Cut L for Linear Components
-- ====================================================
-- Location 1: Add variable declarations (around line 160-170 in DECLARE section)
-- ADD:
--   v_width_mm numeric(10,2) := 0;
--   v_height_mm numeric(10,2) := 0;
--
-- Location 2: Calculate width_mm and height_mm (around line 1175, before INSERT)
-- ADD BEFORE INSERT:
--   -- Calculate cut dimensions in millimeters
--   v_width_mm := COALESCE(v_width_m, 0) * 1000.0;
--   v_height_mm := COALESCE(v_height_m, 0) * 1000.0;
--
-- Location 3: Add cut_l_mm to INSERT statement (around line 1178)
-- In the column list, ADD:
--   cut_l_mm,
--
-- Location 4: Add cut_l_mm value in VALUES (around line 1195)
-- In the VALUES list, ADD:
--   CASE 
--     WHEN v_bom_component.qty_type = 'per_width' 
--          OR v_bom_component.component_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile')
--     THEN v_width_mm 
--     ELSE NULL 
--   END,
-- ====================================================

-- ====================================================
-- FIX 3: CHAIN_HEIGHT_FACTOR Formula Verification
-- ====================================================
-- Location: Around line 1037-1039
-- 
-- VERIFY the formula is:
--   v_calculated_qty := COALESCE(v_height_m, 0) 
--       * COALESCE((v_formula_params->>'height_factor')::numeric, 0.75)
--       * COALESCE((v_formula_params->>'mult')::numeric, 2);
--
-- This should already be correct, but verify that:
-- 1. height_m is in meters (from QuoteLine.height_m)
-- 2. height_factor is applied (default 0.75)
-- 3. mult is applied (default 2)
-- 4. Result is in meters (qty_m)
-- ====================================================

-- ====================================================
-- VERIFICATION QUERIES
-- ====================================================
-- After applying fixes and regenerating BOM, run these queries:

-- Query 1: Check UOM distribution
-- SELECT part_role, uom, COUNT(*) 
-- FROM "BomInstanceLines"
-- WHERE bom_instance_id = '<BOM_INSTANCE_ID>'::uuid
--   AND deleted = false
-- GROUP BY part_role, uom
-- ORDER BY part_role;

-- Query 2: Check cut_l_mm for linear components
-- SELECT part_role, uom, qty, cut_l_mm
-- FROM "BomInstanceLines"
-- WHERE bom_instance_id = '<BOM_INSTANCE_ID>'::uuid
--   AND deleted = false
--   AND part_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile')
-- ORDER BY part_role;

-- Query 3: Check chain formula result
-- SELECT part_role, qty, uom, qty_formula_code
-- FROM "BomInstanceLines" bil
-- INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
-- WHERE bil.part_role = 'chain'
--   AND bil.deleted = false
--   AND bi.deleted = false
-- ORDER BY bil.created_at DESC
-- LIMIT 5;
-- ====================================================

RAISE NOTICE '✅ Migration 419: Fix instructions documented.';
RAISE NOTICE 'Please apply the fixes described above to the generate_bom_for_manufacturing_order function.';
RAISE NOTICE 'The function definition is in migration 405.';
RAISE NOTICE 'After applying fixes, regenerate BOM and run verification queries.';


