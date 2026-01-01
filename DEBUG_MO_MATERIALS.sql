-- DEBUG: Check why Manufacturing Order shows 0 materials
-- Replace '4ed00317-3473-4f16-9710-003911f49523' with your actual MO ID

-- 1) Get the Manufacturing Order details
SELECT 
  mo.id as mo_id,
  mo.manufacturing_order_no,
  mo.sale_order_id,
  so.sale_order_no,
  so.status as sale_order_status
FROM "ManufacturingOrders" mo
LEFT JOIN "SaleOrders" so ON so.id = mo.sale_order_id
WHERE mo.id = '4ed00317-3473-4f16-9710-003911f49523';

-- 2) Check if SaleOrderMaterialList has data for this sale_order_id
-- Replace with the sale_order_id from query 1
SELECT 
  COUNT(*) as material_count,
  sale_order_id
FROM "SaleOrderMaterialList"
WHERE sale_order_id = 'YOUR_SALE_ORDER_ID_HERE'  -- Replace with sale_order_id from query 1
GROUP BY sale_order_id;

-- 3) Check if there are BomInstances for this Sale Order
-- Replace with the sale_order_id from query 1
SELECT 
  COUNT(DISTINCT bi.id) as bom_instances_count,
  COUNT(DISTINCT bil.id) as bom_lines_count
FROM "SaleOrders" so
INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.id = 'YOUR_SALE_ORDER_ID_HERE'  -- Replace with sale_order_id from query 1
  AND so.deleted = false;

-- 4) Check SaleOrderLines for this Sale Order
-- Replace with the sale_order_id from query 1
SELECT 
  id,
  line_number,
  catalog_item_id,
  qty,
  description
FROM "SaleOrderLines"
WHERE sale_order_id = 'YOUR_SALE_ORDER_ID_HERE'  -- Replace with sale_order_id from query 1
  AND deleted = false
ORDER BY line_number;

-- 5) Check BomInstances linked to these SaleOrderLines
-- Replace with the sale_order_id from query 1
SELECT 
  bi.id as bom_instance_id,
  bi.sale_order_line_id,
  sol.line_number,
  COUNT(bil.id) as bom_lines_count
FROM "BomInstances" bi
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE sol.sale_order_id = 'YOUR_SALE_ORDER_ID_HERE'  -- Replace with sale_order_id from query 1
  AND bi.deleted = false
GROUP BY bi.id, bi.sale_order_line_id, sol.line_number;








