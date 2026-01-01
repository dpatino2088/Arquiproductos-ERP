-- ====================================================
-- COMPLETE DATABASE AUDIT - Manufacturing BOM Flow
-- ====================================================
-- Revisión integral del flujo completo de datos
-- Ejecutar todas las queries y compartir resultados

-- ====================================================
-- PARTE 1: VERIFICAR EL FLUJO COMPLETO PARA SO-000002
-- ====================================================

-- 1.1) Verificar Sale Order
SELECT 
  'SaleOrder' as table_name,
  id,
  sale_order_no,
  quote_id,
  status,
  created_at,
  deleted
FROM "SaleOrders"
WHERE sale_order_no = 'SO-000002';

-- 1.2) Verificar Quote relacionado
SELECT 
  'Quote' as table_name,
  q.id,
  q.quote_no,
  q.status,
  q.updated_at as last_updated,
  q.created_at,
  q.deleted
FROM "Quotes" q
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
WHERE so.sale_order_no = 'SO-000002';

-- 1.3) Verificar QuoteLines
SELECT 
  'QuoteLines' as table_name,
  ql.id,
  ql.quote_id,
  ql.catalog_item_id,
  ql.product_type_id,
  ql.qty,
  ql.width_m,
  ql.height_m,
  ql.deleted,
  ql.created_at,
  ci.item_name as catalog_item_name,
  COUNT(qlc.id) as components_count
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE so.sale_order_no = 'SO-000002'
  AND ql.deleted = false
GROUP BY ql.id, ql.quote_id, ql.catalog_item_id, ql.product_type_id, ql.qty, ql.width_m, ql.height_m, ql.deleted, ql.created_at, ci.item_name
ORDER BY ql.created_at;

-- 1.4) Verificar QuoteLineComponents (CRÍTICO - estos son la fuente de BomInstanceLines)
SELECT 
  'QuoteLineComponents' as table_name,
  qlc.id,
  qlc.quote_line_id,
  qlc.catalog_item_id,
  qlc.component_role,
  qlc.source,
  qlc.qty,
  qlc.uom,
  qlc.deleted,
  ci.sku,
  ci.item_name
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000002'
  AND qlc.deleted = false
ORDER BY ql.created_at, qlc.id;

-- 1.5) Verificar SaleOrderLines
SELECT 
  'SaleOrderLines' as table_name,
  sol.id,
  sol.sale_order_id,
  sol.quote_line_id,
  sol.line_number,
  sol.catalog_item_id,
  sol.description,
  sol.deleted,
  sol.created_at
FROM "SaleOrderLines" sol
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000002'
  AND sol.deleted = false
ORDER BY sol.line_number, sol.created_at;

-- 1.6) Verificar BomInstances
SELECT 
  'BomInstances' as table_name,
  bi.id,
  bi.sale_order_line_id,
  bi.quote_line_id,
  bi.status,
  bi.created_at,
  bi.deleted,
  COUNT(bil.id) as bom_lines_count,
  COUNT(CASE WHEN bil.deleted = false THEN 1 END) as active_bom_lines_count
FROM "BomInstances" bi
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE so.sale_order_no = 'SO-000002'
  AND bi.deleted = false
GROUP BY bi.id, bi.sale_order_line_id, bi.quote_line_id, bi.status, bi.created_at, bi.deleted;

-- 1.7) Verificar BomInstanceLines (DEBE estar vacío según el problema)
SELECT 
  'BomInstanceLines' as table_name,
  bil.id,
  bil.bom_instance_id,
  bil.category_code,
  bil.resolved_part_id,
  bil.qty,
  bil.uom,
  bil.description,
  bil.deleted,
  ci.sku,
  ci.item_name
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000002'
ORDER BY bil.id;

-- ====================================================
-- PARTE 2: VERIFICAR EL TRIGGER Y FUNCIONES
-- ====================================================

-- 2.1) Verificar si el trigger existe y está activo
SELECT 
  'Trigger Info' as info_type,
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement,
  action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE '%quote_approved%'
ORDER BY trigger_name;

-- 2.2) Verificar si la función existe
SELECT 
  'Function Info' as info_type,
  routine_name,
  routine_type,
  data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name = 'on_quote_approved_create_operational_docs';

-- 2.3) Verificar funciones auxiliares necesarias
SELECT 
  'Helper Functions' as info_type,
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'normalize_uom_to_canonical',
    'get_unit_cost_in_uom',
    'derive_category_code_from_role'
  )
ORDER BY routine_name;

-- ====================================================
-- PARTE 3: VERIFICAR LA VISTA SaleOrderMaterialList
-- ====================================================

-- 3.1) Verificar si la vista existe
SELECT 
  'View Info' as info_type,
  table_name,
  view_definition
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name = 'SaleOrderMaterialList';

-- 3.2) Probar la vista directamente
SELECT 
  'SaleOrderMaterialList' as source,
  COUNT(*) as row_count
FROM "SaleOrderMaterialList"
WHERE sale_order_id = (
  SELECT id FROM "SaleOrders" WHERE sale_order_no = 'SO-000002' AND deleted = false LIMIT 1
);

-- ====================================================
-- PARTE 4: DIAGNÓSTICO DEL PROBLEMA
-- ====================================================

-- 4.1) Verificar si QuoteLineComponents tienen source = 'configured_component'
-- (El trigger solo crea BomInstanceLines desde componentes con source = 'configured_component')
SELECT 
  'QuoteLineComponents Source Check' as check_type,
  qlc.source,
  COUNT(*) as count,
  CASE 
    WHEN qlc.source = 'configured_component' THEN '✅ Correct source'
    ELSE '❌ Wrong source - trigger will skip these'
  END as status
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
WHERE so.sale_order_no = 'SO-000002'
  AND qlc.deleted = false
GROUP BY qlc.source;

-- 4.2) Verificar si los CatalogItems existen y no están deleted
SELECT 
  'CatalogItems Check' as check_type,
  COUNT(*) as total_components,
  COUNT(CASE WHEN ci.deleted = false THEN 1 END) as active_catalog_items,
  COUNT(CASE WHEN ci.deleted = true THEN 1 END) as deleted_catalog_items,
  COUNT(CASE WHEN ci.id IS NULL THEN 1 END) as missing_catalog_items
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000002'
  AND qlc.deleted = false
  AND qlc.source = 'configured_component';

-- ====================================================
-- PARTE 5: RESUMEN EJECUTIVO
-- ====================================================

-- 5.1) Resumen del flujo completo
SELECT 
  'FLOW SUMMARY' as summary_type,
  (SELECT COUNT(*) FROM "SaleOrders" WHERE sale_order_no = 'SO-000002' AND deleted = false) as sale_orders,
  (SELECT COUNT(*) FROM "Quotes" q INNER JOIN "SaleOrders" so ON so.quote_id = q.id WHERE so.sale_order_no = 'SO-000002' AND q.deleted = false) as quotes,
  (SELECT COUNT(*) FROM "QuoteLines" ql INNER JOIN "Quotes" q ON q.id = ql.quote_id INNER JOIN "SaleOrders" so ON so.quote_id = q.id WHERE so.sale_order_no = 'SO-000002' AND ql.deleted = false) as quote_lines,
  (SELECT COUNT(*) FROM "QuoteLineComponents" qlc INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id INNER JOIN "Quotes" q ON q.id = ql.quote_id INNER JOIN "SaleOrders" so ON so.quote_id = q.id WHERE so.sale_order_no = 'SO-000002' AND qlc.deleted = false) as quote_line_components,
  (SELECT COUNT(*) FROM "QuoteLineComponents" qlc INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id INNER JOIN "Quotes" q ON q.id = ql.quote_id INNER JOIN "SaleOrders" so ON so.quote_id = q.id WHERE so.sale_order_no = 'SO-000002' AND qlc.deleted = false AND qlc.source = 'configured_component') as configured_components,
  (SELECT COUNT(*) FROM "SaleOrderLines" sol INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id WHERE so.sale_order_no = 'SO-000002' AND sol.deleted = false) as sale_order_lines,
  (SELECT COUNT(*) FROM "BomInstances" bi INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id WHERE so.sale_order_no = 'SO-000002' AND bi.deleted = false) as bom_instances,
  (SELECT COUNT(*) FROM "BomInstanceLines" bil INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id WHERE so.sale_order_no = 'SO-000002' AND bil.deleted = false) as bom_instance_lines;

