CREATE OR REPLACE VIEW public.manufacturing_order_material_demand AS
SELECT
  bi.manufacturing_order_id,
  bi.organization_id,
  bil.resolved_part_id AS catalog_item_id,
  ci.sku,
  ci.name AS item_name,
  SUM(bil.qty) AS required_qty,
  bil.uom,
  mo.manufacturing_order_no,
  mo.status AS mo_status
FROM public."BOMInstanceLines" bil
JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id
JOIN public."ManufacturingOrders" mo ON mo.id = bi.manufacturing_order_id
LEFT JOIN public."CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE bi.deleted = false AND bil.deleted = false AND mo.deleted = false
GROUP BY bi.manufacturing_order_id, bi.organization_id,
         bil.resolved_part_id, ci.sku, ci.name, bil.uom,
         mo.manufacturing_order_no, mo.status;

COMMENT ON VIEW public.manufacturing_order_material_demand IS 'Aggregated material demand from BOM per MO for purchasing alignment.';;
