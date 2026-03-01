-- Inventory Unit Model v2 consistency checks
-- Keeps CatalogItems and PurchaseOrderLines snapshot semantics aligned.

ALTER TABLE public."CatalogItems"
  DROP CONSTRAINT IF EXISTS catalogitems_stock_basis_required_check;
ALTER TABLE public."CatalogItems"
  ADD CONSTRAINT catalogitems_stock_basis_required_check
  CHECK (
    (COALESCE(is_roll, false) = true AND stock_basis = 'linear_m')
    OR (COALESCE(is_roll, false) = false AND stock_basis IN ('ea', 'linear_m'))
  );

ALTER TABLE public."CatalogItems"
  DROP CONSTRAINT IF EXISTS catalogitems_purchase_uom_mode_check;
ALTER TABLE public."CatalogItems"
  ADD CONSTRAINT catalogitems_purchase_uom_mode_check
  CHECK (
    purchase_mode IS NULL
    OR (
      purchase_mode = 'roll'
      AND lower(COALESCE(purchase_uom, '')) = 'roll'
    )
    OR (
      purchase_mode = 'linear_direct'
      AND lower(COALESCE(purchase_uom, '')) IN ('m', 'ft', 'yd')
    )
    OR (
      purchase_mode = 'unit_packaged'
      AND lower(COALESCE(purchase_uom, '')) IN (
        'each', 'pack', 'set', 'box', 'case', 'bag', 'bundle', 'carton'
      )
    )
  );

UPDATE public."CatalogItems"
SET
  purchase_uom = CASE
    WHEN purchase_mode = 'roll' THEN 'roll'
    WHEN purchase_mode = 'linear_direct'
      THEN CASE
        WHEN lower(COALESCE(purchase_uom, '')) IN ('m', 'ft', 'yd')
          THEN lower(purchase_uom)
        WHEN lower(COALESCE(purchase_unit::text, '')) IN ('m', 'ft', 'yd')
          THEN lower(purchase_unit::text)
        ELSE 'm'
      END
    WHEN purchase_mode = 'unit_packaged'
      THEN CASE
        WHEN lower(COALESCE(purchase_uom, '')) IN ('each', 'pack', 'set', 'box', 'case', 'bag', 'bundle', 'carton')
          THEN lower(purchase_uom)
        WHEN lower(COALESCE(purchase_unit::text, '')) IN ('each', 'pack', 'set', 'box', 'case', 'bag', 'bundle', 'carton')
          THEN lower(purchase_unit::text)
        ELSE 'each'
      END
    ELSE purchase_uom
  END,
  stock_basis = CASE
    WHEN COALESCE(is_roll, false) = true THEN 'linear_m'
    ELSE COALESCE(stock_basis, CASE WHEN measure_basis = 'linear' THEN 'linear_m' ELSE 'ea' END)
  END
WHERE purchase_mode IS NOT NULL OR stock_basis IS NULL OR purchase_uom IS NULL;

ALTER TABLE public."PurchaseOrderLines"
  DROP CONSTRAINT IF EXISTS purchaseorderlines_purchase_uom_mode_snapshot_check;
ALTER TABLE public."PurchaseOrderLines"
  ADD CONSTRAINT purchaseorderlines_purchase_uom_mode_snapshot_check
  CHECK (
    purchase_mode_snapshot IS NULL
    OR (
      purchase_mode_snapshot = 'roll'
      AND lower(COALESCE(purchase_uom_snapshot, '')) = 'roll'
    )
    OR (
      purchase_mode_snapshot = 'linear_direct'
      AND lower(COALESCE(purchase_uom_snapshot, '')) IN ('m', 'ft', 'yd')
    )
    OR (
      purchase_mode_snapshot = 'unit_packaged'
      AND lower(COALESCE(purchase_uom_snapshot, '')) IN (
        'each', 'pack', 'set', 'box', 'case', 'bag', 'bundle', 'carton'
      )
    )
  );

UPDATE public."PurchaseOrderLines"
SET
  purchase_uom_snapshot = CASE
    WHEN purchase_mode_snapshot = 'roll' THEN 'roll'
    WHEN purchase_mode_snapshot = 'linear_direct'
      THEN CASE
        WHEN lower(COALESCE(purchase_uom_snapshot, '')) IN ('m', 'ft', 'yd')
          THEN lower(purchase_uom_snapshot)
        WHEN lower(COALESCE(purchase_unit_snapshot, unit, '')) IN ('m', 'ft', 'yd')
          THEN lower(COALESCE(purchase_unit_snapshot, unit))
        ELSE 'm'
      END
    WHEN purchase_mode_snapshot = 'unit_packaged'
      THEN CASE
        WHEN lower(COALESCE(purchase_uom_snapshot, '')) IN ('each', 'pack', 'set', 'box', 'case', 'bag', 'bundle', 'carton')
          THEN lower(purchase_uom_snapshot)
        WHEN lower(COALESCE(purchase_unit_snapshot, unit, '')) IN ('each', 'pack', 'set', 'box', 'case', 'bag', 'bundle', 'carton')
          THEN lower(COALESCE(purchase_unit_snapshot, unit))
        ELSE 'each'
      END
    ELSE purchase_uom_snapshot
  END
WHERE purchase_mode_snapshot IS NOT NULL;
