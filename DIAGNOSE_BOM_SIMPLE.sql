-- ========================================
-- DIAGNOSTIC: BOM Missing Components (Supabase Compatible)
-- ========================================
-- INSTRUCTIONS:
-- 1. Replace 'SO-000003' with your actual Sale Order number
-- 2. Run this in Supabase SQL Editor
-- 3. Share the results
-- ========================================

-- ========================================
-- STEP 1: Find Sale Order and its Lines
-- ========================================

SELECT 
  'STEP 1: Sale Order Lines Configuration' as step,
  sol.id as sale_order_line_id,
  so.sale_order_no,
  sol.product_type_id,
  pt.code as product_type_code,
  pt.name as product_type_name,
  sol.drive_type,
  sol.cassette,
  sol.cassette_type,
  sol.side_channel,
  sol.side_channel_type,
  sol.hardware_color,
  sol.bottom_rail_type,
  sol.width_m,
  sol.height_m,
  sol.catalog_item_id as fabric_id,
  ci.collection_name,
  ci.variant_name
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  LEFT JOIN "ProductTypes" pt ON pt.id = sol.product_type_id
  LEFT JOIN "CatalogItems" ci ON ci.id = sol.catalog_item_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false;

-- ========================================
-- STEP 2: Check BOMTemplate exists
-- ========================================

WITH sale_order_data AS (
  SELECT DISTINCT sol.product_type_id
  FROM "SaleOrders" so
    INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
)
SELECT 
  'STEP 2: BOM Template Status' as step,
  bt.id as bom_template_id,
  bt.name as template_name,
  pt.code as product_type_code,
  pt.name as product_type_name,
  bt.active,
  COUNT(bc.id) as total_components,
  COUNT(CASE WHEN bc.component_role = 'fabric' THEN 1 END) as fabric_count,
  COUNT(CASE WHEN bc.component_role = 'operating_system_drive' THEN 1 END) as drive_count,
  COUNT(CASE WHEN bc.component_role = 'tube' THEN 1 END) as tube_count,
  COUNT(CASE WHEN bc.component_role = 'bracket' THEN 1 END) as bracket_count,
  COUNT(CASE WHEN bc.component_role = 'bottom_bar' THEN 1 END) as bottom_bar_count
FROM "BOMTemplates" bt
  INNER JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.product_type_id IN (SELECT product_type_id FROM sale_order_data)
  AND bt.deleted = false
GROUP BY bt.id, bt.name, pt.code, pt.name, bt.active;

-- ========================================
-- STEP 3: Check BomInstances created
-- ========================================

SELECT 
  'STEP 3: BOM Instances' as step,
  bi.id as bom_instance_id,
  bi.sale_order_line_id,
  bi.bom_template_id,
  sol.drive_type as sol_drive_type,
  sol.hardware_color as sol_hardware_color,
  sol.cassette as sol_cassette,
  sol.side_channel as sol_side_channel,
  sol.bottom_rail_type as sol_bottom_rail_type,
  bi.created_at
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false;

-- ========================================
-- STEP 4: Check BomInstanceLines (What was actually generated)
-- ========================================

SELECT 
  'STEP 4: Generated BOM Lines Summary' as step,
  bil.category_code,
  COUNT(*) as count,
  STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) as skus,
  SUM(bil.qty) as total_qty
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bil.category_code
ORDER BY 
  CASE bil.category_code
    WHEN 'fabric' THEN 1
    WHEN 'drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_rail' THEN 5
    ELSE 99
  END;

-- EXPECTED:
-- - Multiple rows with different part_role and category_code values
-- - category_code should include: fabric, drive, tube, bracket, bottom_rail, etc.
-- - If only 'fabric' appears, BOM generation is incomplete

-- ========================================
-- STEP 5: Detailed BOM Lines (Full detail)
-- ========================================

SELECT 
  'STEP 5: Full BOM Detail' as step,
  bil.part_role,
  bil.category_code,
  bil.resolved_part_id,
  bil.resolved_sku,
  ci.sku as catalog_sku,
  ci.item_name,
  bil.qty,
  bil.uom,
  bil.rule_applied
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
ORDER BY 
  CASE bil.category_code
    WHEN 'fabric' THEN 1
    WHEN 'drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_rail' THEN 5
    WHEN 'cassette' THEN 6
    WHEN 'side_channel' THEN 7
    ELSE 99
  END,
  bil.part_role;

-- ========================================
-- INTERPRETATION GUIDE
-- ========================================
--
-- IF STEP 1 shows NULL values for drive_type, cassette, hardware_color:
--   → Problem: Quote configuration not being saved to SaleOrderLines
--   → Fix: Correct QuoteLines → SaleOrderLines conversion
--
-- IF STEP 2 shows total_components = 1 or low number:
--   → Problem: BOMTemplate is incomplete
--   → Fix: Run seed migration or create BOMComponents manually
--
-- IF STEP 2 shows total_components > 10 BUT STEP 4 only shows category_code='fabric':
--   → Problem: generate_configured_bom function not applying rules correctly
--   → Fix: Review and update the function logic
--
-- IF STEP 4 shows multiple category_codes BUT STEP 5 has NULL resolved_part_id:
--   → Problem: BOMComponents have NULL component_item_id
--   → Fix: Map BOMComponents to actual CatalogItems
--
-- IF STEP 3 shows bi.metadata is empty:
--   → Problem: Configuration not being passed to BomInstance
--   → Fix: Ensure generate_configured_bom receives full config
--
-- ========================================

