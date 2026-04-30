-- Add optional ship-to address reference/snapshot on Purchase Orders

ALTER TABLE public."PurchaseOrders"
  ADD COLUMN IF NOT EXISTS ship_to_address_id uuid NULL REFERENCES public."OrganizationAddresses"(id) ON DELETE SET NULL;

ALTER TABLE public."PurchaseOrders"
  ADD COLUMN IF NOT EXISTS ship_to_address_snapshot text NULL;

CREATE INDEX IF NOT EXISTS idx_purchase_orders_ship_to_address_id
  ON public."PurchaseOrders" (ship_to_address_id);

COMMENT ON COLUMN public."PurchaseOrders".ship_to_address_id IS
  'Optional reference to OrganizationAddresses used as Ship-To destination for this PO.';

COMMENT ON COLUMN public."PurchaseOrders".ship_to_address_snapshot IS
  'Text snapshot of Ship-To address at PO save time, for historical consistency.';

NOTIFY pgrst, 'reload schema';
