-- Fix lead times and rewire inventory_availability view to use CatalogItemSupply
-- instead of the orphaned InventoryItemProfiles table.
-- Lead time rules: import = 45-60 days, local = 8-15 days.
-- Risk is now derived automatically from supply_origin + lead time.

BEGIN;

-- 1. Bulk-update lead times in CatalogItemSupply
UPDATE public."CatalogItemSupply"
SET lead_time_min_days = 45, lead_time_max_days = 60, updated_at = now()
WHERE supply_origin = 'import'
  AND (lead_time_min_days != 45 OR lead_time_max_days != 60);

UPDATE public."CatalogItemSupply"
SET lead_time_min_days = 8, lead_time_max_days = 15, updated_at = now()
WHERE supply_origin = 'local'
  AND (lead_time_min_days != 8 OR lead_time_max_days != 15);

-- 2. Drop dependent views
DROP VIEW IF EXISTS public.inventory_available CASCADE;
DROP VIEW IF EXISTS public.inventory_availability CASCADE;

-- 3. Recreate inventory_availability using CatalogItemSupply
CREATE OR REPLACE VIEW public.inventory_availability AS
WITH on_hand AS (
  SELECT organization_id, warehouse_id, catalog_item_id, on_hand_qty, updated_at
  FROM public.inventory_on_hand
),
on_order AS (
  SELECT organization_id, warehouse_id, catalog_item_id, on_order_qty, next_eta
  FROM public.inventory_on_order
),
items_base AS (
  SELECT
    COALESCE(h.organization_id, o.organization_id) AS organization_id,
    COALESCE(h.warehouse_id, o.warehouse_id) AS warehouse_id,
    COALESCE(h.catalog_item_id, o.catalog_item_id) AS catalog_item_id,
    h.on_hand_qty,
    h.updated_at AS h_updated_at,
    o.on_order_qty,
    o.next_eta
  FROM on_hand h
  FULL JOIN on_order o
    ON o.organization_id = h.organization_id
   AND o.warehouse_id = h.warehouse_id
   AND o.catalog_item_id = h.catalog_item_id
)
SELECT
  i.organization_id,
  i.warehouse_id,
  i.catalog_item_id,
  COALESCE(i.on_hand_qty, 0) AS on_hand_qty,
  COALESCE(i.on_order_qty, 0) AS on_order_qty,
  i.next_eta,
  CASE
    WHEN COALESCE(i.on_hand_qty, 0) > 0 THEN 'IN_STOCK'
    WHEN COALESCE(i.on_order_qty, 0) > 0 THEN 'ON_ORDER'
    ELSE 'OUT_OF_STOCK'
  END AS availability,
  CASE
    WHEN s.supply_origin = 'import' AND COALESCE(s.lead_time_min_days, 0) >= 30 THEN 'high'
    WHEN s.supply_origin = 'import' THEN 'medium'
    WHEN s.supply_type = 'order' THEN 'medium'
    ELSE 'low'
  END AS risk_level,
  (s.supply_origin = 'import' AND COALESCE(s.lead_time_min_days, 0) >= 30) AS is_risk,
  COALESCE(s.supply_type = 'order', false) AS is_special_order,
  s.lead_time_min_days AS import_lead_time_min_days,
  s.lead_time_max_days AS import_lead_time_max_days,
  NULL::uuid AS preferred_supplier_id,
  GREATEST(
    COALESCE(i.h_updated_at, '-infinity'::timestamptz),
    COALESCE(i.next_eta::timestamptz, '-infinity'::timestamptz),
    COALESCE(s.updated_at, '-infinity'::timestamptz)
  ) AS updated_at
FROM items_base i
LEFT JOIN public."CatalogItemSupply" s
  ON s.catalog_item_id = i.catalog_item_id
 AND s.organization_id = i.organization_id;

COMMENT ON VIEW public.inventory_availability IS
  'Availability view sourced from CatalogItemSupply for lead times and risk. '
  'risk_level derived: import >=30d lead = high, import <30d = medium, order-only = medium, else low. '
  'Do NOT persist in QuoteLine.';

-- 4. Recreate inventory_available (depends on inventory_availability)
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
 AND al.warehouse_id = a.warehouse_id
 AND al.catalog_item_id = a.catalog_item_id;

-- 5. Clean up orphan InventoryItemProfiles data
DELETE FROM public."InventoryItemProfiles";

COMMIT;
