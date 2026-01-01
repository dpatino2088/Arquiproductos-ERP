-- STEP 1: Get a valid sale_order_id to test SaleOrderMaterialList
-- Run this query first to get a sale_order_id

SELECT 
  id as sale_order_id,
  sale_order_no,
  customer_id,
  status,
  created_at
FROM "SaleOrders"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 5;

-- Then use one of the IDs from the results in the next query








