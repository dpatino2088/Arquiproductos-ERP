
-- Extend PurchaseOrderLines: add cost tracking and one-off item support

-- unit_cost: snapshot from CatalogItems.cost_exw at PO creation, editable per line (audit trail)
ALTER TABLE public."PurchaseOrderLines"
  ADD COLUMN IF NOT EXISTS unit_cost numeric(12,4) NOT NULL DEFAULT 0;

-- description: used for one-off items (no catalog_item_id)
ALTER TABLE public."PurchaseOrderLines"
  ADD COLUMN IF NOT EXISTS description text;

-- is_one_off: true when item is not from catalog
ALTER TABLE public."PurchaseOrderLines"
  ADD COLUMN IF NOT EXISTS is_one_off boolean NOT NULL DEFAULT false;

-- notes: optional per-line notes
ALTER TABLE public."PurchaseOrderLines"
  ADD COLUMN IF NOT EXISTS notes text;

-- Make catalog_item_id nullable to support one-off items
ALTER TABLE public."PurchaseOrderLines"
  ALTER COLUMN catalog_item_id DROP NOT NULL;

-- line_total: computed column = ordered_qty * unit_cost
ALTER TABLE public."PurchaseOrderLines"
  ADD COLUMN IF NOT EXISTS line_total numeric(12,4) GENERATED ALWAYS AS (ordered_qty * unit_cost) STORED;

COMMENT ON COLUMN public."PurchaseOrderLines".unit_cost IS 'Snapshot of purchase price at time of PO creation. Copied from CatalogItems.cost_exw by default but editable. Never modifies the original catalog cost.';
COMMENT ON COLUMN public."PurchaseOrderLines".is_one_off IS 'True for ad-hoc/miscellaneous items not in catalog. catalog_item_id is NULL for these.';
COMMENT ON COLUMN public."PurchaseOrderLines".line_total IS 'Computed: ordered_qty * unit_cost.';
;
