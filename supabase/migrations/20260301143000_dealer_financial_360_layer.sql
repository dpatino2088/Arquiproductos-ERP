SET search_path = public;

-- ----------------------------------------------------
-- Dealer Financial 360 Layer (DB-first)
-- ----------------------------------------------------
-- This migration creates reusable views for:
-- - Dealer AR summary
-- - Dealer AR aging buckets
-- - Dealer financial timeline
-- - Integrity checks for applied amounts
-- ----------------------------------------------------

-- Helpful indexes for financial lookups
CREATE INDEX IF NOT EXISTS idx_dealer_invoices_org_dealer_deleted
  ON public."DealerInvoices" (organization_id, dealer_id, deleted);

CREATE INDEX IF NOT EXISTS idx_dealer_invoices_org_due_date
  ON public."DealerInvoices" (organization_id, due_date)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_dealer_invoices_org_issue_date
  ON public."DealerInvoices" (organization_id, issue_date)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_payments_org_dealer_deleted
  ON public."Payments" (organization_id, dealer_id, deleted);

CREATE INDEX IF NOT EXISTS idx_payments_org_payment_date
  ON public."Payments" (organization_id, payment_date)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_payment_applications_payment_id
  ON public."PaymentApplications" (payment_id);

CREATE INDEX IF NOT EXISTS idx_payment_applications_invoice_id
  ON public."PaymentApplications" (invoice_id);

-- Base helper: invoice balances derived from applications
CREATE OR REPLACE VIEW public.dealer_invoice_balances_v1 AS
WITH applied_by_invoice AS (
  SELECT
    pa.invoice_id,
    SUM(COALESCE(pa.applied_amount, 0))::numeric(14,2) AS applied_total
  FROM public."PaymentApplications" pa
  GROUP BY pa.invoice_id
)
SELECT
  inv.id AS invoice_id,
  inv.organization_id,
  inv.dealer_id,
  inv.sales_order_id,
  inv.invoice_number,
  inv.status AS invoice_status,
  inv.issue_date,
  inv.due_date,
  COALESCE(inv.total, 0)::numeric(14,2) AS invoice_total,
  COALESCE(app.applied_total, 0)::numeric(14,2) AS applied_total,
  GREATEST(COALESCE(inv.total, 0) - COALESCE(app.applied_total, 0), 0)::numeric(14,2) AS balance_due,
  (COALESCE(inv.total, 0) - COALESCE(app.applied_total, 0) > 0.005) AS is_open,
  (
    COALESCE(inv.total, 0) - COALESCE(app.applied_total, 0) > 0.005
    AND inv.due_date IS NOT NULL
    AND inv.due_date < CURRENT_DATE
  ) AS is_past_due
FROM public."DealerInvoices" inv
LEFT JOIN applied_by_invoice app ON app.invoice_id = inv.id
WHERE inv.deleted = false
  AND inv.organization_id IS NOT NULL
  AND inv.dealer_id IS NOT NULL;

-- Main summary per organization + dealer
CREATE OR REPLACE VIEW public.dealer_financial_summary_v1 AS
WITH invoice_agg AS (
  SELECT
    b.organization_id,
    b.dealer_id,
    SUM(b.invoice_total)::numeric(14,2) AS total_invoiced_lifetime,
    SUM(b.applied_total)::numeric(14,2) AS total_paid_on_invoices_lifetime,
    SUM(b.balance_due)::numeric(14,2) AS open_ar,
    SUM(CASE WHEN b.is_past_due THEN b.balance_due ELSE 0 END)::numeric(14,2) AS past_due_amount,
    COUNT(*) FILTER (WHERE b.is_open)::integer AS open_invoices_count
  FROM public.dealer_invoice_balances_v1 b
  WHERE b.invoice_status <> 'void'
  GROUP BY b.organization_id, b.dealer_id
),
payment_agg AS (
  SELECT
    p.organization_id,
    p.dealer_id,
    SUM(COALESCE(p.amount, 0))::numeric(14,2) AS total_payments_recorded_lifetime,
    MAX(p.payment_date) AS last_payment_date
  FROM public."Payments" p
  WHERE p.deleted = false
    AND p.organization_id IS NOT NULL
    AND p.dealer_id IS NOT NULL
  GROUP BY p.organization_id, p.dealer_id
),
sales_order_agg AS (
  SELECT
    so.organization_id,
    so.dealer_id,
    COUNT(*) FILTER (
      WHERE COALESCE(so.deleted, false) = false
        AND COALESCE(so.status, 'draft') NOT IN ('cancelled', 'closed')
    )::integer AS open_so_count
  FROM public."SalesOrders" so
  WHERE so.organization_id IS NOT NULL
    AND so.dealer_id IS NOT NULL
  GROUP BY so.organization_id, so.dealer_id
),
dealer_keys AS (
  SELECT d.organization_id, d.id AS dealer_id
  FROM public."Dealers" d
  WHERE d.deleted = false
)
SELECT
  dk.organization_id,
  dk.dealer_id,
  COALESCE(ia.total_invoiced_lifetime, 0)::numeric(14,2) AS total_invoiced_lifetime,
  COALESCE(pa.total_payments_recorded_lifetime, 0)::numeric(14,2) AS total_paid_lifetime,
  COALESCE(ia.open_ar, 0)::numeric(14,2) AS open_ar,
  COALESCE(ia.past_due_amount, 0)::numeric(14,2) AS past_due_amount,
  GREATEST(COALESCE(pa.total_payments_recorded_lifetime, 0) - COALESCE(ia.total_paid_on_invoices_lifetime, 0), 0)::numeric(14,2) AS unapplied_amount,
  pa.last_payment_date,
  COALESCE(ia.open_invoices_count, 0)::integer AS open_invoices_count,
  COALESCE(sa.open_so_count, 0)::integer AS open_so_count,
  NOW() AS computed_at
FROM dealer_keys dk
LEFT JOIN invoice_agg ia
  ON ia.organization_id = dk.organization_id
 AND ia.dealer_id = dk.dealer_id
LEFT JOIN payment_agg pa
  ON pa.organization_id = dk.organization_id
 AND pa.dealer_id = dk.dealer_id
LEFT JOIN sales_order_agg sa
  ON sa.organization_id = dk.organization_id
 AND sa.dealer_id = dk.dealer_id;

-- AR aging buckets by dealer
CREATE OR REPLACE VIEW public.dealer_ar_aging_v1 AS
WITH open_inv AS (
  SELECT
    b.organization_id,
    b.dealer_id,
    b.balance_due,
    b.due_date,
    GREATEST(CURRENT_DATE - COALESCE(b.due_date, CURRENT_DATE), 0) AS days_overdue
  FROM public.dealer_invoice_balances_v1 b
  WHERE b.invoice_status <> 'void'
    AND b.is_open = true
)
SELECT
  organization_id,
  dealer_id,
  SUM(CASE WHEN due_date IS NULL OR days_overdue = 0 THEN balance_due ELSE 0 END)::numeric(14,2) AS current,
  SUM(CASE WHEN days_overdue BETWEEN 1 AND 30 THEN balance_due ELSE 0 END)::numeric(14,2) AS days_1_30,
  SUM(CASE WHEN days_overdue BETWEEN 31 AND 60 THEN balance_due ELSE 0 END)::numeric(14,2) AS days_31_60,
  SUM(CASE WHEN days_overdue BETWEEN 61 AND 90 THEN balance_due ELSE 0 END)::numeric(14,2) AS days_61_90,
  SUM(CASE WHEN days_overdue > 90 THEN balance_due ELSE 0 END)::numeric(14,2) AS days_90_plus
FROM open_inv
GROUP BY organization_id, dealer_id;

-- Normalized financial timeline per dealer
CREATE OR REPLACE VIEW public.dealer_financial_timeline_v1 AS
WITH so_events AS (
  SELECT
    so.organization_id,
    so.dealer_id,
    so.id AS entity_id,
    'sales_order'::text AS entity_type,
    'sales_order_created'::text AS event_type,
    so.created_at AS event_at,
    so.sales_order_no AS reference_no,
    COALESCE(so.total_amount, 0)::numeric(14,2) AS amount
  FROM public."SalesOrders" so
  WHERE COALESCE(so.deleted, false) = false
    AND so.organization_id IS NOT NULL
    AND so.dealer_id IS NOT NULL
),
invoice_events AS (
  SELECT
    inv.organization_id,
    inv.dealer_id,
    inv.id AS entity_id,
    'invoice'::text AS entity_type,
    CASE
      WHEN inv.status = 'paid' THEN 'invoice_paid'
      WHEN inv.status = 'void' THEN 'invoice_voided'
      WHEN inv.status = 'issued' THEN 'invoice_issued'
      WHEN inv.status = 'partial' THEN 'invoice_partially_paid'
      ELSE 'invoice_created'
    END AS event_type,
    COALESCE(inv.issue_date::timestamptz, inv.created_at) AS event_at,
    inv.invoice_number AS reference_no,
    COALESCE(inv.total, 0)::numeric(14,2) AS amount
  FROM public."DealerInvoices" inv
  WHERE inv.deleted = false
    AND inv.organization_id IS NOT NULL
    AND inv.dealer_id IS NOT NULL
),
payment_events AS (
  SELECT
    p.organization_id,
    p.dealer_id,
    p.id AS entity_id,
    'payment'::text AS entity_type,
    'payment_recorded'::text AS event_type,
    COALESCE(p.payment_date::timestamptz, p.created_at) AS event_at,
    COALESCE(p.reference_number, p.id::text) AS reference_no,
    COALESCE(p.amount, 0)::numeric(14,2) AS amount
  FROM public."Payments" p
  WHERE p.deleted = false
    AND p.organization_id IS NOT NULL
    AND p.dealer_id IS NOT NULL
),
application_events AS (
  SELECT
    p.organization_id,
    p.dealer_id,
    pa.id AS entity_id,
    'payment_application'::text AS entity_type,
    'payment_applied'::text AS event_type,
    pa.created_at AS event_at,
    inv.invoice_number AS reference_no,
    COALESCE(pa.applied_amount, 0)::numeric(14,2) AS amount
  FROM public."PaymentApplications" pa
  JOIN public."Payments" p ON p.id = pa.payment_id
  LEFT JOIN public."DealerInvoices" inv ON inv.id = pa.invoice_id
  WHERE p.deleted = false
    AND p.organization_id IS NOT NULL
    AND p.dealer_id IS NOT NULL
)
SELECT * FROM so_events
UNION ALL
SELECT * FROM invoice_events
UNION ALL
SELECT * FROM payment_events
UNION ALL
SELECT * FROM application_events;

-- Integrity checks (validation layer for observability)
-- overapplied_invoice_count > 0 indicates data issues to be corrected.
CREATE OR REPLACE VIEW public.dealer_financial_integrity_v1 AS
WITH invoice_totals AS (
  SELECT
    inv.organization_id,
    inv.dealer_id,
    inv.id AS invoice_id,
    COALESCE(inv.total, 0)::numeric(14,2) AS invoice_total,
    COALESCE(SUM(pa.applied_amount), 0)::numeric(14,2) AS applied_total
  FROM public."DealerInvoices" inv
  LEFT JOIN public."PaymentApplications" pa ON pa.invoice_id = inv.id
  WHERE inv.deleted = false
    AND inv.organization_id IS NOT NULL
    AND inv.dealer_id IS NOT NULL
  GROUP BY inv.organization_id, inv.dealer_id, inv.id, inv.total
),
payment_totals AS (
  SELECT
    p.organization_id,
    p.dealer_id,
    p.id AS payment_id,
    COALESCE(p.amount, 0)::numeric(14,2) AS payment_total,
    COALESCE(SUM(pa.applied_amount), 0)::numeric(14,2) AS applied_total
  FROM public."Payments" p
  LEFT JOIN public."PaymentApplications" pa ON pa.payment_id = p.id
  WHERE p.deleted = false
    AND p.organization_id IS NOT NULL
    AND p.dealer_id IS NOT NULL
  GROUP BY p.organization_id, p.dealer_id, p.id, p.amount
)
SELECT
  d.organization_id,
  d.id AS dealer_id,
  COUNT(*) FILTER (WHERE it.applied_total > it.invoice_total + 0.005)::integer AS overapplied_invoice_count,
  COUNT(*) FILTER (WHERE pt.applied_total > pt.payment_total + 0.005)::integer AS overallocated_payment_count,
  NOW() AS checked_at
FROM public."Dealers" d
LEFT JOIN invoice_totals it
  ON it.organization_id = d.organization_id
 AND it.dealer_id = d.id
LEFT JOIN payment_totals pt
  ON pt.organization_id = d.organization_id
 AND pt.dealer_id = d.id
WHERE d.deleted = false
GROUP BY d.organization_id, d.id;
