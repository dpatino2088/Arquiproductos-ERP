-- ====================================================
-- DIAGNÓSTICO: Problemas de Pricing en BOM
-- ====================================================
-- Este script ayuda a diagnosticar por qué los precios están en $0.00
-- Ejecutar después de crear una Quote Line para verificar el estado
-- ====================================================

-- 1. VERIFICAR ProductTypes y sus códigos
-- ====================================================
SELECT 
  id,
  code,
  name,
  organization_id,
  deleted
FROM public."ProductTypes" 
WHERE deleted = false
ORDER BY code;

-- Verificar específicamente roller-shade
SELECT 
  id,
  code,
  name,
  organization_id
FROM public."ProductTypes" 
WHERE deleted = false
  AND (
    code ILIKE '%roller%' 
    OR code ILIKE '%shade%'
  )
ORDER BY code;

-- ====================================================
-- 2. VERIFICAR BOMInstance más reciente
-- ====================================================
SELECT 
  bi.id as bom_instance_id,
  bi.quote_line_id,
  bi.bom_template_id,
  bt.code as template_code,
  bt.name as template_name,
  COUNT(bil.id) as lines_count,
  COUNT(CASE WHEN bil.resolved_part_id IS NOT NULL THEN 1 END) as lines_with_part,
  bi.created_at
FROM public."BOMInstances" bi
JOIN public."BOMTemplates" bt ON bt.id = bi.bom_template_id
LEFT JOIN public."BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE bi.deleted = false
GROUP BY bi.id, bi.quote_line_id, bi.bom_template_id, bt.code, bt.name, bi.created_at
ORDER BY bi.created_at DESC
LIMIT 5;

-- ====================================================
-- 3. VERIFICAR BOMInstanceLines con precios
-- ====================================================
-- Reemplazar 'BOM_INSTANCE_ID' con el ID del BOMInstance más reciente
WITH latest_bom AS (
  SELECT id 
  FROM public."BOMInstances" 
  WHERE deleted = false 
  ORDER BY created_at DESC 
  LIMIT 1
)
SELECT 
  bil.id,
  bil.bom_instance_id,
  bil.resolved_part_id,
  bil.qty,
  ci.sku,
  ci.name as item_name,
  ci.msrp as catalog_item_msrp,
  msrp.msrp_sale_out,
  ci.cost_exw,
  CASE 
    WHEN msrp.msrp_sale_out IS NOT NULL THEN msrp.msrp_sale_out * bil.qty
    WHEN ci.msrp IS NOT NULL THEN ci.msrp * bil.qty
    ELSE 0
  END as calculated_total_msrp
FROM public."BOMInstanceLines" bil
LEFT JOIN public."CatalogItems" ci ON ci.id = bil.resolved_part_id
LEFT JOIN public."CatalogItemsMSRP" msrp ON msrp.catalog_item_id = bil.resolved_part_id
WHERE bil.bom_instance_id = (SELECT id FROM latest_bom)
ORDER BY bil.id;

-- ====================================================
-- 4. VERIFICAR QuoteLines con precios
-- ====================================================
-- Reemplazar 'YOUR_ORG_ID' con el organization_id real
SELECT 
  ql.id as quote_line_id,
  ql.quote_id,
  ql.msrp,
  ql.list_unit_price_snapshot,
  ql.cost_exw,
  ql.total_cost,
  ql.qty,
  bi.id as bom_instance_id,
  CASE 
    WHEN ql.list_unit_price_snapshot IS NULL OR ql.list_unit_price_snapshot = 0 THEN '❌ NO PRICE'
    ELSE '✅ HAS PRICE'
  END as price_status
FROM public."QuoteLines" ql
LEFT JOIN public."BOMInstances" bi ON bi.quote_line_id = ql.id AND bi.deleted = false
WHERE ql.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'  -- Cambiar por tu org_id
ORDER BY ql.created_at DESC
LIMIT 10;

-- ====================================================
-- 5. VERIFICAR QuoteLineComponents (selecciones del usuario)
-- ====================================================
-- Reemplazar 'QUOTE_LINE_ID' con el ID de la línea más reciente
WITH latest_quote_line AS (
  SELECT id 
  FROM public."QuoteLines" 
  WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'  -- Cambiar por tu org_id
  ORDER BY created_at DESC 
  LIMIT 1
)
SELECT 
  qlc.id,
  qlc.component_role,
  qlc.kind,
  qlc.catalog_item_id,
  ci.sku,
  ci.name as item_name,
  qlc.payload
FROM public."QuoteLineComponents" qlc
LEFT JOIN public."CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.quote_line_id = (SELECT id FROM latest_quote_line)
  -- Note: QuoteLineComponents may not have 'deleted' column
ORDER BY qlc.component_role;

-- ====================================================
-- 6. VERIFICAR CatalogItemsMSRP tiene datos
-- ====================================================
-- Verificar si los items del BOM tienen msrp_sale_out
WITH latest_bom AS (
  SELECT id 
  FROM public."BOMInstances" 
  WHERE deleted = false 
  ORDER BY created_at DESC 
  LIMIT 1
),
bom_items AS (
  SELECT DISTINCT resolved_part_id
  FROM public."BOMInstanceLines"
  WHERE bom_instance_id = (SELECT id FROM latest_bom)
    AND resolved_part_id IS NOT NULL
)
SELECT 
  ci.id,
  ci.sku,
  ci.name,
  ci.msrp as catalog_item_msrp,
  msrp.msrp_sale_out,
  CASE 
    WHEN msrp.msrp_sale_out IS NOT NULL THEN '✅ Has MSRP'
    WHEN ci.msrp IS NOT NULL THEN '⚠️ Only catalog msrp'
    ELSE '❌ NO MSRP'
  END as msrp_status
FROM bom_items bi
JOIN public."CatalogItems" ci ON ci.id = bi.resolved_part_id
LEFT JOIN public."CatalogItemsMSRP" msrp ON msrp.catalog_item_id = ci.id
ORDER BY ci.sku;

-- ====================================================
-- 7. RESUMEN: Estado completo de la última Quote Line
-- ====================================================
WITH latest_quote_line AS (
  SELECT id, quote_id, organization_id
  FROM public."QuoteLines" 
  WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'  -- Cambiar por tu org_id
  ORDER BY created_at DESC 
  LIMIT 1
),
bom_info AS (
  SELECT 
    bi.id as bom_instance_id,
    bt.code as template_code,
    COUNT(bil.id) as total_lines,
    COUNT(CASE WHEN bil.resolved_part_id IS NOT NULL THEN 1 END) as lines_with_part
  FROM public."BOMInstances" bi
  JOIN public."BOMTemplates" bt ON bt.id = bi.bom_template_id
  LEFT JOIN public."BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
  WHERE bi.quote_line_id = (SELECT id FROM latest_quote_line)
    AND bi.deleted = false
  GROUP BY bi.id, bt.code
)
SELECT 
  'Quote Line' as entity,
  ql.id::text as id,
  ql.msrp::text as msrp,
  ql.list_unit_price_snapshot::text as unit_price,
  ql.qty::text as qty,
  CASE 
    WHEN ql.list_unit_price_snapshot IS NULL OR ql.list_unit_price_snapshot = 0 THEN '❌'
    ELSE '✅'
  END as has_price
FROM latest_quote_line lql
JOIN public."QuoteLines" ql ON ql.id = lql.id

UNION ALL

SELECT 
  'BOM Instance' as entity,
  bi.bom_instance_id::text,
  NULL::text,
  NULL::text,
  bi.total_lines::text,
  CASE 
    WHEN bi.lines_with_part = 0 THEN '❌'
    WHEN bi.lines_with_part < bi.total_lines THEN '⚠️'
    ELSE '✅'
  END as has_price
FROM latest_quote_line lql
LEFT JOIN bom_info bi ON true

UNION ALL

SELECT 
  'User Selections' as entity,
  COUNT(qlc.id)::text,
  NULL::text,
  NULL::text,
  NULL::text,
  CASE 
    WHEN COUNT(qlc.id) = 0 THEN '❌'
    ELSE '✅'
  END as has_price
FROM latest_quote_line lql
LEFT JOIN public."QuoteLineComponents" qlc ON qlc.quote_line_id = lql.id
  -- Note: QuoteLineComponents may not have 'deleted' column
;
