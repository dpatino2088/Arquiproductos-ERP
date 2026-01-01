-- ====================================================
-- Get bom_instance_id for SO-053830
-- ====================================================
-- Run this first to get the actual bom_instance_id to use in other queries
-- ====================================================

SELECT
  so.sale_order_no,
  sol.id AS sale_order_line_id,
  bi.id AS bom_instance_id,
  bi.status,
  bi.bom_template_id,
  bt.name AS template_name
FROM "SalesOrders" so
JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted=false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted=false
LEFT JOIN "BOMTemplates" bt ON bt.id = bi.bom_template_id
WHERE so.sale_order_no = 'SO-053830'
ORDER BY sol.line_number NULLS LAST
LIMIT 5;

-- ⚠️ COPY one of the bom_instance_id values from the results above
-- Then use it in the other diagnostic queries by replacing '<BOM_INSTANCE_ID>'



