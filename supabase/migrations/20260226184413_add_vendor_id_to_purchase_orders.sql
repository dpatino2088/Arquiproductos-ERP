
ALTER TABLE public."PurchaseOrders"
  ADD COLUMN IF NOT EXISTS vendor_id uuid REFERENCES public."DirectoryVendors"(id);

CREATE INDEX IF NOT EXISTS idx_purchase_orders_vendor_id ON public."PurchaseOrders"(vendor_id);
;
