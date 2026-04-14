-- Backfill SaleOrderLines from QuoteLines for SalesOrders that have quote_id but 0 lines.
SET search_path = public;

INSERT INTO "SaleOrderLines" (
  organization_id, sales_order_id, quote_line_id, catalog_item_id, configured_product_id, line_number,
  quantity, unit_price, line_total, description, product_type, product_type_id,
  collection_name, variant_name, hardware_color, width_m, height_m, sqm, area, "position"
)
SELECT
  so.organization_id,
  so.id,
  ql.id,
  ql.catalog_item_id,
  ql.configured_product_id,
  num.rn::integer,
  COALESCE(ql.quantity, 1),
  COALESCE(ql.unit_dealer_price_snapshot, ql.unit_msrp, 0),
  COALESCE(ql.dealer_price_total, (COALESCE(ql.quantity, 1) * COALESCE(ql.unit_dealer_price_snapshot, ql.unit_msrp, 0))),
  ql.name,
  ql.product_type,
  ql.product_type_id,
  ql.collection_name,
  ql.variant_name,
  ql.hardware_color,
  ql.width_m,
  ql.height_m,
  (COALESCE(ql.width_m, 0) * COALESCE(ql.height_m, 0)),
  ql.area,
  ql."position"
FROM "SalesOrders" so
JOIN (
  SELECT ql_inner.id, ql_inner.quote_id, ql_inner.catalog_item_id, ql_inner.configured_product_id,
         ql_inner.quantity, ql_inner.unit_dealer_price_snapshot, ql_inner.unit_msrp, ql_inner.dealer_price_total,
         ql_inner.name, ql_inner.product_type, ql_inner.product_type_id, ql_inner.collection_name,
         ql_inner.variant_name, ql_inner.hardware_color, ql_inner.width_m, ql_inner.height_m,
         ql_inner.area, ql_inner."position", ql_inner.sort_order, ql_inner.created_at,
         row_number() OVER (PARTITION BY ql_inner.quote_id ORDER BY ql_inner.sort_order ASC NULLS LAST, ql_inner.created_at ASC) AS rn
  FROM "QuoteLines" ql_inner
) ql ON ql.quote_id = so.quote_id
CROSS JOIN LATERAL (SELECT ql.rn AS rn) num
WHERE so.deleted = false
  AND so.quote_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM "SaleOrderLines" sol
    WHERE sol.sales_order_id = so.id AND sol.deleted = false
  );;
