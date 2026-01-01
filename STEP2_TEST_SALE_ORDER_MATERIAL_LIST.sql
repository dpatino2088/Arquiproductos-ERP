-- STEP 2: Test SaleOrderMaterialList view with a real sale_order_id
-- Replace 'YOUR_SALE_ORDER_ID_HERE' with an actual UUID from the previous query

SELECT 
  sale_order_id,
  category_code,
  catalog_item_id,
  sku,
  item_name,
  uom,
  total_qty,
  avg_unit_cost_exw,
  total_cost_exw
FROM "SaleOrderMaterialList"
WHERE sale_order_id = 'YOUR_SALE_ORDER_ID_HERE'
ORDER BY category_code, sku;

-- Example with a specific sale_order_id (replace with actual ID):
-- WHERE sale_order_id = '123e4567-e89b-12d3-a456-426614174000'








