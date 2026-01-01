-- ========================================
-- QUICK CHECK: Why Only Fabrics in BOM?
-- ========================================
-- This simplified script checks the 3 most likely causes
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

-- ========================================
-- CHECK 1: Does BOMTemplate have components other than fabric?
-- ========================================
SELECT 
  'CHECK 1: BOMTemplate Components' as check_name,
  bc.component_role,
  COUNT(*) as count,
  CASE 
    WHEN COUNT(*) = 0 THEN '❌ PROBLEM: No components found'
    WHEN COUNT(*) = 1 AND bc.component_role = 'fabric' THEN '❌ PROBLEM: Only fabric component'
    WHEN COUNT(*) > 1 THEN '✅ OK: Multiple component types'
    ELSE '⚠️ WARNING: Check manually'
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
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bc.component_role
ORDER BY 
  CASE bc.component_role
    WHEN 'fabric' THEN 1
    WHEN 'operating_system_drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_bar' THEN 5
    ELSE 99
  END;

-- ========================================
-- CHECK 2: Is QuoteLine configuration complete?
-- ========================================
SELECT 
  'CHECK 2: QuoteLine Configuration' as check_name,
  ql.id as quote_line_id,
  CASE 
    WHEN ql.drive_type IS NULL THEN '❌ MISSING: drive_type'
    WHEN ql.cassette IS NULL THEN '❌ MISSING: cassette'
    WHEN ql.side_channel IS NULL THEN '❌ MISSING: side_channel'
    WHEN ql.hardware_color IS NULL THEN '❌ MISSING: hardware_color'
    WHEN ql.bottom_rail_type IS NULL THEN '❌ MISSING: bottom_rail_type (will block BOM components)'
    ELSE '✅ OK: All config fields present'
  END as status,
  ql.drive_type,
  ql.cassette,
  ql.cassette_type,
  ql.side_channel,
  ql.side_channel_type,
  ql.hardware_color,
  ql.bottom_rail_type
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false;

-- ========================================
-- CHECK 3: Do BOMComponents have component_item_id or auto_select?
-- ========================================
SELECT 
  'CHECK 3: BOMComponent Resolution' as check_name,
  bc.component_role,
  COUNT(*) as total,
  COUNT(CASE WHEN bc.component_item_id IS NOT NULL THEN 1 END) as has_item_id,
  COUNT(CASE WHEN bc.auto_select = true AND bc.sku_resolution_rule IS NOT NULL THEN 1 END) as has_auto_select,
  COUNT(CASE WHEN bc.component_item_id IS NULL AND (bc.auto_select = false OR bc.sku_resolution_rule IS NULL) THEN 1 END) as cannot_resolve,
  CASE 
    WHEN COUNT(CASE WHEN bc.component_item_id IS NULL AND (bc.auto_select = false OR bc.sku_resolution_rule IS NULL) THEN 1 END) > 0 
    THEN '❌ PROBLEM: Some components cannot be resolved'
    ELSE '✅ OK: All components can be resolved'
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
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bc.component_role
ORDER BY 
  CASE bc.component_role
    WHEN 'fabric' THEN 1
    WHEN 'operating_system_drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_bar' THEN 5
    ELSE 99
  END;

-- ========================================
-- SUMMARY: What to do next
-- ========================================
-- 
-- IF CHECK 1 shows "Only fabric component":
--   → Problem: BOMTemplate is incomplete
--   → Solution: Add BOMComponents for drive, tube, bracket, etc.
--
-- IF CHECK 2 shows "MISSING" fields:
--   → Problem: Configuration not saved to QuoteLines
--   → Solution: Fix handleProductConfigComplete in QuoteNew.tsx
--
-- IF CHECK 3 shows "cannot be resolved":
--   → Problem: BOMComponents missing component_item_id or auto_select rule
--   → Solution: Map BOMComponents to CatalogItems or add resolution rules
--
-- ========================================

