
-- Extend PurchaseOrders: add SO/MO reference, totals, notes, currency

-- reference_type: 'sales_order' | 'manufacturing_order' | null
ALTER TABLE public."PurchaseOrders"
  ADD COLUMN IF NOT EXISTS reference_type text;

-- reference_id: FK to SalesOrders or ManufacturingOrders (polymorphic, no hard FK)
ALTER TABLE public."PurchaseOrders"
  ADD COLUMN IF NOT EXISTS reference_id uuid;

-- notes: free-text notes
ALTER TABLE public."PurchaseOrders"
  ADD COLUMN IF NOT EXISTS notes text;

-- subtotal: sum of line_totals (maintained by app)
ALTER TABLE public."PurchaseOrders"
  ADD COLUMN IF NOT EXISTS subtotal numeric(12,2) NOT NULL DEFAULT 0;

-- total: final total (= subtotal for now, extensible for taxes/discounts later)
ALTER TABLE public."PurchaseOrders"
  ADD COLUMN IF NOT EXISTS total numeric(12,2) NOT NULL DEFAULT 0;

-- currency
ALTER TABLE public."PurchaseOrders"
  ADD COLUMN IF NOT EXISTS currency text NOT NULL DEFAULT 'USD';

-- Index for reference lookups (e.g. find all POs for a given SO)
CREATE INDEX IF NOT EXISTS idx_purchase_orders_reference
  ON public."PurchaseOrders" (reference_type, reference_id)
  WHERE reference_type IS NOT NULL;

COMMENT ON COLUMN public."PurchaseOrders".reference_type IS 'Source document type: sales_order or manufacturing_order. Multiple POs can reference the same SO/MO.';
COMMENT ON COLUMN public."PurchaseOrders".reference_id IS 'UUID of the source SO or MO. Polymorphic FK (no hard constraint).';
COMMENT ON COLUMN public."PurchaseOrders".subtotal IS 'Sum of PO line totals. Maintained by application on save.';
;
