-- DEBUG: Check why SO-000001 has no BOM materials
-- Run these queries to diagnose the issue

-- 1) Check the Sale Order details
SELECT 
  id,
  sale_order_no,
  quote_id,
  status,
  created_at
FROM "SaleOrders"
WHERE sale_order_no = 'SO-000001'
  AND deleted = false;

-- 2) Check if the Quote was approved (this should have triggered BOM creation)
SELECT 
  q.id,
  q.quote_no,
  q.status,
  q.approved_at,
  q.created_at
FROM "Quotes" q
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
WHERE so.sale_order_no = 'SO-000001'
  AND q.deleted = false;

-- 3) Check SaleOrderLines for SO-000001
SELECT 
  id,
  line_number,
  catalog_item_id,
  qty,
  description,
  quote_line_id
FROM "SaleOrderLines"
WHERE sale_order_id = (
  SELECT id FROM "SaleOrders" WHERE sale_order_no = 'SO-000001' AND deleted = false LIMIT 1
)
AND deleted = false
ORDER BY line_number;

-- 4) Check if BomInstances exist for these SaleOrderLines
SELECT 
  bi.id as bom_instance_id,
  bi.sale_order_line_id,
  sol.line_number,
  sol.description as line_description,
  COUNT(bil.id) as bom_lines_count
FROM "BomInstances" bi
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE sol.sale_order_id = (
  SELECT id FROM "SaleOrders" WHERE sale_order_no = 'SO-000001' AND deleted = false LIMIT 1
)
AND bi.deleted = false
GROUP BY bi.id, bi.sale_order_line_id, sol.line_number, sol.description;

-- 5) Check BomInstanceLines if BomInstances exist
SELECT 
  bil.id,
  bil.bom_instance_id,
  bil.category_code,
  bil.resolved_part_id,
  bil.qty,
  bil.uom,
  bil.description,
  ci.sku,
  ci.item_name
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE sol.sale_order_id = (
  SELECT id FROM "SaleOrders" WHERE sale_order_no = 'SO-000001' AND deleted = false LIMIT 1
)
AND bil.deleted = false
AND bi.deleted = false
ORDER BY bil.category_code, ci.sku;

-- 6) Test SaleOrderMaterialList view for this Sale Order
SELECT 
  sale_order_id,
  category_code,
  sku,
  item_name,
  uom,
  total_qty,
  total_cost_exw
FROM "SaleOrderMaterialList"
WHERE sale_order_id = (
  SELECT id FROM "SaleOrders" WHERE sale_order_no = 'SO-000001' AND deleted = false LIMIT 1
)
ORDER BY category_code, sku;








