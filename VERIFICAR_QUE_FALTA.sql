-- ====================================================
-- VERIFICAR QUÉ FALTA: Diagnóstico rápido
-- ====================================================

-- 1. Verificar si los QuoteLines tienen product_type_id
SELECT 
  '1. QuoteLines con product_type_id' as check_name,
  ql.id as quote_line_id,
  ql.product_type_id,
  pt.name as product_type_name
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false;

-- 2. Verificar si existen BOMTemplates para esos product_type_id
SELECT 
  '2. BOMTemplates disponibles' as check_name,
  ql.id as quote_line_id,
  ql.product_type_id,
  pt.name as product_type_name,
  q.organization_id,
  bt.id as bom_template_id,
  bt.name as bom_template_name,
  bt.active,
  bt.deleted,
  COUNT(bc.id) as bom_components_count
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

-- 3. Verificar QuoteLineComponents existentes
SELECT 
  '3. QuoteLineComponents existentes' as check_name,
  ql.id as quote_line_id,
  COUNT(qlc.id) as total_components,
  COUNT(CASE WHEN qlc.source = 'configured_component' THEN 1 END) as configured_components
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
GROUP BY ql.id;








