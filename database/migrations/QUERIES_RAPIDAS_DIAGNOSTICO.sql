-- ====================================================
-- QUERIES RÁPIDAS PARA DIAGNÓSTICO (Sin placeholders)
-- ====================================================
-- ⚠️ IMPORTANTE: Primero ejecuta CHECK_COLUMNS_EXIST.sql o migración 220
--    para asegurar que las columnas cut_length_mm existen
-- ====================================================
-- Ejecuta estas 3 queries y pega los resultados
-- ====================================================

-- ====================================================
-- 1. INPUTS DEL BOM (Fase 2.1) - Primer BomInstance con template
-- ====================================================
SELECT 
  bi.id AS bom_instance_id,
  sol.id AS sale_order_line_id,
  sol.width_m,
  sol.height_m,
  sol.qty,
  sol.product_type,
  sol.drive_type,
  ql.width_m AS ql_width_m,
  ql.height_m AS ql_height_m
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
WHERE bi.deleted = false
AND bi.bom_template_id IS NOT NULL
ORDER BY bi.created_at DESC
LIMIT 1;

-- ====================================================
-- 2. REGLAS DEL TEMPLATE (Fase 3.1) - Para el mismo BomInstance
-- ====================================================
SELECT
  bc.id,
  bc.sequence_order,
  bc.component_role,
  bc.affects_role,
  bc.cut_axis,
  bc.cut_delta_mm,
  bc.cut_delta_scope,
  ci.sku AS component_sku
FROM "BOMComponents" bc
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE bc.bom_template_id = (
  SELECT bi.bom_template_id 
  FROM "BomInstances" bi
  WHERE bi.deleted = false
  AND bi.bom_template_id IS NOT NULL
  ORDER BY bi.created_at DESC
  LIMIT 1
)
AND bc.deleted = false
AND bc.cut_axis IS NOT NULL
AND bc.cut_axis <> 'none'
ORDER BY bc.sequence_order;

-- ====================================================
-- 3. 10 LÍNEAS DEL BOM (Fase 1.1) - Para el mismo BomInstance
-- ====================================================
SELECT
  bil.id,
  bil.resolved_sku,
  bil.part_role,
  bil.qty,
  bil.uom,
  bil.cut_length_mm,
  bil.cut_width_mm,
  bil.cut_height_mm,
  bil.calc_notes
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id = (
  SELECT bi.id 
  FROM "BomInstances" bi
  WHERE bi.deleted = false
  AND bi.bom_template_id IS NOT NULL
  ORDER BY bi.created_at DESC
  LIMIT 1
)
AND bil.deleted = false
ORDER BY bil.part_role, bil.resolved_sku
LIMIT 10;

