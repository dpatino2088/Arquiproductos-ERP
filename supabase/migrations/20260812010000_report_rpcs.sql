-- Reports module: 5 read-only aggregation RPCs.
--
-- All server-side (GROUP BY in Postgres, small jsonb out) so the frontend never
-- downloads raw rows. SECURITY INVOKER: caller's RLS applies to every table.
-- Window convention: [p_from, p_to] inclusive dates (created_at < p_to + 1 day).
-- No pricing formula is touched — these read stored totals and snapshots only.

-- ============================================================================
-- 1) Sales summary: KPIs + monthly trend + status mix + conversion funnel
-- ============================================================================
CREATE OR REPLACE FUNCTION public.report_sales_summary(
  p_org_id uuid,
  p_from date,
  p_to date
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
WITH so AS (
  SELECT id, quote_id, total_amount, status::text AS status, created_at
  FROM "SalesOrders"
  WHERE organization_id = p_org_id
    AND deleted = false
    AND status::text <> 'cancelled'
    AND created_at >= p_from
    AND created_at < p_to + 1
),
q AS (
  -- Superseded quotes are old versions; counting them would inflate the funnel.
  SELECT id, total_amount, created_at
  FROM "Quotes"
  WHERE organization_id = p_org_id
    AND deleted = false
    AND COALESCE(archived, false) = false
    AND status::text <> 'superseded'
    AND created_at >= p_from
    AND created_at < p_to + 1
),
p AS (
  SELECT id, status::text AS status, created_at
  FROM "Proposals"
  WHERE organization_id = p_org_id
    AND deleted = false
    AND COALESCE(archived, false) = false
    AND created_at >= p_from
    AND created_at < p_to + 1
)
SELECT jsonb_build_object(
  'total_sales', COALESCE((SELECT round(sum(total_amount)::numeric, 2) FROM so), 0),
  'orders_count', (SELECT count(*) FROM so),
  'avg_ticket', COALESCE((SELECT round(avg(total_amount)::numeric, 2) FROM so), 0),
  'monthly', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('month', m, 'total', total, 'orders', orders) ORDER BY m)
    FROM (
      SELECT to_char(date_trunc('month', created_at), 'YYYY-MM') AS m,
             round(sum(total_amount)::numeric, 2) AS total,
             count(*) AS orders
      FROM so
      GROUP BY 1
    ) x
  ), '[]'::jsonb),
  'status_mix', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('status', status, 'count', c) ORDER BY c DESC)
    FROM (SELECT status, count(*) AS c FROM so GROUP BY status) x
  ), '[]'::jsonb),
  'funnel', jsonb_build_object(
    'quotes_created', (SELECT count(*) FROM q),
    'quotes_amount', COALESCE((SELECT round(sum(total_amount)::numeric, 2) FROM q), 0),
    'proposals_created', (SELECT count(*) FROM p),
    'proposals_accepted', (SELECT count(*) FROM p WHERE status = 'accepted'),
    'orders_created', (SELECT count(*) FROM so),
    'quote_to_order_pct', CASE
      WHEN (SELECT count(*) FROM q) = 0 THEN 0
      ELSE round((SELECT count(*) FROM so)::numeric * 100 / (SELECT count(*) FROM q), 1)
    END,
    'avg_cycle_days', COALESCE((
      SELECT round(avg(extract(epoch FROM (s.created_at - qq.created_at)) / 86400)::numeric, 1)
      FROM so s
      JOIN "Quotes" qq ON qq.id = s.quote_id
    ), 0)
  )
)
$$;

-- ============================================================================
-- 2) Dealer ranking: sales, orders, quotes, conversion and real margin
--    (cost from QuoteLines.unit_cost_total_snapshot via SaleOrderLines)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.report_dealer_ranking(
  p_org_id uuid,
  p_from date,
  p_to date
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
WITH so AS (
  SELECT id, dealer_id, total_amount
  FROM "SalesOrders"
  WHERE organization_id = p_org_id
    AND deleted = false
    AND status::text <> 'cancelled'
    AND created_at >= p_from
    AND created_at < p_to + 1
),
so_agg AS (
  SELECT dealer_id, count(*) AS orders_count, round(sum(total_amount)::numeric, 2) AS sales_total
  FROM so
  GROUP BY dealer_id
),
margin AS (
  SELECT so.dealer_id,
         round(sum(sol.line_total)::numeric, 2) AS revenue,
         round(sum(COALESCE(ql.unit_cost_total_snapshot, 0) * COALESCE(sol.quantity, 1))::numeric, 2) AS cost
  FROM so
  JOIN "SaleOrderLines" sol ON sol.sales_order_id = so.id AND sol.deleted = false
  LEFT JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
  GROUP BY so.dealer_id
),
q AS (
  SELECT dealer_id, count(*) AS quotes_count
  FROM "Quotes"
  WHERE organization_id = p_org_id
    AND deleted = false
    AND COALESCE(archived, false) = false
    AND status::text <> 'superseded'
    AND created_at >= p_from
    AND created_at < p_to + 1
  GROUP BY dealer_id
)
SELECT COALESCE(jsonb_agg(
  jsonb_build_object(
    'dealer_id', d.id,
    'dealer_name', COALESCE(d.dealer_name, '—'),
    'dealer_no', d.dealer_no,
    'orders_count', COALESCE(sa.orders_count, 0),
    'sales_total', COALESCE(sa.sales_total, 0),
    'quotes_count', COALESCE(q.quotes_count, 0),
    'conversion_pct', CASE
      WHEN COALESCE(q.quotes_count, 0) = 0 THEN NULL
      ELSE round(COALESCE(sa.orders_count, 0)::numeric * 100 / q.quotes_count, 1)
    END,
    'revenue', COALESCE(m.revenue, 0),
    'cost', COALESCE(m.cost, 0),
    'margin_pct', CASE
      WHEN COALESCE(m.revenue, 0) = 0 OR m.cost IS NULL OR m.cost = 0 THEN NULL
      ELSE round((m.revenue - m.cost) * 100 / m.revenue, 1)
    END
  )
  ORDER BY COALESCE(sa.sales_total, 0) DESC, COALESCE(q.quotes_count, 0) DESC
), '[]'::jsonb)
FROM "Dealers" d
LEFT JOIN so_agg sa ON sa.dealer_id = d.id
LEFT JOIN margin m ON m.dealer_id = d.id
LEFT JOIN q ON q.dealer_id = d.id
WHERE d.organization_id = p_org_id
  AND d.deleted = false
  AND (sa.dealer_id IS NOT NULL OR q.dealer_id IS NOT NULL)
$$;

-- ============================================================================
-- 3) Product mix: units & revenue by product type + top collections/fabrics
-- ============================================================================
CREATE OR REPLACE FUNCTION public.report_product_mix(
  p_org_id uuid,
  p_from date,
  p_to date
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
WITH sol AS (
  SELECT l.*
  FROM "SaleOrderLines" l
  JOIN "SalesOrders" o ON o.id = l.sales_order_id
  WHERE o.organization_id = p_org_id
    AND o.deleted = false
    AND o.status::text <> 'cancelled'
    AND o.created_at >= p_from
    AND o.created_at < p_to + 1
    AND l.deleted = false
)
SELECT jsonb_build_object(
  'by_product_type', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'product_type', pt_name,
      'units', units,
      'revenue', revenue,
      'avg_width_m', avg_w,
      'avg_height_m', avg_h
    ) ORDER BY revenue DESC)
    FROM (
      SELECT COALESCE(pt.name, sol.product_type, 'Other') AS pt_name,
             round(sum(COALESCE(sol.quantity, 1))::numeric, 0) AS units,
             round(sum(COALESCE(sol.line_total, 0))::numeric, 2) AS revenue,
             round(avg(NULLIF(sol.width_m, 0))::numeric, 2) AS avg_w,
             round(avg(NULLIF(sol.height_m, 0))::numeric, 2) AS avg_h
      FROM sol
      LEFT JOIN "ProductTypes" pt ON pt.id = sol.product_type_id
      GROUP BY 1
    ) x
  ), '[]'::jsonb),
  'top_collections', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'collection', collection,
      'variant', variant,
      'units', units,
      'revenue', revenue
    ) ORDER BY revenue DESC)
    FROM (
      SELECT sol.collection_name AS collection,
             sol.variant_name AS variant,
             round(sum(COALESCE(sol.quantity, 1))::numeric, 0) AS units,
             round(sum(COALESCE(sol.line_total, 0))::numeric, 2) AS revenue
      FROM sol
      WHERE COALESCE(sol.collection_name, '') <> ''
      GROUP BY 1, 2
      ORDER BY 4 DESC
      LIMIT 15
    ) x
  ), '[]'::jsonb)
)
$$;

-- ============================================================================
-- 4) Component consumption: motors/tubes/brackets used by sold orders
--    (BOMInstanceLines via BOMInstances.sales_order_line_id) + accessories
-- ============================================================================
CREATE OR REPLACE FUNCTION public.report_component_consumption(
  p_org_id uuid,
  p_from date,
  p_to date
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
WITH sol AS (
  SELECT l.id, l.quote_line_id, l.sales_order_id
  FROM "SaleOrderLines" l
  JOIN "SalesOrders" o ON o.id = l.sales_order_id
  WHERE o.organization_id = p_org_id
    AND o.deleted = false
    AND o.status::text <> 'cancelled'
    AND o.created_at >= p_from
    AND o.created_at < p_to + 1
    AND l.deleted = false
),
comp AS (
  SELECT bil.part_role,
         bil.catalog_item_id,
         max(bil.uom) AS uom,
         round(sum(COALESCE(bil.qty, 0))::numeric, 2) AS qty,
         round(sum(COALESCE(bil.total_cost_exw, 0))::numeric, 2) AS cost,
         count(DISTINCT sol.sales_order_id) AS orders_count
  FROM sol
  JOIN "BOMInstances" bi ON bi.sales_order_line_id = sol.id AND bi.deleted = false
  JOIN "BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
    AND bil.deleted = false
    AND COALESCE(bil.excluded, false) = false
  GROUP BY bil.part_role, bil.catalog_item_id
)
SELECT jsonb_build_object(
  'top_components', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'part_role', c.part_role,
      'sku', ci.sku,
      'name', ci.name,
      'uom', c.uom,
      'qty', c.qty,
      'cost', c.cost,
      'orders_count', c.orders_count
    ) ORDER BY c.cost DESC)
    FROM (SELECT * FROM comp ORDER BY cost DESC LIMIT 30) c
    LEFT JOIN "CatalogItems" ci ON ci.id = c.catalog_item_id
  ), '[]'::jsonb),
  'by_role', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('part_role', part_role, 'qty', qty, 'cost', cost) ORDER BY cost DESC)
    FROM (
      SELECT COALESCE(part_role, 'other') AS part_role,
             round(sum(qty)::numeric, 2) AS qty,
             round(sum(cost)::numeric, 2) AS cost
      FROM comp
      GROUP BY 1
    ) x
  ), '[]'::jsonb),
  'accessories', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'sku', sku,
      'name', name,
      'qty', qty,
      'orders_count', orders_count
    ) ORDER BY qty DESC)
    FROM (
      SELECT ci.sku,
             ci.name,
             round(sum(COALESCE(qlc.qty, 0))::numeric, 2) AS qty,
             count(DISTINCT sol.sales_order_id) AS orders_count
      FROM sol
      JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = sol.quote_line_id
        AND qlc.deleted = false
        AND COALESCE(qlc.archived, false) = false
      LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
      GROUP BY ci.sku, ci.name
      ORDER BY 3 DESC
      LIMIT 20
    ) x
  ), '[]'::jsonb)
)
$$;

-- ============================================================================
-- 5) Purchasing: spend by month / vendor, PO status mix, top purchased items
--    Spend = committed POs (OPEN + CLOSED); DRAFT and CANCELLED excluded.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.report_purchasing(
  p_org_id uuid,
  p_from date,
  p_to date
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
WITH po AS (
  SELECT id, vendor_id, status::text AS status, total, created_at
  FROM "PurchaseOrders"
  WHERE organization_id = p_org_id
    AND created_at >= p_from
    AND created_at < p_to + 1
),
act AS (
  SELECT * FROM po WHERE status NOT IN ('CANCELLED', 'DRAFT')
)
SELECT jsonb_build_object(
  'total_spend', COALESCE((SELECT round(sum(total)::numeric, 2) FROM act), 0),
  'po_count', (SELECT count(*) FROM act),
  'monthly', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('month', m, 'total', total, 'pos', pos) ORDER BY m)
    FROM (
      SELECT to_char(date_trunc('month', created_at), 'YYYY-MM') AS m,
             round(sum(COALESCE(total, 0))::numeric, 2) AS total,
             count(*) AS pos
      FROM act
      GROUP BY 1
    ) x
  ), '[]'::jsonb),
  'status_mix', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('status', status, 'count', c) ORDER BY c DESC)
    FROM (SELECT status, count(*) AS c FROM po GROUP BY status) x
  ), '[]'::jsonb),
  'by_vendor', COALESCE((
    SELECT jsonb_agg(jsonb_build_object('vendor', vendor, 'total', total, 'pos', pos) ORDER BY total DESC)
    FROM (
      SELECT COALESCE(v.vendor_name, v.name, '—') AS vendor,
             round(sum(COALESCE(act.total, 0))::numeric, 2) AS total,
             count(*) AS pos
      FROM act
      LEFT JOIN "DirectoryVendors" v ON v.id = act.vendor_id
      GROUP BY 1
      ORDER BY 2 DESC
      LIMIT 15
    ) x
  ), '[]'::jsonb),
  'top_items', COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'sku', sku,
      'name', name,
      'qty', qty,
      'unit', unit,
      'spend', spend
    ) ORDER BY spend DESC)
    FROM (
      SELECT COALESCE(ci.sku, pol.sku_snapshot, '—') AS sku,
             COALESCE(ci.name, pol.item_name_snapshot, pol.description) AS name,
             round(sum(COALESCE(pol.ordered_qty, 0))::numeric, 2) AS qty,
             max(pol.unit) AS unit,
             round(sum(COALESCE(pol.line_total, 0))::numeric, 2) AS spend
      FROM act
      JOIN "PurchaseOrderLines" pol ON pol.purchase_order_id = act.id
      LEFT JOIN "CatalogItems" ci ON ci.id = pol.catalog_item_id
      GROUP BY 1, 2
      ORDER BY 5 DESC
      LIMIT 20
    ) x
  ), '[]'::jsonb)
)
$$;

COMMENT ON FUNCTION public.report_sales_summary(uuid, date, date) IS 'Reports: sales KPIs, monthly trend, status mix and quote→proposal→order funnel.';
COMMENT ON FUNCTION public.report_dealer_ranking(uuid, date, date) IS 'Reports: per-dealer sales, quotes, conversion and margin (from stored snapshots).';
COMMENT ON FUNCTION public.report_product_mix(uuid, date, date) IS 'Reports: units/revenue by product type and top collections.';
COMMENT ON FUNCTION public.report_component_consumption(uuid, date, date) IS 'Reports: component consumption (BOMInstanceLines) and accessories for sold orders.';
COMMENT ON FUNCTION public.report_purchasing(uuid, date, date) IS 'Reports: purchasing spend by month/vendor, PO status mix, top purchased items.';
