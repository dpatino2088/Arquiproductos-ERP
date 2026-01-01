-- QUICK CHECK: Verify if BomInstanceLines exist for SO-000002
-- Run this query to see if there are actual material lines

-- Check BomInstanceLines for the BomInstances we found
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
  bil.deleted as bil_deleted,  -- Check if lines are deleted
  ci.sku,
  ci.item_name,
  ci.id as catalog_item_id
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000002'
  AND bil.deleted = false  -- Only non-deleted lines
  AND bi.deleted = false
ORDER BY bil.category_code, ci.sku;

-- If this returns 0 rows, the problem is that BomInstanceLines don't exist or are all deleted
-- If this returns rows, check the category_code column - if it's NULL, that's the problem








