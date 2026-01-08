-- ====================================================
-- Query de Diagnóstico: ¿Qué está llamando el BOM?
-- ====================================================
-- Este query ayuda a entender qué template y componentes se están usando
-- ====================================================

-- Reemplazar con el manufacturing_order_id real
-- Ejemplo: '79d6cc3c-b546-4c6f-97ca-42125f7454d5'::uuid

WITH mo_info AS (
  SELECT 
    mo.id as mo_id,
    mo.status,
    so.id as sale_order_id,
    so.order_number,
    sol.id as sale_order_line_id,
    ql.id as quote_line_id,
    ql.bom_template_id,
    ql.product_type_id,
    ql.hardware_color,
    ql.drive_type,
    ql.cassette,
    ql.side_channel,
    ql.width_m,
    ql.height_m
  FROM "ManufacturingOrders" mo
  JOIN "SalesOrders" so ON so.id = mo.sale_order_id
  JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id
  JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
  WHERE mo.id = '79d6cc3c-b546-4c6f-97ca-42125f7454d5'::uuid -- ⚠️ REEMPLAZAR CON EL ID REAL
  LIMIT 1
)
SELECT 
  'QuoteLine Info' as section,
  jsonb_build_object(
    'quote_line_id', ql.id,
    'bom_template_id', ql.bom_template_id,
    'product_type_id', ql.product_type_id,
    'hardware_color', ql.hardware_color,
    'drive_type', ql.drive_type,
    'cassette', ql.cassette,
    'side_channel', ql.side_channel,
    'width_m', ql.width_m,
    'height_m', ql.height_m
  ) as data
FROM mo_info mo
JOIN "QuoteLines" ql ON ql.id = mo.quote_line_id

UNION ALL

SELECT 
  'BOM Template Info' as section,
  jsonb_build_object(
    'template_id', bt.id,
    'template_name', bt.name,
    'product_type_id', bt.product_type_id,
    'active', bt.active,
    'deleted', bt.deleted,
    'components_count', (
      SELECT COUNT(*) 
      FROM "BOMComponents" bc 
      WHERE bc.bom_template_id = bt.id 
      AND bc.deleted = false
    )
  ) as data
FROM mo_info mo
LEFT JOIN "BOMTemplates" bt ON bt.id = mo.bom_template_id

UNION ALL

SELECT 
  'BOM Components (Template)' as section,
  jsonb_agg(
    jsonb_build_object(
      'id', bc.id,
      'component_role', bc.component_role,
      'auto_select', bc.auto_select,
      'component_item_id', bc.component_item_id,
      'qty_type', bc.qty_type,
      'qty_value', bc.qty_value,
      'uom', bc.uom,
      'hardware_color', bc.hardware_color,
      'sku_resolution_rule', bc.sku_resolution_rule,
      'block_condition', bc.block_condition
    )
    ORDER BY bc.component_role, bc.auto_select DESC
  ) as data
FROM mo_info mo
LEFT JOIN "BOMTemplates" bt ON bt.id = mo.bom_template_id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
GROUP BY mo.mo_id

UNION ALL

SELECT 
  'QuoteLineComponents' as section,
  jsonb_agg(
    jsonb_build_object(
      'id', qlc.id,
      'component_role', qlc.component_role,
      'catalog_item_id', qlc.catalog_item_id,
      'qty', qlc.qty,
      'uom', qlc.uom,
      'source', qlc.source
    )
    ORDER BY qlc.component_role
  ) as data
FROM mo_info mo
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = mo.quote_line_id AND qlc.deleted = false
GROUP BY mo.mo_id

UNION ALL

SELECT 
  'Generated BOM Lines' as section,
  jsonb_agg(
    jsonb_build_object(
      'id', bil.id,
      'part_role', bil.part_role,
      'resolved_sku', bil.resolved_sku,
      'description', bil.description,
      'qty', bil.qty,
      'uom', bil.uom,
      'category_code', bil.category_code,
      'unit_cost_exw', bil.unit_cost_exw,
      'total_cost_exw', bil.total_cost_exw,
      'unit_msrp_sale_out', bil.unit_msrp_sale_out,
      'total_msrp_sale_out', bil.total_msrp_sale_out
    )
    ORDER BY bil.category_code, bil.part_role
  ) as data
FROM mo_info mo
JOIN "SalesOrderLines" sol ON sol.sale_order_id = mo.sale_order_id
JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
GROUP BY mo.mo_id;


