-- Supply / resale products (the "special purchase catalog") + line-level PO->SO link.
--
-- Business context: made-to-measure / resale products are bought from a supplier
-- (via PO), received into the warehouse, and delivered against a specific Sales
-- Order line -- they are NOT shown in the sellable dealer catalog. We model this
-- as a flag on the existing item master (CatalogItems) instead of a parallel
-- catalog, so there is a single source of truth for inventory, cost and movements.

SET search_path = public;

-- 1) Flag an item as a supply/resale product (special purchase catalog).
ALTER TABLE public."CatalogItems"
  ADD COLUMN IF NOT EXISTS is_supply_product boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public."CatalogItems".is_supply_product IS
  'True for resale/made-to-measure products bought via PO and delivered as-is. Not shown in the sellable dealer catalog / configurator.';

-- 2) Line-level link: a PO line can reference the exact Sales Order line it fulfills.
--    (PO-level linkage already exists via PurchaseOrders.reference_type/reference_id.)
ALTER TABLE public."PurchaseOrderLines"
  ADD COLUMN IF NOT EXISTS sales_order_line_id uuid NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'purchaseorderlines_sales_order_line_id_fkey'
      AND table_name = 'PurchaseOrderLines'
  ) THEN
    ALTER TABLE public."PurchaseOrderLines"
      ADD CONSTRAINT purchaseorderlines_sales_order_line_id_fkey
      FOREIGN KEY (sales_order_line_id)
      REFERENCES public."SaleOrderLines"(id) ON DELETE SET NULL;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_pol_sales_order_line_id
  ON public."PurchaseOrderLines"(sales_order_line_id)
  WHERE sales_order_line_id IS NOT NULL;

COMMENT ON COLUMN public."PurchaseOrderLines".sales_order_line_id IS
  'When set, this PO line was purchased specifically to fulfill this Sales Order line (purchase-to-order for supply/MTM products).';
