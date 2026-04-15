-- ============================================================================
-- 1. Add sales_order_id to DeliveryNotes (was missing from original schema)
-- 2. Make manufacturing_order_id nullable (DN can be SO-level)
-- 3. Add claim_id to finished_goods_by_so view for service MO detection
-- ============================================================================

SET search_path = public;

-- 1) Add sales_order_id column to DeliveryNotes
ALTER TABLE public."DeliveryNotes"
  ADD COLUMN IF NOT EXISTS sales_order_id uuid REFERENCES public."SalesOrders"(id);

CREATE INDEX IF NOT EXISTS idx_delivery_notes_so
  ON public."DeliveryNotes"(sales_order_id) WHERE sales_order_id IS NOT NULL;

-- Backfill existing delivery notes from their MO's sales_order_id
UPDATE public."DeliveryNotes" dn
SET sales_order_id = mo.sales_order_id
FROM public."ManufacturingOrders" mo
WHERE dn.manufacturing_order_id = mo.id
  AND dn.sales_order_id IS NULL
  AND mo.sales_order_id IS NOT NULL;

-- 2) Make manufacturing_order_id nullable (DN can be SO-level)
ALTER TABLE public."DeliveryNotes"
  ALTER COLUMN manufacturing_order_id DROP NOT NULL;

-- 3) Create finished_goods_by_so view with claim_id for service MO detection
CREATE OR REPLACE VIEW public.finished_goods_by_so AS
SELECT
  'product' AS line_type,
  mol.id AS line_id,
  mo.sales_order_id,
  mo.id AS manufacturing_order_id,
  mo.manufacturing_order_no,
  mo.status AS mo_status,
  mo.organization_id,
  mol.delivery_status,
  mol.quantity,
  mol.delivered_qty,
  mol.delivered_at,
  so.sales_order_no,
  d.dealer_name,
  dc.customer_name,
  sol.description AS line_description,
  sol.product_type,
  sol.area,
  sol.position,
  ci.name AS catalog_item_name,
  ci.sku AS catalog_item_sku,
  mo.released_at,
  mo.claim_id
FROM public."ManufacturingOrderLines" mol
JOIN public."ManufacturingOrders" mo ON mo.id = mol.manufacturing_order_id
LEFT JOIN public."SalesOrders" so ON so.id = mo.sales_order_id
LEFT JOIN public."Dealers" d ON d.id = so.dealer_id
LEFT JOIN public."DirectoryCustomers" dc ON dc.id = so.customer_id
LEFT JOIN public."SaleOrderLines" sol ON sol.id = mol.sales_order_line_id
LEFT JOIN public."CatalogItems" ci ON ci.id = sol.catalog_item_id
WHERE mol.deleted = false
  AND mo.deleted = false
  AND mo.status IN ('ready_for_pickup', 'delivered')
  AND mol.delivery_status IN ('ready', 'delivered');
