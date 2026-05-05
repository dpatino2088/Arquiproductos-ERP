-- ============================================================================
-- Filter manufacturing_order_material_demand by MOL status.
-- Only lines that are reviewed (or beyond) contribute to material demand;
-- draft and cancelled MOLs no longer pollute purchasing demand totals.
-- ============================================================================

CREATE OR REPLACE VIEW public.manufacturing_order_material_demand AS
SELECT
  bi.manufacturing_order_id,
  bi.organization_id,
  bil.resolved_part_id AS catalog_item_id,
  ci.sku,
  ci.name AS item_name,
  SUM(bil.qty) * mo.quantity AS required_qty,
  bil.uom,
  mo.manufacturing_order_no,
  mo.status AS mo_status
FROM "BOMInstanceLines" bil
JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
JOIN "ManufacturingOrders" mo ON mo.id = bi.manufacturing_order_id
JOIN "ManufacturingOrderLines" mol
  ON mol.manufacturing_order_id = bi.manufacturing_order_id
  AND mol.sales_order_line_id = bi.sales_order_line_id
  AND mol.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE bi.deleted = false
  AND bil.deleted = false
  AND mo.deleted = false
  AND mol.status IN (
    'reviewed',
    'confirmed',
    'procurement',
    'material_available',
    'materials_ready',
    'in_production'
  )
GROUP BY bi.manufacturing_order_id, bi.organization_id, bil.resolved_part_id,
         ci.sku, ci.name, bil.uom, mo.manufacturing_order_no, mo.status,
         mo.quantity;
