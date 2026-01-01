-- ========================================
-- FIX: Update QuoteLines with Missing product_type_id (AUTO)
-- ========================================
-- This script automatically updates QuoteLines that are missing product_type_id
-- by getting it from their associated CatalogItems
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

DO $$
DECLARE
  v_updated_count integer;
  v_quote_line_id uuid;
  v_product_type_id uuid;
  v_product_type_code text;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FIXING QuoteLines with Missing product_type_id';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Update QuoteLines with product_type_id from CatalogItemProductTypes
  FOR v_quote_line_id, v_product_type_id, v_product_type_code IN
    SELECT 
      ql.id,
      cipt.product_type_id,
      pt.code
    FROM "SaleOrders" so
      INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
      INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
      INNER JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
      INNER JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
      INNER JOIN "ProductTypes" pt ON pt.id = cipt.product_type_id
    WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
      AND so.deleted = false
      AND (ql.product_type_id IS NULL OR ql.product_type IS NULL)
  LOOP
    UPDATE "QuoteLines"
    SET 
      product_type_id = v_product_type_id,
      product_type = v_product_type_code,
      updated_at = NOW()
    WHERE id = v_quote_line_id;

    RAISE NOTICE '✅ Updated QuoteLine % with product_type_id: % (%)', 
      v_quote_line_id, v_product_type_id, v_product_type_code;
  END LOOP;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  
  IF v_updated_count = 0 THEN
    RAISE NOTICE 'ℹ️  No QuoteLines needed updating';
  ELSE
    RAISE NOTICE '';
    RAISE NOTICE '✅ Updated % QuoteLine(s)', v_updated_count;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✨ PROCESS COMPLETED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Next step: Run CREATE_AND_FIX_BOM_TEMPLATE.sql';
  RAISE NOTICE '';

END $$;

-- Verification: Show updated QuoteLines
SELECT 
  'Verification: Updated QuoteLines' as check_name,
  so.sale_order_no,
  ql.id as quote_line_id,
  ql.product_type_id,
  ql.product_type,
  pt.code as product_type_code,
  pt.name as product_type_name,
  CASE 
    WHEN ql.product_type_id IS NULL THEN '❌ STILL MISSING'
    ELSE '✅ FIXED'
  END as status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
ORDER BY ql.created_at DESC;








