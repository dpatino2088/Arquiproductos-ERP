-- Inventory Unit Model v2
-- Adds explicit model fields to CatalogItems and PO snapshots while preserving legacy compatibility.

ALTER TABLE public."CatalogItems"
  ADD COLUMN IF NOT EXISTS purchase_mode text NULL,
  ADD COLUMN IF NOT EXISTS stock_basis text NULL,
  ADD COLUMN IF NOT EXISTS purchase_uom text NULL;

ALTER TABLE public."CatalogItems"
  DROP CONSTRAINT IF EXISTS catalogitems_purchase_mode_check;
ALTER TABLE public."CatalogItems"
  ADD CONSTRAINT catalogitems_purchase_mode_check
  CHECK (purchase_mode IS NULL OR purchase_mode IN ('unit_packaged', 'linear_direct', 'roll'));

ALTER TABLE public."CatalogItems"
  DROP CONSTRAINT IF EXISTS catalogitems_stock_basis_check;
ALTER TABLE public."CatalogItems"
  ADD CONSTRAINT catalogitems_stock_basis_check
  CHECK (stock_basis IS NULL OR stock_basis IN ('ea', 'linear_m'));

UPDATE public."CatalogItems"
SET
  stock_basis = CASE
    WHEN COALESCE(is_roll, false) = true OR measure_basis = 'linear' THEN 'linear_m'
    ELSE 'ea'
  END,
  purchase_mode = CASE
    WHEN COALESCE(is_roll, false) = true THEN 'roll'
    WHEN measure_basis = 'linear' AND lower(COALESCE(purchase_unit::text, '')) IN ('m', 'ft', 'yd') THEN 'linear_direct'
    WHEN measure_basis = 'linear' THEN 'unit_packaged'
    ELSE 'unit_packaged'
  END,
  purchase_uom = CASE
    WHEN COALESCE(is_roll, false) = true THEN 'roll'
    WHEN measure_basis = 'linear' AND lower(COALESCE(purchase_unit::text, '')) IN ('m', 'ft', 'yd')
      THEN lower(COALESCE(purchase_unit::text, unit_of_measure, 'm'))
    WHEN measure_basis = 'linear'
      THEN lower(COALESCE(unit_of_measure, 'm'))
    ELSE lower(COALESCE(purchase_unit::text, 'each'))
  END
WHERE purchase_mode IS NULL
   OR stock_basis IS NULL
   OR purchase_uom IS NULL;

ALTER TABLE public."PurchaseOrderLines"
  ADD COLUMN IF NOT EXISTS purchase_mode_snapshot text NULL,
  ADD COLUMN IF NOT EXISTS stock_basis_snapshot text NULL,
  ADD COLUMN IF NOT EXISTS purchase_uom_snapshot text NULL;

ALTER TABLE public."PurchaseOrderLines"
  DROP CONSTRAINT IF EXISTS purchaseorderlines_purchase_mode_snapshot_check;
ALTER TABLE public."PurchaseOrderLines"
  ADD CONSTRAINT purchaseorderlines_purchase_mode_snapshot_check
  CHECK (purchase_mode_snapshot IS NULL OR purchase_mode_snapshot IN ('unit_packaged', 'linear_direct', 'roll'));

ALTER TABLE public."PurchaseOrderLines"
  DROP CONSTRAINT IF EXISTS purchaseorderlines_stock_basis_snapshot_check;
ALTER TABLE public."PurchaseOrderLines"
  ADD CONSTRAINT purchaseorderlines_stock_basis_snapshot_check
  CHECK (stock_basis_snapshot IS NULL OR stock_basis_snapshot IN ('ea', 'linear_m'));

UPDATE public."PurchaseOrderLines" pol
SET
  stock_basis_snapshot = COALESCE(
    pol.stock_basis_snapshot,
    CASE
      WHEN COALESCE(pol.is_roll_snapshot, false) = true THEN 'linear_m'
      WHEN ci.measure_basis = 'linear' THEN 'linear_m'
      ELSE 'ea'
    END
  ),
  purchase_mode_snapshot = COALESCE(
    pol.purchase_mode_snapshot,
    CASE
      WHEN COALESCE(pol.is_roll_snapshot, false) = true THEN 'roll'
      WHEN ci.measure_basis = 'linear'
        AND lower(COALESCE(pol.purchase_uom_snapshot, pol.purchase_unit_snapshot, pol.unit, '')) IN ('m', 'ft', 'yd') THEN 'linear_direct'
      WHEN ci.measure_basis = 'linear' THEN 'unit_packaged'
      ELSE 'unit_packaged'
    END
  ),
  purchase_uom_snapshot = COALESCE(
    pol.purchase_uom_snapshot,
    CASE
      WHEN COALESCE(pol.is_roll_snapshot, false) = true THEN 'roll'
      WHEN ci.measure_basis = 'linear'
        AND lower(COALESCE(pol.purchase_unit_snapshot, pol.unit, '')) IN ('m', 'ft', 'yd')
          THEN lower(COALESCE(pol.purchase_unit_snapshot, pol.unit, 'm'))
      WHEN ci.measure_basis = 'linear'
          THEN lower(COALESCE(pol.unit_of_measure_snapshot, pol.unit, 'm'))
      ELSE lower(COALESCE(pol.purchase_unit_snapshot, pol.unit, 'each'))
    END
  )
FROM public."CatalogItems" ci
WHERE pol.catalog_item_id = ci.id;

UPDATE public."PurchaseOrderLines"
SET
  stock_basis_snapshot = COALESCE(stock_basis_snapshot, 'ea'),
  purchase_mode_snapshot = COALESCE(purchase_mode_snapshot, 'unit_packaged'),
  purchase_uom_snapshot = COALESCE(purchase_uom_snapshot, lower(COALESCE(purchase_unit_snapshot, unit, 'each')))
WHERE stock_basis_snapshot IS NULL
   OR purchase_mode_snapshot IS NULL
   OR purchase_uom_snapshot IS NULL;
