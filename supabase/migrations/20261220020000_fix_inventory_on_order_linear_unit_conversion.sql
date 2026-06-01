-- Fix inventory_on_order: convert vendor linear units (yd/ft/in) to internal meters
-- so a PO line in yards/feet contributes the correct meters to "on order".
-- Previously only 'roll' (x roll_length) and packaging (x uppu) were converted;
-- yd/ft fell into ELSE -> x1, counting 14 yd as 14 m.
CREATE OR REPLACE VIEW public.inventory_on_order AS
 SELECT po.organization_id,
    po.warehouse_id,
    pol.catalog_item_id,
    sum(GREATEST(pol.ordered_qty - pol.received_qty, 0::numeric) *
        CASE
            WHEN lower(pol.unit) = 'roll'::text THEN COALESCE(ci.roll_length_m, 1::numeric)
            WHEN lower(pol.unit) IN ('yd','yard','yards') THEN 0.9144
            WHEN lower(pol.unit) IN ('ft','foot','feet') THEN 0.3048
            WHEN lower(pol.unit) IN ('in','inch','inches') THEN 0.0254
            WHEN COALESCE(ci.units_per_purchase_unit, 1::numeric) > 1::numeric AND (lower(pol.unit) <> ALL (ARRAY['each'::text, 'ea'::text, 'ft'::text, 'm'::text, 'yd'::text, 'm2'::text, 'yd2'::text, 'roll'::text])) THEN ci.units_per_purchase_unit
            ELSE 1::numeric
        END) AS on_order_qty,
    min(po.expected_date) FILTER (WHERE po.expected_date IS NOT NULL) AS next_eta
   FROM "PurchaseOrders" po
     JOIN "PurchaseOrderLines" pol ON pol.purchase_order_id = po.id
     LEFT JOIN "CatalogItems" ci ON ci.id = pol.catalog_item_id
  WHERE (po.status = ANY (ARRAY['OPEN'::purchase_order_status, 'PARTIAL'::purchase_order_status])) AND (pol.ordered_qty - pol.received_qty) > 0::numeric
  GROUP BY po.organization_id, po.warehouse_id, pol.catalog_item_id;
