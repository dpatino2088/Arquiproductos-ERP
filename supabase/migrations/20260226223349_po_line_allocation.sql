-- Add per-line allocation columns to PurchaseOrderLines
-- allocation_type: 'stock' (default) or 'manufacturing_order'
-- allocation_mo_id: FK to ManufacturingOrders when allocation_type = 'manufacturing_order'
-- allocation_notes: optional notes per allocation

ALTER TABLE public."PurchaseOrderLines"
  ADD COLUMN IF NOT EXISTS allocation_type text NOT NULL DEFAULT 'stock',
  ADD COLUMN IF NOT EXISTS allocation_mo_id uuid NULL,
  ADD COLUMN IF NOT EXISTS allocation_notes text NULL;

-- FK to ManufacturingOrders
ALTER TABLE public."PurchaseOrderLines"
  ADD CONSTRAINT fk_po_line_allocation_mo
  FOREIGN KEY (allocation_mo_id)
  REFERENCES public."ManufacturingOrders"(id)
  ON DELETE RESTRICT;

-- CHECK: stock lines must have NULL mo_id; MO lines must have a mo_id
ALTER TABLE public."PurchaseOrderLines"
  ADD CONSTRAINT chk_po_line_allocation_consistency
  CHECK (
    (allocation_type = 'stock' AND allocation_mo_id IS NULL)
    OR
    (allocation_type = 'manufacturing_order' AND allocation_mo_id IS NOT NULL)
  );

-- Backfill from legacy PurchaseOrders.reference_type/reference_id:
-- For POs with a single MO reference, set all their lines to that MO.
UPDATE public."PurchaseOrderLines" pol
SET
  allocation_type = 'manufacturing_order',
  allocation_mo_id = po.reference_id
FROM public."PurchaseOrders" po
WHERE pol.purchase_order_id = po.id
  AND po.reference_type = 'manufacturing_order'
  AND po.reference_id IS NOT NULL;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_po_lines_allocation_mo
  ON public."PurchaseOrderLines"(allocation_mo_id)
  WHERE allocation_mo_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_po_lines_allocation_type
  ON public."PurchaseOrderLines"(allocation_type);;
