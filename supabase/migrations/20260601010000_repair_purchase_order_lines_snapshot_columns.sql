-- Repair: ensure PurchaseOrderLines has snapshot columns (if 20260301010000 was not applied).
-- Safe to run multiple times (ADD COLUMN IF NOT EXISTS).

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
