-- Use purchase-facing roll dimensions on PO line snapshots.
-- Internal normalized meters are not used for purchasing display.

ALTER TABLE public."PurchaseOrderLines"
  ADD COLUMN IF NOT EXISTS roll_width_value_snapshot numeric NULL,
  ADD COLUMN IF NOT EXISTS roll_width_uom_snapshot text NULL,
  ADD COLUMN IF NOT EXISTS roll_length_value_snapshot numeric NULL,
  ADD COLUMN IF NOT EXISTS roll_length_uom_snapshot text NULL;

UPDATE public."PurchaseOrderLines" pol
SET
  roll_width_value_snapshot = COALESCE(pol.roll_width_value_snapshot, ci.roll_width_value),
  roll_width_uom_snapshot = COALESCE(pol.roll_width_uom_snapshot, ci.roll_width_uom),
  roll_length_value_snapshot = COALESCE(pol.roll_length_value_snapshot, ci.roll_length_value),
  roll_length_uom_snapshot = COALESCE(pol.roll_length_uom_snapshot, ci.roll_length_uom)
FROM public."CatalogItems" ci
WHERE pol.catalog_item_id = ci.id;
