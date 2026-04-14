ALTER TABLE public."PurchaseOrderLines"
  ADD COLUMN IF NOT EXISTS sku_snapshot text NULL,
  ADD COLUMN IF NOT EXISTS item_name_snapshot text NULL,
  ADD COLUMN IF NOT EXISTS purchase_unit_snapshot text NULL,
  ADD COLUMN IF NOT EXISTS units_per_purchase_unit_snapshot numeric NULL,
  ADD COLUMN IF NOT EXISTS unit_of_measure_snapshot text NULL;

UPDATE public."PurchaseOrderLines" pol
SET
  sku_snapshot = COALESCE(pol.sku_snapshot, ci.sku),
  item_name_snapshot = COALESCE(pol.item_name_snapshot, ci.name),
  purchase_unit_snapshot = COALESCE(pol.purchase_unit_snapshot, pol.unit, ci.purchase_unit::text, 'each'),
  units_per_purchase_unit_snapshot = COALESCE(pol.units_per_purchase_unit_snapshot, ci.units_per_purchase_unit, 1),
  unit_of_measure_snapshot = COALESCE(pol.unit_of_measure_snapshot, ci.unit_of_measure, 'ea')
FROM public."CatalogItems" ci
WHERE pol.catalog_item_id = ci.id;

UPDATE public."PurchaseOrderLines"
SET
  purchase_unit_snapshot = COALESCE(purchase_unit_snapshot, unit, 'each'),
  units_per_purchase_unit_snapshot = COALESCE(units_per_purchase_unit_snapshot, 1),
  unit_of_measure_snapshot = COALESCE(unit_of_measure_snapshot, 'ea')
WHERE purchase_unit_snapshot IS NULL
   OR units_per_purchase_unit_snapshot IS NULL
   OR unit_of_measure_snapshot IS NULL;;
