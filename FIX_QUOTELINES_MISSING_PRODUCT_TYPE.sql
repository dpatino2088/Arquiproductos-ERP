-- ========================================
-- FIX: QuoteLines with Missing product_type_id
-- ========================================
-- This script identifies and helps fix QuoteLines that are missing product_type_id
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

-- Step 1: Show QuoteLines with missing product_type_id
SELECT 
  'Step 1: QuoteLines Missing product_type_id' as check_name,
  so.sale_order_no,
  ql.id as quote_line_id,
  ql.product_type_id,
  ql.product_type,
  ql.catalog_item_id,
  ci.item_name as catalog_item_name,
  ci.sku as catalog_item_sku
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
  AND (ql.product_type_id IS NULL OR ql.product_type IS NULL)
ORDER BY ql.created_at DESC;

-- Step 2: Try to find ProductType from CatalogItem
SELECT 
  'Step 2: Suggested ProductType from CatalogItem' as check_name,
  ql.id as quote_line_id,
  ci.id as catalog_item_id,
  ci.sku,
  ci.item_name,
  cipt.product_type_id,
  pt.code as product_type_code,
  pt.name as product_type_name
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
  LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
  LEFT JOIN "ProductTypes" pt ON pt.id = cipt.product_type_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
  AND (ql.product_type_id IS NULL OR ql.product_type IS NULL)
ORDER BY ql.created_at DESC;

-- Step 3: Example UPDATE statement (uncomment and modify as needed)
/*
-- Update QuoteLine with product_type_id from CatalogItemProductTypes
UPDATE "QuoteLines" ql
SET 
  product_type_id = (
    SELECT cipt.product_type_id
    FROM "CatalogItemProductTypes" cipt
    WHERE cipt.catalog_item_id = ql.catalog_item_id
    LIMIT 1
  ),
  product_type = (
    SELECT pt.code
    FROM "CatalogItemProductTypes" cipt
    INNER JOIN "ProductTypes" pt ON pt.id = cipt.product_type_id
    WHERE cipt.catalog_item_id = ql.catalog_item_id
    LIMIT 1
  ),
  updated_at = NOW()
WHERE ql.id = 'QUOTE_LINE_ID_HERE'::uuid
  AND ql.product_type_id IS NULL;
*/

-- ========================================
-- INSTRUCTIONS
-- ========================================
-- 
-- 1. Review Step 1 to see which QuoteLines are missing product_type_id
-- 2. Review Step 2 to see suggested ProductTypes from CatalogItems
-- 3. Use Step 3 as a template to update QuoteLines with the correct product_type_id
-- 4. After fixing, run CREATE_AND_FIX_BOM_TEMPLATE.sql again
--
-- ========================================








