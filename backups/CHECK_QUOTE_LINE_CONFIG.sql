-- Verificar QuoteLineComponents guardados para una línea
-- Reemplaza el quote_line_id con el de la línea que creaste

SELECT 
  qlc.component_role,
  qlc.kind,
  qlc.catalog_item_id,
  qlc.payload,
  qlc.deleted,
  ci.sku,
  ci.name
FROM public."QuoteLineComponents" qlc
LEFT JOIN public."CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.quote_line_id = '3fc6811f-e553-42f9-835b-1c3105f09b4b' -- ⚠️ REEMPLAZAR con el ID de la línea
  AND qlc.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
ORDER BY qlc.created_at;

-- También verifica si hay BOMInstance
SELECT 
  bi.id as instance_id,
  bi.bom_template_id,
  bt.code as template_code,
  bt.name as template_name,
  COUNT(bil.id) as lines_count
FROM public."BOMInstances" bi
LEFT JOIN public."BOMTemplates" bt ON bt.id = bi.bom_template_id
LEFT JOIN public."BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE bi.quote_line_id = '3fc6811f-e553-42f9-835b-1c3105f09b4b' -- ⚠️ REEMPLAZAR
  AND bi.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'
  AND bi.deleted = false
GROUP BY bi.id, bi.bom_template_id, bt.code, bt.name;
