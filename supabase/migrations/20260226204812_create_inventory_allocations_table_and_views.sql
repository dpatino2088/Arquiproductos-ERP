
-- ============================================================
-- Inventory Allocations table + views
-- ============================================================

-- 1A. InventoryAllocations table
CREATE TABLE IF NOT EXISTS public."InventoryAllocations" (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public."Organizations"(id),
    warehouse_id    uuid NOT NULL REFERENCES public."Warehouses"(id),
    catalog_item_id uuid NOT NULL REFERENCES public."CatalogItems"(id),
    sales_order_id  uuid NOT NULL REFERENCES public."SalesOrders"(id),
    sale_order_line_id uuid REFERENCES public."SaleOrderLines"(id),
    allocated_qty   numeric(12,4) NOT NULL CHECK (allocated_qty > 0),
    status          text NOT NULL DEFAULT 'reserved'
                    CHECK (status IN ('reserved','issued','released')),
    source          text DEFAULT 'manual'
                    CHECK (source IN ('manual','auto_receipt','auto_bulk')),
    allocated_at    timestamptz NOT NULL DEFAULT now(),
    issued_at       timestamptz,
    released_at     timestamptz,
    notes           text,
    created_by      uuid,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public."InventoryAllocations" OWNER TO postgres;

COMMENT ON TABLE public."InventoryAllocations" IS
  'Reserves inventory for a specific Sales Order. status: reserved (in warehouse but committed), issued (sent to production), released (freed back).';

CREATE INDEX idx_inv_alloc_org_so ON public."InventoryAllocations" (organization_id, sales_order_id);
CREATE INDEX idx_inv_alloc_org_item ON public."InventoryAllocations" (organization_id, catalog_item_id);
CREATE INDEX idx_inv_alloc_warehouse ON public."InventoryAllocations" (warehouse_id, catalog_item_id);

-- RLS
ALTER TABLE public."InventoryAllocations" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inv_alloc_select_org" ON public."InventoryAllocations"
    FOR SELECT USING (public.is_org_user_member_strict(organization_id) OR public.is_portal_user_in_org(organization_id));

CREATE POLICY "inv_alloc_insert_org" ON public."InventoryAllocations"
    FOR INSERT WITH CHECK (public.is_org_user_member_strict(organization_id) OR public.is_portal_user_in_org(organization_id));

CREATE POLICY "inv_alloc_update_org" ON public."InventoryAllocations"
    FOR UPDATE USING (public.is_org_user_member_strict(organization_id) OR public.is_portal_user_in_org(organization_id));

CREATE POLICY "inv_alloc_delete_org" ON public."InventoryAllocations"
    FOR DELETE USING (public.is_org_user_member_strict(organization_id) OR public.is_portal_user_in_org(organization_id));

GRANT SELECT, INSERT, UPDATE, DELETE ON public."InventoryAllocations" TO authenticated;

-- 1B. inventory_allocated view
CREATE OR REPLACE VIEW public.inventory_allocated AS
SELECT
    organization_id,
    warehouse_id,
    catalog_item_id,
    SUM(allocated_qty) AS allocated_qty
FROM public."InventoryAllocations"
WHERE status = 'reserved'
GROUP BY organization_id, warehouse_id, catalog_item_id;

ALTER VIEW public.inventory_allocated OWNER TO postgres;
GRANT SELECT ON public.inventory_allocated TO authenticated;

-- 1C. inventory_available view
CREATE OR REPLACE VIEW public.inventory_available AS
SELECT
    a.organization_id,
    a.warehouse_id,
    a.catalog_item_id,
    a.on_hand_qty,
    COALESCE(al.allocated_qty, 0) AS allocated_qty,
    GREATEST(a.on_hand_qty - COALESCE(al.allocated_qty, 0), 0) AS available_qty,
    a.on_order_qty,
    a.next_eta,
    a.availability,
    a.risk_level,
    a.is_risk,
    a.is_special_order
FROM public.inventory_availability a
LEFT JOIN public.inventory_allocated al
    ON al.organization_id = a.organization_id
   AND al.warehouse_id    = a.warehouse_id
   AND al.catalog_item_id = a.catalog_item_id;

ALTER VIEW public.inventory_available OWNER TO postgres;
GRANT SELECT ON public.inventory_available TO authenticated;
;
