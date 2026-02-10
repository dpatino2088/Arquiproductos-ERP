-- =====================================================
-- Adaptio Inventory Availability — Fase 2: Vistas
-- =====================================================
-- inventory_on_hand: stock real (from InventoryBalances)
-- inventory_on_order: PO – receipts (OPEN/PARTIAL), next_eta = MIN(expected_date)
-- inventory_availability: combines on_hand + on_order + profiles (informative)
-- =====================================================

SET search_path = public;

-- Vista: stock on hand por organization, warehouse, catalog_item
CREATE OR REPLACE VIEW public.inventory_on_hand AS
SELECT
  b.organization_id,
  b.warehouse_id,
  b.catalog_item_id,
  b.quantity AS on_hand_qty,
  b.updated_at
FROM "public"."InventoryBalances" b;

COMMENT ON VIEW public.inventory_on_hand IS 'Stock on hand per org/warehouse/catalog_item. Source: InventoryBalances.';

-- Vista: on order (ordered - received) por material + warehouse. El cálculo manda: (ordered_qty - received_qty) > 0.
-- status OPEN/PARTIAL es coherente con eso; next_eta solo usa expected_date no nulos.
CREATE OR REPLACE VIEW public.inventory_on_order AS
SELECT
  po.organization_id,
  po.warehouse_id,
  pol.catalog_item_id,
  SUM(pol.ordered_qty - pol.received_qty) AS on_order_qty,
  MIN(po.expected_date) FILTER (WHERE po.expected_date IS NOT NULL) AS next_eta
FROM "public"."PurchaseOrders" po
JOIN "public"."PurchaseOrderLines" pol ON pol.purchase_order_id = po.id
WHERE po.status IN ('OPEN', 'PARTIAL')
  AND (pol.ordered_qty - pol.received_qty) > 0
GROUP BY po.organization_id, po.warehouse_id, pol.catalog_item_id;

COMMENT ON VIEW public.inventory_on_order IS 'On order = (ordered_qty - received_qty) > 0; status supportive. next_eta = MIN(expected_date) only over non-null dates.';

-- Vista: availability combinada (on_hand + on_order + profiles)
-- availability_type = estado principal (IN_STOCK | IN_TRANSIT | IMPORT | UNKNOWN). is_risk = modificador (no reemplaza la realidad).
CREATE OR REPLACE VIEW public.inventory_availability AS
WITH on_hand AS (
  SELECT organization_id, warehouse_id, catalog_item_id, on_hand_qty
  FROM public.inventory_on_hand
),
on_order AS (
  SELECT organization_id, warehouse_id, catalog_item_id, on_order_qty, next_eta
  FROM public.inventory_on_order
),
profiles AS (
  SELECT catalog_item_id, warehouse_id,
    import_lead_time_min_days,
    import_lead_time_max_days,
    risk_level,
    is_special_order
  FROM "public"."InventoryItemProfiles"
),
-- Base: todos los ítems que tienen perfil O que tienen on_hand u on_order
items_with_activity AS (
  SELECT DISTINCT organization_id, warehouse_id, catalog_item_id
  FROM (
    SELECT organization_id, warehouse_id, catalog_item_id FROM on_hand
    UNION
    SELECT organization_id, warehouse_id, catalog_item_id FROM on_order
    UNION
    SELECT w.organization_id, p.warehouse_id, p.catalog_item_id
    FROM profiles p
    JOIN "public"."Warehouses" w ON w.id = p.warehouse_id
  ) u
)
SELECT
  i.organization_id,
  i.warehouse_id,
  i.catalog_item_id,
  COALESCE(h.on_hand_qty, 0) AS on_hand_qty,
  COALESCE(o.on_order_qty, 0) AS on_order_qty,
  o.next_eta,
  p.import_lead_time_min_days,
  p.import_lead_time_max_days,
  p.risk_level,
  COALESCE(p.is_special_order, false) AS is_special_order,
  (p.risk_level IN ('high', 'critical')) AS is_risk,
  CASE
    WHEN COALESCE(h.on_hand_qty, 0) > 0 THEN 'IN_STOCK'
    WHEN COALESCE(o.on_order_qty, 0) > 0 THEN 'IN_TRANSIT'
    WHEN p.is_special_order OR (p.import_lead_time_min_days IS NOT NULL OR p.import_lead_time_max_days IS NOT NULL) THEN 'IMPORT'
    ELSE 'UNKNOWN'
  END AS availability_type
FROM items_with_activity i
LEFT JOIN on_hand h ON h.organization_id = i.organization_id AND h.warehouse_id = i.warehouse_id AND h.catalog_item_id = i.catalog_item_id
LEFT JOIN on_order o ON o.organization_id = i.organization_id AND o.warehouse_id = i.warehouse_id AND o.catalog_item_id = i.catalog_item_id
LEFT JOIN profiles p ON p.catalog_item_id = i.catalog_item_id AND p.warehouse_id = i.warehouse_id;

COMMENT ON VIEW public.inventory_availability IS 'Informative. availability_type = principal (IN_STOCK|IN_TRANSIT|IMPORT|UNKNOWN). is_risk = modifier. Do NOT persist in QuoteLine.';
