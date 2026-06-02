-- Restore the bil.excluded = false filter dropped during the sol.quantity rewrite
-- (20261220010000). Keeps demand aligned with issue_materials, which excludes them.
CREATE OR REPLACE VIEW public.manufacturing_order_material_demand AS
 SELECT bi.manufacturing_order_id,
    bi.organization_id,
    bil.resolved_part_id AS catalog_item_id,
    ci.sku,
    ci.name AS item_name,
    sum(bil.qty * COALESCE(sol.quantity, 1)::numeric) AS required_qty,
    bil.uom,
    mo.manufacturing_order_no,
    mo.status AS mo_status
   FROM "BOMInstanceLines" bil
     JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
     JOIN "ManufacturingOrders" mo ON mo.id = bi.manufacturing_order_id
     JOIN "ManufacturingOrderLines" mol ON mol.manufacturing_order_id = bi.manufacturing_order_id AND mol.sales_order_line_id = bi.sales_order_line_id AND mol.deleted = false
     JOIN "SaleOrderLines" sol ON sol.id = bi.sales_order_line_id
     LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
  WHERE bi.deleted = false AND bil.deleted = false AND bil.excluded = false AND mo.deleted = false AND (mol.status = ANY (ARRAY['reviewed'::text, 'confirmed'::text, 'procurement'::text, 'material_available'::text, 'materials_ready'::text, 'in_production'::text]))
  GROUP BY bi.manufacturing_order_id, bi.organization_id, bil.resolved_part_id, ci.sku, ci.name, bil.uom, mo.manufacturing_order_no, mo.status;
