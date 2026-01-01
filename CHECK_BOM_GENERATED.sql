-- ========================================
-- CHECK: What BOM Components Were Generated
-- ========================================
-- This script shows what components were actually generated
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

-- Step 1: What components were generated in QuoteLineComponents?
SELECT 
  'Step 1: Components Generated' as check_name,
  qlc.component_role,
  qlc.qty,
  qlc.uom,
  ci.sku,
  ci.item_name
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.source = 'configured_component' 
    AND qlc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
ORDER BY 
  CASE qlc.component_role
    WHEN 'fabric' THEN 1
    WHEN 'operating_system_drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_bar' THEN 5
    ELSE 99
  END;

-- Step 2: Which BOMTemplate components were NOT generated?
SELECT 
  'Step 2: Components NOT Generated' as check_name,
  bc.component_role,
  bc.block_type,
  bc.block_condition,
  bc.component_item_id,
  bc.auto_select,
  bc.sku_resolution_rule,
  CASE 
    WHEN bc.component_item_id IS NULL AND (bc.auto_select = false OR bc.sku_resolution_rule IS NULL) THEN '❌ Cannot resolve (no item_id, no auto_select)'
    WHEN bc.block_condition IS NOT NULL THEN '⚠️ Has block_condition (may be blocked)'
    WHEN bc.component_item_id IS NOT NULL THEN '✅ Has item_id'
    WHEN bc.auto_select = true THEN '✅ Has auto_select'
    ELSE '⚠️ Unknown'
  END as resolution_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id 
    AND bc.deleted = false
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.component_role = bc.component_role
    AND qlc.source = 'configured_component'
    AND qlc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
  AND qlc.id IS NULL  -- Only show components that were NOT generated
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

-- ========================================
-- INTERPRETATION
-- ========================================
-- 
-- Step 1: Shows what was actually generated
--   - If only 'fabric' appears → Problem: Only fabric was generated
--   - If multiple components appear → Good: Generation is working
--
-- Step 2: Shows which components from BOMTemplate were NOT generated
--   - If shows "Cannot resolve" → Need to add component_item_id or auto_select
--   - If shows "Has block_condition" → May be blocked by configuration mismatch
--   - If shows "Has item_id" or "Has auto_select" → Should work, check block_condition
--
-- ========================================








