-- Fix: manufacturing_order_material_demand was NOT multiplying BOM per-unit
-- quantities by mo.quantity.  MOs with qty > 1 showed drastically understated
-- demand (e.g. 3.9 m fabric instead of 561.6 m for 144 units).

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
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE bi.deleted = false
  AND bil.deleted = false
  AND mo.deleted = false
GROUP BY bi.manufacturing_order_id, bi.organization_id, bil.resolved_part_id,
         ci.sku, ci.name, bil.uom, mo.manufacturing_order_no, mo.status,
         mo.quantity;

-- Release orphaned allocations for cancelled MO-000002
UPDATE public."InventoryAllocations"
SET released_at = now()
WHERE manufacturing_order_id IN (
  SELECT id FROM public."ManufacturingOrders"
  WHERE status = 'cancelled' AND deleted = false
)
AND released_at IS NULL;
