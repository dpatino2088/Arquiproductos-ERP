SET search_path = public;

-- ============================================================
-- Accounts Payable (AP) Module
-- Tables, indexes, RLS, and financial views
-- ============================================================

-- -------------------- VendorBills --------------------
CREATE TABLE IF NOT EXISTS public."VendorBills" (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  uuid NOT NULL,
  vendor_id        uuid NOT NULL REFERENCES public."DirectoryVendors"(id),
  purchase_order_id uuid NULL REFERENCES public."PurchaseOrders"(id),
  bill_number      text NOT NULL,
  vendor_bill_ref  text NULL,
  status           text NOT NULL DEFAULT 'draft',
  bill_date        date NOT NULL DEFAULT CURRENT_DATE,
  due_date         date NULL,
  currency_code    text NOT NULL DEFAULT 'USD',
  subtotal         numeric(14,2) NOT NULL DEFAULT 0,
  tax_total        numeric(14,2) NOT NULL DEFAULT 0,
  total            numeric(14,2) NOT NULL DEFAULT 0,
  notes            text NULL,
  void_reason      text NULL,
  voided_by        uuid NULL,
  voided_at        timestamptz NULL,
  deleted          boolean NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT NOW(),
  updated_at       timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vendor_bills_org_vendor_deleted
  ON public."VendorBills" (organization_id, vendor_id, deleted);

CREATE INDEX IF NOT EXISTS idx_vendor_bills_org_due_date
  ON public."VendorBills" (organization_id, due_date)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_vendor_bills_org_bill_date
  ON public."VendorBills" (organization_id, bill_date)
  WHERE deleted = false;

CREATE INDEX IF NOT EXISTS idx_vendor_bills_po
  ON public."VendorBills" (purchase_order_id)
  WHERE purchase_order_id IS NOT NULL AND deleted = false;

CREATE UNIQUE INDEX IF NOT EXISTS ux_vendor_bills_org_number
  ON public."VendorBills" (organization_id, bill_number)
  WHERE deleted = false;

ALTER TABLE public."VendorBills" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "vendor_bills_select_org" ON public."VendorBills";
CREATE POLICY "vendor_bills_select_org" ON public."VendorBills"
  FOR SELECT TO authenticated
  USING (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "vendor_bills_insert_org" ON public."VendorBills";
CREATE POLICY "vendor_bills_insert_org" ON public."VendorBills"
  FOR INSERT TO authenticated
  WITH CHECK (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "vendor_bills_update_org" ON public."VendorBills";
CREATE POLICY "vendor_bills_update_org" ON public."VendorBills"
  FOR UPDATE TO authenticated
  USING (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "vendor_bills_delete_org" ON public."VendorBills";
CREATE POLICY "vendor_bills_delete_org" ON public."VendorBills"
  FOR DELETE TO authenticated
  USING (public.is_org_user_member_strict(organization_id));

-- -------------------- VendorBillLines --------------------
CREATE TABLE IF NOT EXISTS public."VendorBillLines" (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bill_id                uuid NOT NULL REFERENCES public."VendorBills"(id) ON DELETE CASCADE,
  catalog_item_id        uuid NULL REFERENCES public."CatalogItems"(id),
  purchase_order_line_id uuid NULL REFERENCES public."PurchaseOrderLines"(id),
  sort_order             integer NOT NULL DEFAULT 0,
  description            text NULL,
  qty                    numeric(12,4) NOT NULL DEFAULT 1,
  unit_cost              numeric(14,4) NOT NULL DEFAULT 0,
  tax_pct                numeric(5,2) NOT NULL DEFAULT 0,
  line_subtotal          numeric(14,2) NOT NULL DEFAULT 0,
  line_tax               numeric(14,2) NOT NULL DEFAULT 0,
  line_total             numeric(14,2) NOT NULL DEFAULT 0,
  created_at             timestamptz NOT NULL DEFAULT NOW(),
  updated_at             timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vendor_bill_lines_bill
  ON public."VendorBillLines" (bill_id);

CREATE INDEX IF NOT EXISTS idx_vendor_bill_lines_po_line
  ON public."VendorBillLines" (purchase_order_line_id)
  WHERE purchase_order_line_id IS NOT NULL;

ALTER TABLE public."VendorBillLines" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "vendor_bill_lines_select_via_bill" ON public."VendorBillLines";
CREATE POLICY "vendor_bill_lines_select_via_bill" ON public."VendorBillLines"
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."VendorBills" vb
      WHERE vb.id = bill_id
        AND public.is_org_user_member_strict(vb.organization_id)
    )
  );

DROP POLICY IF EXISTS "vendor_bill_lines_insert_via_bill" ON public."VendorBillLines";
CREATE POLICY "vendor_bill_lines_insert_via_bill" ON public."VendorBillLines"
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."VendorBills" vb
      WHERE vb.id = bill_id
        AND public.is_org_user_member_strict(vb.organization_id)
    )
  );

DROP POLICY IF EXISTS "vendor_bill_lines_update_via_bill" ON public."VendorBillLines";
CREATE POLICY "vendor_bill_lines_update_via_bill" ON public."VendorBillLines"
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."VendorBills" vb
      WHERE vb.id = bill_id
        AND public.is_org_user_member_strict(vb.organization_id)
    )
  );

DROP POLICY IF EXISTS "vendor_bill_lines_delete_via_bill" ON public."VendorBillLines";
CREATE POLICY "vendor_bill_lines_delete_via_bill" ON public."VendorBillLines"
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."VendorBills" vb
      WHERE vb.id = bill_id
        AND public.is_org_user_member_strict(vb.organization_id)
    )
  );

-- -------------------- VendorPayments --------------------
CREATE TABLE IF NOT EXISTS public."VendorPayments" (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  uuid NOT NULL,
  vendor_id        uuid NOT NULL REFERENCES public."DirectoryVendors"(id),
  amount           numeric(14,2) NOT NULL CHECK (amount > 0),
  payment_method   text NULL,
  reference_number text NULL,
  bank_name        text NULL,
  payment_date     date NOT NULL DEFAULT CURRENT_DATE,
  description      text NULL,
  notes            text NULL,
  recorded_by      uuid NULL,
  recorded_by_name text NULL,
  status           text NOT NULL DEFAULT 'active',
  void_reason      text NULL,
  voided_by        uuid NULL,
  voided_at        timestamptz NULL,
  deleted          boolean NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT NOW(),
  updated_at       timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vendor_payments_org_vendor_deleted
  ON public."VendorPayments" (organization_id, vendor_id, deleted);

CREATE INDEX IF NOT EXISTS idx_vendor_payments_org_date
  ON public."VendorPayments" (organization_id, payment_date)
  WHERE deleted = false;

ALTER TABLE public."VendorPayments" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "vendor_payments_select_org" ON public."VendorPayments";
CREATE POLICY "vendor_payments_select_org" ON public."VendorPayments"
  FOR SELECT TO authenticated
  USING (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "vendor_payments_insert_org" ON public."VendorPayments";
CREATE POLICY "vendor_payments_insert_org" ON public."VendorPayments"
  FOR INSERT TO authenticated
  WITH CHECK (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "vendor_payments_update_org" ON public."VendorPayments";
CREATE POLICY "vendor_payments_update_org" ON public."VendorPayments"
  FOR UPDATE TO authenticated
  USING (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "vendor_payments_delete_org" ON public."VendorPayments";
CREATE POLICY "vendor_payments_delete_org" ON public."VendorPayments"
  FOR DELETE TO authenticated
  USING (public.is_org_user_member_strict(organization_id));

-- -------------------- VendorPaymentApplications --------------------
CREATE TABLE IF NOT EXISTS public."VendorPaymentApplications" (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_payment_id  uuid NOT NULL REFERENCES public."VendorPayments"(id) ON DELETE CASCADE,
  bill_id            uuid NOT NULL REFERENCES public."VendorBills"(id),
  applied_amount     numeric(14,2) NOT NULL CHECK (applied_amount > 0),
  created_at         timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vendor_payment_apps_payment
  ON public."VendorPaymentApplications" (vendor_payment_id);

CREATE INDEX IF NOT EXISTS idx_vendor_payment_apps_bill
  ON public."VendorPaymentApplications" (bill_id);

ALTER TABLE public."VendorPaymentApplications" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "vendor_pmt_apps_select_via_pmt" ON public."VendorPaymentApplications";
CREATE POLICY "vendor_pmt_apps_select_via_pmt" ON public."VendorPaymentApplications"
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."VendorPayments" vp
      WHERE vp.id = vendor_payment_id
        AND public.is_org_user_member_strict(vp.organization_id)
    )
  );

DROP POLICY IF EXISTS "vendor_pmt_apps_insert_via_pmt" ON public."VendorPaymentApplications";
CREATE POLICY "vendor_pmt_apps_insert_via_pmt" ON public."VendorPaymentApplications"
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."VendorPayments" vp
      WHERE vp.id = vendor_payment_id
        AND public.is_org_user_member_strict(vp.organization_id)
    )
  );

DROP POLICY IF EXISTS "vendor_pmt_apps_delete_via_pmt" ON public."VendorPaymentApplications";
CREATE POLICY "vendor_pmt_apps_delete_via_pmt" ON public."VendorPaymentApplications"
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public."VendorPayments" vp
      WHERE vp.id = vendor_payment_id
        AND public.is_org_user_member_strict(vp.organization_id)
    )
  );

-- -------------------- VendorCredits --------------------
CREATE TABLE IF NOT EXISTS public."VendorCredits" (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id  uuid NOT NULL,
  vendor_id        uuid NOT NULL REFERENCES public."DirectoryVendors"(id),
  bill_id          uuid NOT NULL REFERENCES public."VendorBills"(id),
  credit_number    text NOT NULL,
  issue_date       date NOT NULL DEFAULT CURRENT_DATE,
  amount           numeric(14,2) NOT NULL CHECK (amount > 0),
  reason           text NULL,
  status           text NOT NULL DEFAULT 'issued',
  void_reason      text NULL,
  voided_by        uuid NULL,
  voided_at        timestamptz NULL,
  deleted          boolean NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT NOW(),
  updated_at       timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vendor_credits_org_vendor_deleted
  ON public."VendorCredits" (organization_id, vendor_id, deleted);

CREATE INDEX IF NOT EXISTS idx_vendor_credits_bill_deleted
  ON public."VendorCredits" (bill_id, deleted);

CREATE UNIQUE INDEX IF NOT EXISTS ux_vendor_credits_org_number
  ON public."VendorCredits" (organization_id, credit_number)
  WHERE deleted = false;

ALTER TABLE public."VendorCredits" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "vendor_credits_select_org" ON public."VendorCredits";
CREATE POLICY "vendor_credits_select_org" ON public."VendorCredits"
  FOR SELECT TO authenticated
  USING (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "vendor_credits_insert_org" ON public."VendorCredits";
CREATE POLICY "vendor_credits_insert_org" ON public."VendorCredits"
  FOR INSERT TO authenticated
  WITH CHECK (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "vendor_credits_update_org" ON public."VendorCredits";
CREATE POLICY "vendor_credits_update_org" ON public."VendorCredits"
  FOR UPDATE TO authenticated
  USING (public.is_org_user_member_strict(organization_id));

DROP POLICY IF EXISTS "vendor_credits_delete_org" ON public."VendorCredits";
CREATE POLICY "vendor_credits_delete_org" ON public."VendorCredits"
  FOR DELETE TO authenticated
  USING (public.is_org_user_member_strict(organization_id));

-- ============================================================
-- AP Financial Views
-- ============================================================

-- Bill balances (mirrors dealer_invoice_balances_v1)
CREATE OR REPLACE VIEW public.vendor_bill_balances_v1 AS
WITH applied_by_bill AS (
  SELECT
    vpa.bill_id,
    SUM(COALESCE(vpa.applied_amount, 0))::numeric(14,2) AS applied_total
  FROM public."VendorPaymentApplications" vpa
  JOIN public."VendorPayments" vp ON vp.id = vpa.vendor_payment_id
  WHERE COALESCE(vp.status, 'active') <> 'void'
    AND vp.deleted = false
  GROUP BY vpa.bill_id
),
credited_by_bill AS (
  SELECT
    vc.bill_id,
    SUM(COALESCE(vc.amount, 0))::numeric(14,2) AS credited_total
  FROM public."VendorCredits" vc
  WHERE vc.deleted = false
    AND vc.status <> 'void'
  GROUP BY vc.bill_id
)
SELECT
  vb.id AS bill_id,
  vb.organization_id,
  vb.vendor_id,
  vb.purchase_order_id,
  vb.bill_number,
  vb.vendor_bill_ref,
  vb.status AS bill_status,
  vb.bill_date,
  vb.due_date,
  COALESCE(vb.total, 0)::numeric(14,2) AS bill_total,
  COALESCE(app.applied_total, 0)::numeric(14,2) AS applied_total,
  COALESCE(cr.credited_total, 0)::numeric(14,2) AS credited_total,
  GREATEST(COALESCE(vb.total, 0) - COALESCE(app.applied_total, 0) - COALESCE(cr.credited_total, 0), 0)::numeric(14,2) AS balance_due,
  (COALESCE(vb.total, 0) - COALESCE(app.applied_total, 0) - COALESCE(cr.credited_total, 0) > 0.005) AS is_open,
  (
    COALESCE(vb.total, 0) - COALESCE(app.applied_total, 0) - COALESCE(cr.credited_total, 0) > 0.005
    AND vb.due_date IS NOT NULL
    AND vb.due_date < CURRENT_DATE
  ) AS is_past_due
FROM public."VendorBills" vb
LEFT JOIN applied_by_bill app ON app.bill_id = vb.id
LEFT JOIN credited_by_bill cr ON cr.bill_id = vb.id
WHERE vb.deleted = false
  AND vb.organization_id IS NOT NULL
  AND vb.vendor_id IS NOT NULL;

-- Vendor financial summary (mirrors dealer_financial_summary_v1)
CREATE OR REPLACE VIEW public.vendor_financial_summary_v1 AS
WITH bill_agg AS (
  SELECT
    b.organization_id,
    b.vendor_id,
    SUM(b.bill_total)::numeric(14,2) AS total_billed_lifetime,
    SUM(b.applied_total)::numeric(14,2) AS total_paid_on_bills_lifetime,
    SUM(b.credited_total)::numeric(14,2) AS total_credited_lifetime,
    SUM(b.balance_due)::numeric(14,2) AS open_ap,
    SUM(CASE WHEN b.is_past_due THEN b.balance_due ELSE 0 END)::numeric(14,2) AS past_due_amount,
    COUNT(*) FILTER (WHERE b.is_open)::integer AS open_bills_count
  FROM public.vendor_bill_balances_v1 b
  WHERE b.bill_status <> 'void'
  GROUP BY b.organization_id, b.vendor_id
),
payment_agg AS (
  SELECT
    vp.organization_id,
    vp.vendor_id,
    SUM(COALESCE(vp.amount, 0))::numeric(14,2) AS total_payments_recorded_lifetime,
    MAX(vp.payment_date) AS last_payment_date
  FROM public."VendorPayments" vp
  WHERE vp.deleted = false
    AND COALESCE(vp.status, 'active') <> 'void'
    AND vp.organization_id IS NOT NULL
    AND vp.vendor_id IS NOT NULL
  GROUP BY vp.organization_id, vp.vendor_id
),
po_agg AS (
  SELECT
    po.organization_id,
    po.vendor_id,
    COUNT(*) FILTER (
      WHERE po.status IN ('OPEN', 'PARTIAL')
    )::integer AS open_po_count
  FROM public."PurchaseOrders" po
  WHERE po.organization_id IS NOT NULL
    AND po.vendor_id IS NOT NULL
  GROUP BY po.organization_id, po.vendor_id
),
vendor_keys AS (
  SELECT v.organization_id, v.id AS vendor_id
  FROM public."DirectoryVendors" v
  WHERE COALESCE(v.deleted, false) = false
    AND COALESCE(v.archived, false) = false
)
SELECT
  vk.organization_id,
  vk.vendor_id,
  COALESCE(ba.total_billed_lifetime, 0)::numeric(14,2) AS total_billed_lifetime,
  COALESCE(pa.total_payments_recorded_lifetime, 0)::numeric(14,2) AS total_paid_lifetime,
  COALESCE(ba.open_ap, 0)::numeric(14,2) AS open_ap,
  COALESCE(ba.past_due_amount, 0)::numeric(14,2) AS past_due_amount,
  GREATEST(COALESCE(pa.total_payments_recorded_lifetime, 0) - COALESCE(ba.total_paid_on_bills_lifetime, 0), 0)::numeric(14,2) AS unapplied_amount,
  pa.last_payment_date,
  COALESCE(ba.open_bills_count, 0)::integer AS open_bills_count,
  COALESCE(poa.open_po_count, 0)::integer AS open_po_count,
  NOW() AS computed_at
FROM vendor_keys vk
LEFT JOIN bill_agg ba
  ON ba.organization_id = vk.organization_id
 AND ba.vendor_id = vk.vendor_id
LEFT JOIN payment_agg pa
  ON pa.organization_id = vk.organization_id
 AND pa.vendor_id = vk.vendor_id
LEFT JOIN po_agg poa
  ON poa.organization_id = vk.organization_id
 AND poa.vendor_id = vk.vendor_id;

-- AP aging buckets (mirrors dealer_ar_aging_v1)
CREATE OR REPLACE VIEW public.vendor_ap_aging_v1 AS
WITH open_bills AS (
  SELECT
    b.organization_id,
    b.vendor_id,
    b.balance_due,
    b.due_date,
    GREATEST(CURRENT_DATE - COALESCE(b.due_date, CURRENT_DATE), 0) AS days_overdue
  FROM public.vendor_bill_balances_v1 b
  WHERE b.bill_status <> 'void'
    AND b.is_open = true
)
SELECT
  organization_id,
  vendor_id,
  SUM(CASE WHEN due_date IS NULL OR days_overdue = 0 THEN balance_due ELSE 0 END)::numeric(14,2) AS current,
  SUM(CASE WHEN days_overdue BETWEEN 1 AND 30 THEN balance_due ELSE 0 END)::numeric(14,2) AS days_1_30,
  SUM(CASE WHEN days_overdue BETWEEN 31 AND 60 THEN balance_due ELSE 0 END)::numeric(14,2) AS days_31_60,
  SUM(CASE WHEN days_overdue BETWEEN 61 AND 90 THEN balance_due ELSE 0 END)::numeric(14,2) AS days_61_90,
  SUM(CASE WHEN days_overdue > 90 THEN balance_due ELSE 0 END)::numeric(14,2) AS days_90_plus
FROM open_bills
GROUP BY organization_id, vendor_id;

-- AP financial timeline (mirrors dealer_financial_timeline_v1)
CREATE OR REPLACE VIEW public.vendor_financial_timeline_v1 AS
WITH po_events AS (
  SELECT
    po.organization_id,
    po.vendor_id,
    po.id AS entity_id,
    'purchase_order'::text AS entity_type,
    'purchase_order_created'::text AS event_type,
    po.created_at AS event_at,
    po.po_number AS reference_no,
    COALESCE(po.total, 0)::numeric(14,2) AS amount
  FROM public."PurchaseOrders" po
  WHERE po.organization_id IS NOT NULL
    AND po.vendor_id IS NOT NULL
),
bill_events AS (
  SELECT
    vb.organization_id,
    vb.vendor_id,
    vb.id AS entity_id,
    'bill'::text AS entity_type,
    CASE
      WHEN vb.status = 'paid' THEN 'bill_paid'
      WHEN vb.status = 'void' THEN 'bill_voided'
      WHEN vb.status = 'open' THEN 'bill_opened'
      WHEN vb.status = 'partial' THEN 'bill_partially_paid'
      ELSE 'bill_created'
    END AS event_type,
    COALESCE(vb.bill_date::timestamptz, vb.created_at) AS event_at,
    vb.bill_number AS reference_no,
    COALESCE(vb.total, 0)::numeric(14,2) AS amount
  FROM public."VendorBills" vb
  WHERE vb.deleted = false
    AND vb.organization_id IS NOT NULL
    AND vb.vendor_id IS NOT NULL
),
credit_events AS (
  SELECT
    vc.organization_id,
    vc.vendor_id,
    vc.id AS entity_id,
    'vendor_credit'::text AS entity_type,
    CASE
      WHEN vc.status = 'void' THEN 'vendor_credit_voided'
      ELSE 'vendor_credit_created'
    END AS event_type,
    COALESCE(vc.issue_date::timestamptz, vc.created_at) AS event_at,
    vc.credit_number AS reference_no,
    COALESCE(vc.amount, 0)::numeric(14,2) AS amount
  FROM public."VendorCredits" vc
  WHERE vc.deleted = false
    AND vc.organization_id IS NOT NULL
    AND vc.vendor_id IS NOT NULL
),
payment_events AS (
  SELECT
    vp.organization_id,
    vp.vendor_id,
    vp.id AS entity_id,
    'vendor_payment'::text AS entity_type,
    CASE
      WHEN COALESCE(vp.status, 'active') = 'void' THEN 'vendor_payment_voided'
      ELSE 'vendor_payment_recorded'
    END AS event_type,
    COALESCE(vp.payment_date::timestamptz, vp.created_at) AS event_at,
    COALESCE(vp.reference_number, vp.id::text) AS reference_no,
    COALESCE(vp.amount, 0)::numeric(14,2) AS amount
  FROM public."VendorPayments" vp
  WHERE vp.deleted = false
    AND vp.organization_id IS NOT NULL
    AND vp.vendor_id IS NOT NULL
),
application_events AS (
  SELECT
    vp.organization_id,
    vp.vendor_id,
    vpa.id AS entity_id,
    'vendor_payment_application'::text AS entity_type,
    'vendor_payment_applied'::text AS event_type,
    vpa.created_at AS event_at,
    vb.bill_number AS reference_no,
    COALESCE(vpa.applied_amount, 0)::numeric(14,2) AS amount
  FROM public."VendorPaymentApplications" vpa
  JOIN public."VendorPayments" vp ON vp.id = vpa.vendor_payment_id
  LEFT JOIN public."VendorBills" vb ON vb.id = vpa.bill_id
  WHERE vp.deleted = false
    AND COALESCE(vp.status, 'active') <> 'void'
    AND vp.organization_id IS NOT NULL
    AND vp.vendor_id IS NOT NULL
)
SELECT * FROM po_events
UNION ALL
SELECT * FROM bill_events
UNION ALL
SELECT * FROM credit_events
UNION ALL
SELECT * FROM payment_events
UNION ALL
SELECT * FROM application_events;

-- Integrity checks for AP
CREATE OR REPLACE VIEW public.vendor_financial_integrity_v1 AS
WITH bill_totals AS (
  SELECT
    vb.organization_id,
    vb.vendor_id,
    vb.id AS bill_id,
    COALESCE(vb.total, 0)::numeric(14,2) AS bill_total,
    COALESCE(SUM(vpa.applied_amount), 0)::numeric(14,2) AS applied_total
  FROM public."VendorBills" vb
  LEFT JOIN public."VendorPaymentApplications" vpa ON vpa.bill_id = vb.id
  WHERE vb.deleted = false
    AND vb.organization_id IS NOT NULL
    AND vb.vendor_id IS NOT NULL
  GROUP BY vb.organization_id, vb.vendor_id, vb.id, vb.total
),
payment_totals AS (
  SELECT
    vp.organization_id,
    vp.vendor_id,
    vp.id AS payment_id,
    COALESCE(vp.amount, 0)::numeric(14,2) AS payment_total,
    COALESCE(SUM(vpa.applied_amount), 0)::numeric(14,2) AS applied_total
  FROM public."VendorPayments" vp
  LEFT JOIN public."VendorPaymentApplications" vpa ON vpa.vendor_payment_id = vp.id
  WHERE vp.deleted = false
    AND vp.organization_id IS NOT NULL
    AND vp.vendor_id IS NOT NULL
  GROUP BY vp.organization_id, vp.vendor_id, vp.id, vp.amount
)
SELECT
  v.organization_id,
  v.id AS vendor_id,
  COUNT(DISTINCT bt.bill_id) FILTER (WHERE bt.applied_total > bt.bill_total + 0.005)::integer AS overapplied_bill_count,
  COUNT(DISTINCT pt.payment_id) FILTER (WHERE pt.applied_total > pt.payment_total + 0.005)::integer AS overallocated_payment_count,
  NOW() AS checked_at
FROM public."DirectoryVendors" v
LEFT JOIN bill_totals bt
  ON bt.organization_id = v.organization_id
 AND bt.vendor_id = v.id
LEFT JOIN payment_totals pt
  ON pt.organization_id = v.organization_id
 AND pt.vendor_id = v.id
WHERE COALESCE(v.deleted, false) = false
GROUP BY v.organization_id, v.id;

-- Add billing_status to PurchaseOrders for PO-Bill integration
ALTER TABLE public."PurchaseOrders"
  ADD COLUMN IF NOT EXISTS billing_status text NOT NULL DEFAULT 'unbilled';

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
