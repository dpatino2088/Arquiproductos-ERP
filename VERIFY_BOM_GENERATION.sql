-- ========================================
-- VERIFY: BOM Generation Status
-- ========================================
-- This script verifies if BOM components are being generated correctly
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

-- Step 1: Check QuoteLineComponents generated
SELECT 
  'Step 1: QuoteLineComponents Generated' as check_name,
  qlc.component_role,
  qlc.source,
  qlc.qty,
  qlc.uom,
  ci.sku,
  ci.item_name,
  COUNT(*) as count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.source = 'configured_component' 
    AND qlc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
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

-- Step 2: Check BOMTemplate components vs QuoteLineComponents
SELECT 
  'Step 2: BOMTemplate Components vs Generated' as check_name,
  bc.component_role,
  bc.block_type,
  bc.block_condition,
  bc.component_item_id,
  bc.auto_select,
  bc.sku_resolution_rule,
  COUNT(DISTINCT bc.id) as bom_template_count,
  COUNT(DISTINCT qlc.id) as generated_count,
  CASE 
    WHEN COUNT(DISTINCT bc.id) > 0 AND COUNT(DISTINCT qlc.id) = 0 THEN '❌ NOT GENERATED'
    WHEN COUNT(DISTINCT bc.id) > 0 AND COUNT(DISTINCT qlc.id) > 0 THEN '✅ GENERATED'
    ELSE '⚠️ NOT IN TEMPLATE'
  END as status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id 
    AND bc.deleted = false
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.component_role = bc.component_role
    AND qlc.source = 'configured_component'
    AND qlc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bc.component_role, bc.block_type, bc.block_condition, bc.component_item_id, bc.auto_select, bc.sku_resolution_rule
ORDER BY 
  CASE bc.component_role
    WHEN 'fabric' THEN 1
    WHEN 'operating_system_drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_bar' THEN 5
    ELSE 99
  END;

-- Step 3: Check QuoteLine configuration
SELECT 
  'Step 3: QuoteLine Configuration' as check_name,
  ql.id as quote_line_id,
  ql.drive_type,
  ql.bottom_rail_type,
  ql.cassette,
  ql.cassette_type,
  ql.side_channel,
  ql.side_channel_type,
  ql.hardware_color,
  CASE 
    WHEN ql.drive_type IS NULL THEN '❌ MISSING: drive_type'
    WHEN ql.bottom_rail_type IS NULL THEN '❌ MISSING: bottom_rail_type'
    WHEN ql.cassette IS NULL THEN '❌ MISSING: cassette'
    WHEN ql.side_channel IS NULL THEN '❌ MISSING: side_channel'
    WHEN ql.hardware_color IS NULL THEN '❌ MISSING: hardware_color'
    ELSE '✅ OK: All config present'
  END as config_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false;

-- ========================================
-- INTERPRETATION
-- ========================================
-- 
-- Step 1: Shows what was actually generated in QuoteLineComponents
--   - If only 'fabric' appears → Problem in generation
--   - If multiple component_role appear → Generation is working
--
-- Step 2: Compares BOMTemplate components with what was generated
--   - If status shows "NOT GENERATED" → Component exists in template but wasn't generated
--   - Possible causes: block_condition mismatch, component_item_id missing, auto_select not working
--
-- Step 3: Shows QuoteLine configuration
--   - If config_status shows "MISSING" → Configuration incomplete, BOM generation will fail
--
-- ========================================








