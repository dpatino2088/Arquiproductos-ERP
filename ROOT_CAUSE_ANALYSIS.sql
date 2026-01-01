-- ====================================================
-- ROOT CAUSE ANALYSIS - Por qué no hay BomInstanceLines
-- ====================================================

-- PROBLEMA IDENTIFICADO:
-- El trigger on_quote_approved_create_operational_docs SOLO crea BomInstanceLines
-- desde QuoteLineComponents que tienen source = 'configured_component'
-- (ver línea 816 de migration 177)

-- ====================================================
-- DIAGNÓSTICO 1: Verificar source de QuoteLineComponents
-- ====================================================

SELECT 
  'DIAGNÓSTICO 1: QuoteLineComponents source values' as diagnostic,
  qlc.source,
  COUNT(*) as count,
  CASE 
    WHEN qlc.source = 'configured_component' THEN '✅ CORRECTO - Estos SÍ crean BomInstanceLines'
    WHEN qlc.source IS NULL THEN '❌ NULL - NO crea BomInstanceLines'
    ELSE '❌ INCORRECTO - source = "' || qlc.source || '" NO crea BomInstanceLines'
  END as status,
  STRING_AGG(DISTINCT qlc.component_role, ', ') as component_roles
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
WHERE so.sale_order_no = 'SO-000002'
  AND qlc.deleted = false
GROUP BY qlc.source
ORDER BY count DESC;

-- ====================================================
-- DIAGNÓSTICO 2: Verificar todos los QuoteLineComponents con detalles
-- ====================================================

SELECT 
  'DIAGNÓSTICO 2: Todos los QuoteLineComponents' as diagnostic,
  ql.created_at as quote_line_created,
  qlc.id as qlc_id,
  qlc.source,
  qlc.component_role,
  qlc.catalog_item_id,
  qlc.qty,
  qlc.uom,
  ci.sku,
  ci.item_name,
  ci.deleted as catalog_item_deleted,
  CASE 
    WHEN qlc.source = 'configured_component' AND ci.deleted = false THEN '✅ Se creará BomInstanceLine'
    WHEN qlc.source != 'configured_component' THEN '❌ source incorrecto: ' || qlc.source
    WHEN ci.deleted = true THEN '❌ CatalogItem está deleted'
    WHEN ci.id IS NULL THEN '❌ CatalogItem no existe'
    ELSE '❓ Otro problema'
  END as why_not_created
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000002'
  AND qlc.deleted = false
ORDER BY ql.created_at, qlc.id;

-- ====================================================
-- DIAGNÓSTICO 3: Comparar con un Quote que SÍ tiene BOM
-- ====================================================

-- Si hay otro Sale Order que SÍ tiene BomInstanceLines, comparar
SELECT 
  'DIAGNÓSTICO 3: Comparación con otros Sale Orders' as diagnostic,
  so.sale_order_no,
  COUNT(DISTINCT qlc.id) as total_quote_line_components,
  COUNT(DISTINCT CASE WHEN qlc.source = 'configured_component' THEN qlc.id END) as configured_components,
  COUNT(DISTINCT bil.id) as bom_instance_lines,
  CASE 
    WHEN COUNT(DISTINCT bil.id) > 0 THEN '✅ Tiene BOM'
    WHEN COUNT(DISTINCT CASE WHEN qlc.source = 'configured_component' THEN qlc.id END) = 0 THEN '❌ No tiene configured_components'
    ELSE '❌ Tiene configured_components pero no BOM'
  END as status
FROM "SaleOrders" so
INNER JOIN "Quotes" q ON q.id = so.quote_id
INNER JOIN "QuoteLines" ql ON ql.quote_id = q.id AND ql.deleted = false
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
LEFT JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.deleted = false
  AND so.sale_order_no IN ('SO-000001', 'SO-000002')
GROUP BY so.sale_order_no
ORDER BY so.sale_order_no;

-- ====================================================
-- SOLUCIÓN: Si source no es 'configured_component', necesitamos corregirlo
-- ====================================================

-- Verificar si podemos actualizar el source
SELECT 
  'SOLUCIÓN: Verificar valores únicos de source' as solution_check,
  source,
  COUNT(*) as count
FROM "QuoteLineComponents"
WHERE deleted = false
GROUP BY source
ORDER BY count DESC;

