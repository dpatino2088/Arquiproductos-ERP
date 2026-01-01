-- ========================================
-- TEST: Manual BOM Generation
-- ========================================
-- This script tests generate_configured_bom_for_quote_line manually
-- INSTRUCTIONS: 
-- 1. Replace all placeholder values with actual IDs and values
-- 2. Run the function and check the results
-- 3. Review QuoteLineComponents to see what was generated
-- ========================================

-- INSTRUCTIONS: Replace all placeholder values with actual IDs and values

-- Step 1: Get QuoteLine configuration
SELECT 
  'QuoteLine Configuration' as check_name,
  ql.id,
  ql.product_type_id,
  ql.drive_type,
  ql.bottom_rail_type,
  ql.cassette,
  ql.cassette_type,
  ql.side_channel,
  ql.side_channel_type,
  ql.hardware_color,
  ql.width_m,
  ql.height_m,
  ql.qty
FROM "QuoteLines" ql
WHERE ql.id = 'YOUR_QUOTE_LINE_ID'::uuid -- CHANGE THIS
  AND ql.deleted = false;

-- Step 2: Call generate_configured_bom_for_quote_line manually
-- IMPORTANT: Replace all values with actual data from Step 1
SELECT generate_configured_bom_for_quote_line(
  p_quote_line_id := 'YOUR_QUOTE_LINE_ID'::uuid, -- CHANGE THIS
  p_product_type_id := 'YOUR_PRODUCT_TYPE_ID'::uuid, -- CHANGE THIS
  p_organization_id := 'YOUR_ORGANIZATION_ID'::uuid, -- CHANGE THIS
  p_drive_type := 'motor', -- Replace with actual value from Step 1
  p_bottom_rail_type := 'standard', -- Replace with actual value from Step 1
  p_cassette := false, -- Replace with actual value from Step 1
  p_cassette_type := NULL, -- Replace with actual value from Step 1
  p_side_channel := false, -- Replace with actual value from Step 1
  p_side_channel_type := NULL, -- Replace with actual value from Step 1
  p_hardware_color := 'white', -- Replace with actual value from Step 1
  p_width_m := 2.0, -- Replace with actual value from Step 1
  p_height_m := 1.5, -- Replace with actual value from Step 1
  p_qty := 1 -- Replace with actual value from Step 1
) as bom_generation_result;

-- Step 3: Check QuoteLineComponents generated
SELECT 
  'QuoteLineComponents Generated' as check_name,
  qlc.component_role,
  qlc.source,
  qlc.qty,
  qlc.uom,
  ci.sku,
  ci.item_name,
  COUNT(*) as count
FROM "QuoteLineComponents" qlc
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.quote_line_id = 'YOUR_QUOTE_LINE_ID'::uuid -- CHANGE THIS
  AND qlc.source = 'configured_component'
  AND qlc.deleted = false
GROUP BY qlc.component_role, qlc.source, qlc.qty, qlc.uom, ci.sku, ci.item_name
ORDER BY 
  CASE qlc.component_role
    WHEN 'fabric' THEN 1
    WHEN 'operating_system_drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_bar' THEN 5
    ELSE 99
  END;

-- Step 4: Check for errors in function execution
-- Review the JSONB result from Step 2:
-- - If success = false, check the error message
-- - If success = true, check the count of inserted_components
-- - Compare inserted_components with QuoteLineComponents from Step 3

-- ========================================
-- TROUBLESHOOTING
-- ========================================
-- 
-- If function returns success = false:
--   → Check the error message in the JSONB result
--   → Verify that BOMTemplate exists and is active
--   → Verify that BOMComponents exist
--
-- If function returns success = true but count = 1 (only fabric):
--   → Check STEP 6 of DIAGNOSE_BOM_COMPLETE.sql to see which components are blocked
--   → Verify block_conditions match QuoteLine configuration
--   → Verify component_item_id or auto_select is configured
--
-- If function returns success = true and count > 1 but QuoteLineComponents only shows fabric:
--   → Check if there's a conflict or constraint preventing insertion
--   → Review logs for any warnings
--
-- ========================================

