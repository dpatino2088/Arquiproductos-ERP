-- Verificar BOMTemplates para los QuoteLines de SO-000002

SELECT 
  ql.id as quote_line_id,
  ql.product_type_id,
  pt.name as product_type_name,
  q.organization_id,
  bt.id as bom_template_id,
  bt.name as bom_template_name,
  bt.active,
  bt.deleted,
  COUNT(bc.id) as bom_components_count,
  CASE 
    WHEN ql.product_type_id IS NULL THEN '❌ QuoteLine NO tiene product_type_id'
    WHEN bt.id IS NULL THEN '❌ NO hay BOMTemplate para este product_type_id'
    WHEN bt.deleted = true THEN '❌ BOMTemplate está deleted'
    WHEN bt.active = false THEN '❌ BOMTemplate está inactive'
    WHEN COUNT(bc.id) = 0 THEN '❌ BOMTemplate NO tiene componentes'
    ELSE '✅ BOMTemplate OK'
  END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
  AND bt.organization_id = q.organization_id
  AND bt.deleted = false
  AND bt.active = true
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
GROUP BY ql.id, ql.product_type_id, pt.name, q.organization_id, bt.id, bt.name, bt.active, bt.deleted;








