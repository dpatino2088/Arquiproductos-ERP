-- ========================================
-- FIND: Which BOMTemplate is being used by Sale Order
-- ========================================
-- This script shows which BOMTemplate is associated with the QuoteLine
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

-- Step 1: Show QuoteLine and its ProductType
SELECT 
  'Step 1: QuoteLine Info' as check_name,
  so.sale_order_no,
  ql.id as quote_line_id,
  ql.product_type_id,
  pt.code as product_type_code,
  pt.name as product_type_name,
  ql.organization_id
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false;

-- Step 2: Show ALL BOMTemplates for this ProductType and Organization
SELECT 
  'Step 2: Available BOMTemplates' as check_name,
  bt.id as bom_template_id,
  bt.name as template_name,
  bt.active,
  bt.deleted,
  COUNT(bc.id) as component_count,
  CASE 
    WHEN bt.deleted = true THEN '❌ DELETED'
    WHEN bt.active = false THEN '⚠️ INACTIVE'
    WHEN COUNT(bc.id) = 0 THEN '❌ NO COMPONENTS'
    WHEN COUNT(bc.id) > 0 AND bt.active = true THEN '✅ ACTIVE WITH COMPONENTS'
    ELSE '⚠️ CHECK MANUALLY'
  END as status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bt.id, bt.name, bt.active, bt.deleted
ORDER BY 
  CASE 
    WHEN bt.deleted = true THEN 3
    WHEN bt.active = false THEN 2
    WHEN COUNT(bc.id) = 0 THEN 1
    ELSE 0
  END,
  bt.active DESC,
  COUNT(bc.id) DESC;

-- Step 3: Show which BOMTemplate would be used (active, not deleted, with most components)
SELECT 
  'Step 3: BOMTemplate That Would Be Used' as check_name,
  bt.id as bom_template_id,
  bt.name as template_name,
  bt.active,
  bt.deleted,
  COUNT(bc.id) as component_count,
  STRING_AGG(DISTINCT bc.component_role, ', ' ORDER BY bc.component_role) as component_roles
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bt.id, bt.name, bt.active, bt.deleted
ORDER BY COUNT(bc.id) DESC
LIMIT 1;

-- ========================================
-- INTERPRETATION
-- ========================================
-- 
-- Step 1: Shows the ProductType being used
-- Step 2: Shows ALL BOMTemplates (active, inactive, deleted) for this ProductType
-- Step 3: Shows which BOMTemplate would actually be used (active, not deleted)
--
-- If Step 3 shows component_count = 0:
--   → This is the problem! The BOMTemplate has no components
--   → Solution: Run FIX_BOM_TEMPLATE_COMPONENTS_AUTO.sql
--
-- If Step 3 shows component_count > 0:
--   → BOMTemplate has components, but they're not being generated
--   → Check: FIX_BOM_COMPONENTS_RESOLUTION.sql (component_item_id missing?)
--
-- ========================================








