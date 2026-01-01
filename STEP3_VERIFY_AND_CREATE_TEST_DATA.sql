-- STEP 3: Verify existing data and create test data if needed
-- Run these queries in order

-- 1) Check if we have any Sale Orders
SELECT 
  COUNT(*) as total_sale_orders,
  COUNT(CASE WHEN deleted = false THEN 1 END) as active_sale_orders
FROM "SaleOrders";

-- 2) Check if we have any Sale Orders with BOM data
SELECT 
  so.id as sale_order_id,
  so.sale_order_no,
  COUNT(DISTINCT bi.id) as bom_instances_count,
  COUNT(DISTINCT bil.id) as bom_lines_count
FROM "SaleOrders" so
LEFT JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.deleted = false
GROUP BY so.id, so.sale_order_no
HAVING COUNT(DISTINCT bi.id) > 0
ORDER BY so.created_at DESC
LIMIT 5;

-- 3) Check SaleOrderMaterialList for a specific sale order (if you have one)
-- Replace with an actual sale_order_id from query 2
/*
SELECT 
  sale_order_id,
  category_code,
  sku,
  item_name,
  uom,
  total_qty,
  total_cost_exw
FROM "SaleOrderMaterialList"
WHERE sale_order_id = 'YOUR_SALE_ORDER_ID_HERE'
ORDER BY category_code, sku;
*/

-- 4) Check if we have any Manufacturing Orders
SELECT 
  COUNT(*) as total_manufacturing_orders,
  COUNT(CASE WHEN deleted = false THEN 1 END) as active_manufacturing_orders
FROM "ManufacturingOrders";

-- 5) Show existing Manufacturing Orders with their Sale Orders
SELECT 
  mo.id,
  mo.manufacturing_order_no,
  mo.status,
  mo.sale_order_id,
  so.sale_order_no,
  so.status as sale_order_status
FROM "ManufacturingOrders" mo
LEFT JOIN "SaleOrders" so ON so.id = mo.sale_order_id
WHERE mo.deleted = false
ORDER BY mo.created_at DESC
LIMIT 10;








