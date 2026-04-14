SET search_path = public;

CREATE TABLE IF NOT EXISTS public."DealerCreditNotes" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  dealer_id uuid NOT NULL,
  invoice_id uuid NOT NULL,
  credit_note_number text NOT NULL,
  issue_date date NOT NULL DEFAULT CURRENT_DATE,
  amount numeric(14,2) NOT NULL CHECK (amount > 0),
  reason text NULL,
  status text NOT NULL DEFAULT 'issued',
  deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dealer_credit_notes_org_dealer_deleted
  ON public."DealerCreditNotes" (organization_id, dealer_id, deleted);

CREATE INDEX IF NOT EXISTS idx_dealer_credit_notes_invoice_deleted
  ON public."DealerCreditNotes" (invoice_id, deleted);

CREATE UNIQUE INDEX IF NOT EXISTS ux_dealer_credit_notes_org_number
  ON public."DealerCreditNotes" (organization_id, credit_note_number)
  WHERE deleted = false;

CREATE OR REPLACE VIEW public.dealer_invoice_balances_v1 AS
WITH applied_by_invoice AS (
  SELECT
    pa.invoice_id,
    SUM(COALESCE(pa.applied_amount, 0))::numeric(14,2) AS applied_total
  FROM public."PaymentApplications" pa
  GROUP BY pa.invoice_id
),
credited_by_invoice AS (
  SELECT
    cn.invoice_id,
    SUM(COALESCE(cn.amount, 0))::numeric(14,2) AS credited_total
  FROM public."DealerCreditNotes" cn
  WHERE cn.deleted = false
    AND cn.status <> 'void'
  GROUP BY cn.invoice_id
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
  GREATEST(COALESCE(inv.total, 0) - COALESCE(app.applied_total, 0) - COALESCE(cr.credited_total, 0), 0)::numeric(14,2) AS balance_due,
  (COALESCE(inv.total, 0) - COALESCE(app.applied_total, 0) - COALESCE(cr.credited_total, 0) > 0.005) AS is_open,
  (
    COALESCE(inv.total, 0) - COALESCE(app.applied_total, 0) - COALESCE(cr.credited_total, 0) > 0.005
    AND inv.due_date IS NOT NULL
    AND inv.due_date < CURRENT_DATE
  ) AS is_past_due,
  COALESCE(cr.credited_total, 0)::numeric(14,2) AS credited_total
FROM public."DealerInvoices" inv
LEFT JOIN applied_by_invoice app ON app.invoice_id = inv.id
LEFT JOIN credited_by_invoice cr ON cr.invoice_id = inv.id
WHERE inv.deleted = false
  AND inv.organization_id IS NOT NULL
  AND inv.dealer_id IS NOT NULL;

CREATE OR REPLACE VIEW public.dealer_financial_summary_v1 AS
WITH invoice_agg AS (
  SELECT
    b.organization_id,
    b.dealer_id,
    SUM(b.invoice_total)::numeric(14,2) AS total_invoiced_lifetime,
    SUM(b.applied_total)::numeric(14,2) AS total_paid_on_invoices_lifetime,
    SUM(b.credited_total)::numeric(14,2) AS total_credited_lifetime,
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
credit_events AS (
  SELECT
    cn.organization_id,
    cn.dealer_id,
    cn.id AS entity_id,
    'credit_note'::text AS entity_type,
    CASE
      WHEN cn.status = 'void' THEN 'credit_note_voided'
      ELSE 'credit_note_created'
    END AS event_type,
    COALESCE(cn.issue_date::timestamptz, cn.created_at) AS event_at,
    cn.credit_note_number AS reference_no,
    COALESCE(cn.amount, 0)::numeric(14,2) AS amount
  FROM public."DealerCreditNotes" cn
  WHERE cn.deleted = false
    AND cn.organization_id IS NOT NULL
    AND cn.dealer_id IS NOT NULL
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
SELECT * FROM credit_events
UNION ALL
SELECT * FROM payment_events
UNION ALL
SELECT * FROM application_events;;
