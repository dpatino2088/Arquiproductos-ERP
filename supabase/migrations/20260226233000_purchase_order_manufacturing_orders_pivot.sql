-- Multi-MO references for Purchase Orders
-- Phase 1: add pivot table + backfill from legacy PurchaseOrders.reference_id

CREATE TABLE IF NOT EXISTS public."PurchaseOrderManufacturingOrders" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
  purchase_order_id uuid NOT NULL REFERENCES public."PurchaseOrders"(id) ON DELETE CASCADE,
  manufacturing_order_id uuid NOT NULL REFERENCES public."ManufacturingOrders"(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid NULL,
  deleted boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  CONSTRAINT po_mo_unique UNIQUE (purchase_order_id, manufacturing_order_id)
);

CREATE INDEX IF NOT EXISTS idx_po_mo_org
  ON public."PurchaseOrderManufacturingOrders"(organization_id);
CREATE INDEX IF NOT EXISTS idx_po_mo_po
  ON public."PurchaseOrderManufacturingOrders"(purchase_order_id);
CREATE INDEX IF NOT EXISTS idx_po_mo_mo
  ON public."PurchaseOrderManufacturingOrders"(manufacturing_order_id);

-- Backfill from legacy single-reference fields
INSERT INTO public."PurchaseOrderManufacturingOrders" (
  organization_id,
  purchase_order_id,
  manufacturing_order_id
)
SELECT
  po.organization_id,
  po.id,
  po.reference_id
FROM public."PurchaseOrders" po
JOIN public."ManufacturingOrders" mo ON mo.id = po.reference_id
WHERE po.reference_type = 'manufacturing_order'
  AND po.reference_id IS NOT NULL
ON CONFLICT (purchase_order_id, manufacturing_order_id) DO NOTHING;

ALTER TABLE public."PurchaseOrderManufacturingOrders" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "purchase_order_mo_select_org" ON public."PurchaseOrderManufacturingOrders";
CREATE POLICY "purchase_order_mo_select_org" ON public."PurchaseOrderManufacturingOrders"
  FOR SELECT
  USING (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "purchase_order_mo_insert_org" ON public."PurchaseOrderManufacturingOrders";
CREATE POLICY "purchase_order_mo_insert_org" ON public."PurchaseOrderManufacturingOrders"
  FOR INSERT
  WITH CHECK (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "purchase_order_mo_update_org" ON public."PurchaseOrderManufacturingOrders";
CREATE POLICY "purchase_order_mo_update_org" ON public."PurchaseOrderManufacturingOrders"
  FOR UPDATE
  USING (public.is_org_user_member_strict(organization_id))
  WITH CHECK (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "purchase_order_mo_delete_org" ON public."PurchaseOrderManufacturingOrders";
CREATE POLICY "purchase_order_mo_delete_org" ON public."PurchaseOrderManufacturingOrders"
  FOR DELETE
  USING (public.is_org_user_member_strict(organization_id));

