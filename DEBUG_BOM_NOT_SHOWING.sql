-- DEBUG: Check why BOM materials (Fabric, etc.) are not showing in Manufacturing Order
-- Run these queries to diagnose the issue

-- 1) Check if BomInstances exist for SO-000001
SELECT 
  bi.id as bom_instance_id,
  bi.sale_order_line_id,
  sol.line_number,
  sol.description as line_description,
  bi.status as bom_status,
  bi.created_at
FROM "BomInstances" bi
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000001'
  AND bi.deleted = false
  AND sol.deleted = false
ORDER BY sol.line_number;

-- 2) Check BomInstanceLines (the actual materials like Fabric, etc.)
SELECT 
  bil.id,
  bil.bom_instance_id,
  bil.category_code,  -- This should be 'fabric', 'tube', etc.
  bil.resolved_part_id,
  bil.qty,
  bil.uom,
  bil.description,
  bil.unit_cost_exw,
  bil.total_cost_exw,
  ci.sku,
  ci.item_name,
  ci.id as catalog_item_id
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000001'
  AND bil.deleted = false
  AND bi.deleted = false
ORDER BY bil.category_code, ci.sku;

-- 3) Check if category_code is NULL or empty (this could be the problem)
SELECT 
  category_code,
  COUNT(*) as count,
  CASE 
    WHEN category_code IS NULL THEN 'NULL category_code'
    WHEN category_code = '' THEN 'Empty category_code'
    ELSE 'Has category_code'
  END as status
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000001'
  AND bil.deleted = false
  AND bi.deleted = false
GROUP BY category_code;

-- 4) Test SaleOrderMaterialList view directly
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
WHERE sale_order_id = (
  SELECT id FROM "SaleOrders" WHERE sale_order_no = 'SO-000001' AND deleted = false LIMIT 1
)
ORDER BY category_code, sku;

-- 5) Check if resolved_part_id is NULL (materials without catalog items)
SELECT 
  COUNT(*) as materials_without_catalog_item,
  COUNT(CASE WHEN resolved_part_id IS NULL THEN 1 END) as null_resolved_part_id
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000001'
  AND bil.deleted = false
  AND bi.deleted = false;

-- 6) Check all BomInstanceLines with their full details
SELECT 
  bil.id,
  bil.bom_instance_id,
  bil.category_code,
  bil.resolved_part_id,
  bil.qty,
  bil.uom,
  bil.description,
  bil.unit_cost_exw,
  bil.total_cost_exw,
  bil.deleted as bil_deleted,
  bi.deleted as bi_deleted,
  sol.deleted as sol_deleted,
  so.deleted as so_deleted,
  ci.id as catalog_item_exists,
  ci.sku,
  ci.item_name
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000001'
ORDER BY bil.category_code, bil.id;








