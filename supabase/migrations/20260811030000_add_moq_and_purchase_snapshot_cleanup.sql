-- MOQ + Purchase Unit flow
-- 1) Add CatalogItems.moq (expressed in purchase_unit)
-- 2) Add PurchaseOrderLines.moq_snapshot for historical consistency
-- 3) Controlled cleanup for obvious linear "tramo" SKUs (tube/profile bars)

ALTER TABLE public."CatalogItems"
  ADD COLUMN IF NOT EXISTS moq numeric(14,4) NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'catalogitems_moq_nonnegative'
  ) THEN
    ALTER TABLE public."CatalogItems"
      ADD CONSTRAINT catalogitems_moq_nonnegative
      CHECK (moq >= 0);
  END IF;
END $$;

ALTER TABLE public."PurchaseOrderLines"
  ADD COLUMN IF NOT EXISTS moq_snapshot numeric(14,4);

UPDATE public."CatalogItems"
SET moq = 0
WHERE moq IS NULL;

-- Snapshot current MOQ into existing PO lines (best effort historical context).
-- We do not overwrite existing snapshots.
UPDATE public."PurchaseOrderLines" pol
SET moq_snapshot = ci.moq
FROM public."CatalogItems" ci
WHERE pol.catalog_item_id = ci.id
  AND pol.moq_snapshot IS NULL;

-- Controlled cleanup:
-- Linear bars sold by tramo should use purchase_unit='each'
-- and units_per_purchase_unit in internal meters.
-- Restrict to tube/profile-like SKUs to avoid broad side effects.
UPDATE public."CatalogItems"
SET
  purchase_unit = 'each',
  units_per_purchase_unit = CASE
    WHEN purchase_unit = 'ft' THEN ROUND(units_per_purchase_unit * 0.3048, 4)
    ELSE units_per_purchase_unit
  END,
  updated_at = now()
WHERE measure_basis = 'linear'
  AND units_per_purchase_unit > 1
  AND purchase_unit IN ('ft', 'm')
  AND (
    sku ILIKE 'RTU-%'
    OR sku ILIKE 'LUT-%'
    OR name ILIKE '%tube%'
    OR name ILIKE '%profile%'
  );

