-- ========================================
-- FIND: List Available Sale Orders
-- ========================================
-- This script lists all Sale Orders so you can find the correct one
-- ========================================

-- Step 1: List all Sale Orders (recent first)
SELECT 
  'Step 1: All Sale Orders' as check_name,
  so.sale_order_no,
  so.id as sale_order_id,
  so.organization_id,
  so.created_at,
  so.status,
  COUNT(sol.id) as line_count,
  COUNT(ql.id) as quote_line_count
FROM "SaleOrders" so
  LEFT JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
WHERE so.deleted = false
GROUP BY so.sale_order_no, so.id, so.organization_id, so.created_at, so.status
ORDER BY so.created_at DESC
LIMIT 20;

-- Step 2: Show Sale Orders with QuoteLines and ProductTypes
SELECT 
  'Step 2: Sale Orders with QuoteLines' as check_name,
  so.sale_order_no,
  ql.id as quote_line_id,
  pt.code as product_type_code,
  pt.name as product_type_name,
  ql.organization_id,
  bt.id as bom_template_id,
  bt.name as bom_template_name,
  COUNT(bc.id) as bom_component_count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
  LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.deleted = false
GROUP BY so.sale_order_no, so.created_at, ql.id, pt.code, pt.name, ql.organization_id, bt.id, bt.name
ORDER BY so.created_at DESC, so.sale_order_no
LIMIT 20;

-- Step 3: Show Sale Orders that might have BOM issues (no BOMTemplate or 0 components)
SELECT 
  'Step 3: Sale Orders with Potential BOM Issues' as check_name,
  so.sale_order_no,
  ql.id as quote_line_id,
  pt.code as product_type_code,
  pt.name as product_type_name,
  CASE 
    WHEN bt.id IS NULL THEN '❌ NO BOMTemplate'
    WHEN COUNT(bc.id) = 0 THEN '❌ BOMTemplate has 0 components'
    ELSE '✅ OK'
  END as issue_status,
  COUNT(bc.id) as bom_component_count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
  LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.deleted = false
GROUP BY so.sale_order_no, so.created_at, ql.id, pt.code, pt.name, bt.id
HAVING bt.id IS NULL OR COUNT(bc.id) = 0
ORDER BY so.created_at DESC
LIMIT 20;

-- ========================================
-- INSTRUCTIONS
-- ========================================
-- 
-- 1. Review Step 1 to find your Sale Order number
-- 2. Review Step 2 to see which Sale Orders have QuoteLines and BOMTemplates
-- 3. Review Step 3 to find Sale Orders that need fixing (no BOMTemplate or 0 components)
-- 4. Copy the correct sale_order_no and use it in CREATE_AND_FIX_BOM_TEMPLATE.sql
--
-- ========================================

