-- ====================================================
-- DIAGNÓSTICO COMPLETO: Por qué no hay QuoteLineComponents
-- ====================================================
-- Ejecuta este script completo y comparte TODOS los resultados

-- ====================================================
-- PARTE 1: Verificar QuoteLines y sus product_type_id
-- ====================================================

SELECT 
  'PARTE 1: QuoteLines' as diagnostic_section,
  ql.id as quote_line_id,
  ql.product_type_id,
  ql.catalog_item_id,
  ql.qty,
  ql.width_m,
  ql.height_m,
  pt.name as product_type_name,
  ci.item_name as catalog_item_name,
  ci.sku as catalog_item_sku
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
ORDER BY ql.created_at;

-- ====================================================
-- PARTE 2: Verificar si existen BOMTemplates para esos product_type_id
-- ====================================================

SELECT 
  'PARTE 2: BOMTemplates Check' as diagnostic_section,
  ql.id as quote_line_id,
  ql.product_type_id,
  pt.name as product_type_name,
  q.organization_id,
  bt.id as bom_template_id,
  bt.name as bom_template_name,
  bt.active as template_active,
  bt.deleted as template_deleted,
  CASE 
    WHEN ql.product_type_id IS NULL THEN '❌ QuoteLine NO tiene product_type_id'
    WHEN pt.id IS NULL THEN '❌ ProductType NO existe'
    WHEN bt.id IS NULL THEN '❌ NO existe BOMTemplate para este product_type_id'
    WHEN bt.deleted = true THEN '❌ BOMTemplate está deleted'
    WHEN bt.active = false THEN '❌ BOMTemplate está inactive'
    ELSE '✅ BOMTemplate OK'
  END as template_status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
  AND bt.organization_id = q.organization_id
  AND bt.deleted = false
  AND bt.active = true
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
ORDER BY ql.created_at;

-- ====================================================
-- PARTE 3: Verificar BOMComponents en los BOMTemplates
-- ====================================================

SELECT 
  'PARTE 3: BOMComponents Check' as diagnostic_section,
  ql.id as quote_line_id,
  bt.id as bom_template_id,
  bt.name as bom_template_name,
  COUNT(bc.id) as total_bom_components,
  COUNT(CASE WHEN bc.deleted = false THEN 1 END) as active_bom_components_count,
  CASE 
    WHEN bt.id IS NULL THEN '❌ No BOMTemplate'
    WHEN COUNT(bc.id) = 0 THEN '❌ BOMTemplate sin BOMComponents'
    WHEN COUNT(CASE WHEN bc.deleted = false THEN 1 END) = 0 THEN '❌ Todos los BOMComponents están deleted'
    ELSE '✅ BOMComponents OK'
  END as components_status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
  AND bt.organization_id = q.organization_id
  AND bt.deleted = false
  AND bt.active = true
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
GROUP BY ql.id, bt.id, bt.name
ORDER BY ql.created_at;

-- ====================================================
-- PARTE 4: Verificar QuoteLineComponents existentes (cualquier source)
-- ====================================================

SELECT 
  'PARTE 4: QuoteLineComponents Existentes' as diagnostic_section,
  ql.id as quote_line_id,
  qlc.id as qlc_id,
  qlc.source,
  qlc.component_role,
  qlc.catalog_item_id,
  qlc.qty,
  qlc.uom,
  ci.sku,
  ci.item_name
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
ORDER BY ql.created_at, qlc.id;

-- ====================================================
-- PARTE 5: Resumen Ejecutivo
-- ====================================================

SELECT 
  'RESUMEN EJECUTIVO' as summary_type,
  (SELECT COUNT(*) FROM "QuoteLines" ql 
   INNER JOIN "Quotes" q ON q.id = ql.quote_id
   INNER JOIN "SaleOrders" so ON so.quote_id = q.id
   WHERE so.sale_order_no = 'SO-000002' AND ql.deleted = false) as total_quote_lines,
  (SELECT COUNT(*) FROM "QuoteLines" ql 
   INNER JOIN "Quotes" q ON q.id = ql.quote_id
   INNER JOIN "SaleOrders" so ON so.quote_id = q.id
   WHERE so.sale_order_no = 'SO-000002' 
     AND ql.deleted = false
     AND ql.product_type_id IS NOT NULL) as quote_lines_with_product_type,
  (SELECT COUNT(*) FROM "QuoteLines" ql 
   INNER JOIN "Quotes" q ON q.id = ql.quote_id
   INNER JOIN "SaleOrders" so ON so.quote_id = q.id
   LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
     AND bt.organization_id = q.organization_id
     AND bt.deleted = false
     AND bt.active = true
   WHERE so.sale_order_no = 'SO-000002' 
     AND ql.deleted = false
     AND bt.id IS NOT NULL) as quote_lines_with_bom_template,
  (SELECT COUNT(*) FROM "QuoteLineComponents" qlc
   INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
   INNER JOIN "Quotes" q ON q.id = ql.quote_id
   INNER JOIN "SaleOrders" so ON so.quote_id = q.id
   WHERE so.sale_order_no = 'SO-000002'
     AND qlc.deleted = false
     AND qlc.source = 'configured_component') as configured_components_created,
  (SELECT COUNT(*) FROM "QuoteLineComponents" qlc
   INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
   INNER JOIN "Quotes" q ON q.id = ql.quote_id
   INNER JOIN "SaleOrders" so ON so.quote_id = q.id
   WHERE so.sale_order_no = 'SO-000002'
     AND qlc.deleted = false) as total_quote_line_components;








