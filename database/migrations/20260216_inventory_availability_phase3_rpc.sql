-- =====================================================
-- Adaptio Inventory Availability — Fase 3: RPC
-- =====================================================
-- RPC get_inventory_availability: filtra por warehouse y opcionalmente catalog_item_ids.
-- STABLE (no escribe); RLS vía tablas base.
-- =====================================================

SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_inventory_availability(
  p_warehouse_id uuid,
  p_catalog_item_ids uuid[] DEFAULT NULL
)
RETURNS TABLE (
  organization_id uuid,
  warehouse_id uuid,
  catalog_item_id uuid,
  on_hand_qty numeric,
  on_order_qty numeric,
  next_eta date,
  import_lead_time_min_days integer,
  import_lead_time_max_days integer,
  risk_level text,
  is_special_order boolean,
  is_risk boolean,
  availability_type text
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    a.organization_id,
    a.warehouse_id,
    a.catalog_item_id,
    a.on_hand_qty,
    a.on_order_qty,
    a.next_eta,
    a.import_lead_time_min_days,
    a.import_lead_time_max_days,
    a.risk_level,
    a.is_special_order,
    a.is_risk,
    a.availability_type
  FROM public.inventory_availability a
  WHERE a.warehouse_id = p_warehouse_id
    AND (p_catalog_item_ids IS NULL OR a.catalog_item_id = ANY(p_catalog_item_ids));
$$;

COMMENT ON FUNCTION public.get_inventory_availability(uuid, uuid[]) IS
  'Returns availability for a warehouse (optional catalog_item_ids). STABLE. Informative only. RLS via base tables. Do not persist in QuoteLine.';
