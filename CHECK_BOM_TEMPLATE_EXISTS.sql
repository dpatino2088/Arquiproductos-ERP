-- ========================================
-- CHECK: Verify BOMTemplate Exists for Sale Order
-- ========================================
-- This script checks if a BOMTemplate exists and why it might not be found
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

-- Step 1: Check if Sale Order exists
SELECT 
  'Step 1: Sale Order' as check_name,
  so.id as sale_order_id,
  so.sale_order_no,
  so.organization_id,
  so.deleted as so_deleted
FROM "SaleOrders" so
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false;

-- Step 2: Check QuoteLines and ProductTypes
SELECT 
  'Step 2: QuoteLines and ProductTypes' as check_name,
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

-- Step 3: Check ALL BOMTemplates for this ProductType and Organization
SELECT 
  'Step 3: All BOMTemplates (including inactive/deleted)' as check_name,
  bt.id as bom_template_id,
  bt.name as template_name,
  bt.product_type_id,
  pt.code as product_type_code,
  bt.organization_id,
  bt.active,
  bt.deleted,
  COUNT(bc.id) as component_count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
  LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bt.id, bt.name, bt.product_type_id, pt.code, bt.organization_id, bt.active, bt.deleted
ORDER BY bt.active DESC, bt.deleted ASC, bt.created_at DESC;

-- Step 4: Check if BOMTemplate exists but is inactive or deleted
SELECT 
  'Step 4: BOMTemplate Status' as check_name,
  CASE 
    WHEN bt.id IS NULL THEN '❌ NOT FOUND: No BOMTemplate exists for this ProductType and Organization'
    WHEN bt.deleted = true THEN '❌ DELETED: BOMTemplate exists but is deleted'
    WHEN bt.active = false THEN '⚠️ INACTIVE: BOMTemplate exists but is not active'
    WHEN bt.active = true AND bt.deleted = false THEN '✅ ACTIVE: BOMTemplate is active and ready'
    ELSE '⚠️ UNKNOWN: Check manually'
  END as status,
  bt.id as bom_template_id,
  bt.name as template_name,
  bt.active,
  bt.deleted
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
LIMIT 1;

-- Step 5: List ALL BOMTemplates in the organization (for reference)
SELECT 
  'Step 5: All BOMTemplates in Organization' as check_name,
  bt.id as bom_template_id,
  bt.name as template_name,
  pt.code as product_type_code,
  pt.name as product_type_name,
  bt.active,
  bt.deleted,
  COUNT(bc.id) as component_count
FROM "SaleOrders" so
  CROSS JOIN "BOMTemplates" bt
  LEFT JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
  AND bt.organization_id = so.organization_id
GROUP BY bt.id, bt.name, pt.code, pt.name, bt.active, bt.deleted
ORDER BY bt.active DESC, bt.deleted ASC, bt.created_at DESC;

-- ========================================
-- INTERPRETATION
-- ========================================
-- 
-- If Step 1 shows no results:
--   → Sale Order number is incorrect
--
-- If Step 2 shows no product_type_id:
--   → QuoteLine is missing product_type_id
--
-- If Step 3 shows no BOMTemplate:
--   → Need to CREATE a BOMTemplate first
--
-- If Step 3 shows BOMTemplate with active = false:
--   → Need to UPDATE BOMTemplate to set active = true
--
-- If Step 3 shows BOMTemplate with deleted = true:
--   → Need to UPDATE BOMTemplate to set deleted = false
--
-- ========================================








