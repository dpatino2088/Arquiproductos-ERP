-- STEP 1 - DB REALITY CHECK
-- Run these queries in Supabase SQL Editor and paste results

-- 1) Does ManufacturingOrders exist?
SELECT to_regclass('public."ManufacturingOrders"') AS manufacturingorders;

-- 2) Does SaleOrderMaterialList exist?
SELECT to_regclass('public."SaleOrderMaterialList"') AS saleordermateriallist;

-- 3) Show last 5 manufacturing orders (if table exists):
SELECT 
  id, 
  manufacturing_order_no, 
  status, 
  sale_order_id, 
  created_at
FROM "ManufacturingOrders"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 5;








