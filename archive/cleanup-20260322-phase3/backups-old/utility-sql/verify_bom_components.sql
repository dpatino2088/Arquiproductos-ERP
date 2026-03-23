-- ============================================================
-- Script de Verificación de BOMComponents
-- Verifica que todos los templates tengan sus componentes
-- ============================================================

-- Verificar conteo de componentes por template
SELECT 
  bt.code AS template_code,
  bt.name AS template_name,
  COUNT(bc.id) AS component_count,
  COUNT(DISTINCT bc.component_role) AS unique_roles
FROM public."BOMTemplates" bt
LEFT JOIN public."BOMComponents" bc ON bt.id = bc.bom_template_id AND bc.deleted = false
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted = false
GROUP BY bt.id, bt.code, bt.name
ORDER BY bt.code;

-- Verificar componentes por role y template
SELECT 
  bt.code AS template_code,
  bc.component_role,
  COUNT(*) AS qty_components,
  COUNT(CASE WHEN bc.component_item_id IS NULL THEN 1 END) AS null_item_ids,
  COUNT(CASE WHEN bc.component_item_id IS NOT NULL THEN 1 END) AS resolved_items
FROM public."BOMTemplates" bt
INNER JOIN public."BOMComponents" bc ON bt.id = bc.bom_template_id
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted = false
  AND bc.deleted = false
GROUP BY bt.code, bc.component_role
ORDER BY bt.code, bc.component_role;

-- Verificar componentes sin catalog_item_id resuelto (deben ser user-selectable como motor, tube, track)
SELECT 
  bt.code AS template_code,
  bc.component_role,
  bc.component_item_id,
  bc.sku_resolution_rule,
  bc.auto_select
FROM public."BOMTemplates" bt
INNER JOIN public."BOMComponents" bc ON bt.id = bc.bom_template_id
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted = false
  AND bc.deleted = false
  AND bc.component_item_id IS NULL
ORDER BY bt.code, bc.component_role;

-- Verificar componentes con SKUs específicos (ejemplos clave)
SELECT 
  bt.code AS template_code,
  bc.component_role,
  ci.sku,
  bc.qty_value,
  bc.uom
FROM public."BOMTemplates" bt
INNER JOIN public."BOMComponents" bc ON bt.id = bc.bom_template_id
LEFT JOIN public."CatalogItems" ci ON bc.component_item_id = ci.id
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted = false
  AND bc.deleted = false
  AND ci.sku IN ('RC2013-M', 'RC2011', 'RCA-04-W', 'PU12-0400-MW', 'CC1017-W')
ORDER BY bt.code, ci.sku;

-- Resumen por product_type
SELECT 
  pt.code AS product_type,
  COUNT(DISTINCT bt.id) AS template_count,
  COUNT(bc.id) AS total_components,
  COUNT(DISTINCT bc.component_role) AS unique_roles
FROM public."ProductTypes" pt
LEFT JOIN public."BOMTemplates" bt ON pt.id = bt.product_type_id AND bt.deleted = false
LEFT JOIN public."BOMComponents" bc ON bt.id = bc.bom_template_id AND bc.deleted = false
WHERE pt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
GROUP BY pt.id, pt.code
ORDER BY pt.code;

-- Verificar templates sin componentes (deberían ser 0)
SELECT 
  bt.code,
  bt.name,
  COUNT(bc.id) AS component_count
FROM public."BOMTemplates" bt
LEFT JOIN public."BOMComponents" bc ON bt.id = bc.bom_template_id AND bc.deleted = false
WHERE bt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND bt.deleted = false
GROUP BY bt.id, bt.code, bt.name
HAVING COUNT(bc.id) = 0;
