-- DEBUG: Why are there no BomInstanceLines for SO-000002?
-- Run these queries to find the root cause

-- 1) Check if the Quote had QuoteLineComponents (these are needed to create BomInstanceLines)
SELECT 
  q.id as quote_id,
  q.quote_no,
  q.status as quote_status,
  q.approved_at,
  COUNT(DISTINCT ql.id) as quote_lines_count,
  COUNT(DISTINCT qlc.id) as quote_line_components_count
FROM "Quotes" q
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "QuoteLines" ql ON ql.quote_id = q.id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE so.sale_order_no = 'SO-000002'
  AND q.deleted = false
GROUP BY q.id, q.quote_no, q.status, q.approved_at;

-- 2) Check QuoteLines for the Quote that created SO-000002
SELECT 
  ql.id as quote_line_id,
  ql.line_number,
  ql.catalog_item_id,
  ql.description,
  ql.product_type_id,
  COUNT(qlc.id) as components_count
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
GROUP BY ql.id, ql.line_number, ql.catalog_item_id, ql.description, ql.product_type_id
ORDER BY ql.line_number;

-- 3) Check if the BomInstances were created but are missing lines
SELECT 
  bi.id as bom_instance_id,
  bi.sale_order_line_id,
  bi.quote_line_id,
  bi.status as bom_status,
  bi.created_at,
  COUNT(bil.id) as bom_lines_count,
  COUNT(CASE WHEN bil.deleted = false THEN 1 END) as active_bom_lines_count
FROM "BomInstances" bi
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE so.sale_order_no = 'SO-000002'
  AND bi.deleted = false
GROUP BY bi.id, bi.sale_order_line_id, bi.quote_line_id, bi.status, bi.created_at;

-- 4) Check if there's a way to regenerate BOM - verify the function exists
SELECT 
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%bom%'
ORDER BY routine_name;








