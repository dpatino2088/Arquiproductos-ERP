
BEGIN;

-- ============================================================
-- 1. ALTER existing Payments table
-- ============================================================
ALTER TABLE public."Payments"
  ADD COLUMN IF NOT EXISTS dealer_id uuid NULL,
  ADD COLUMN IF NOT EXISTS recorded_by_name text NULL;

-- Backfill dealer_id from SalesOrders
UPDATE public."Payments" p
SET dealer_id = so.dealer_id
FROM public."SalesOrders" so
WHERE so.id = p.sales_order_id AND p.dealer_id IS NULL;

ALTER TABLE public."Payments"
  ALTER COLUMN sales_order_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS payments_org_dealer_idx ON public."Payments"(organization_id, dealer_id);

-- ============================================================
-- 2. DealerInvoices
-- ============================================================
CREATE TABLE IF NOT EXISTS public."DealerInvoices" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  dealer_id uuid NOT NULL,
  sales_order_id uuid NULL REFERENCES public."SalesOrders"(id) ON DELETE SET NULL,
  invoice_number text NOT NULL,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','issued','partial','paid','void')),
  issue_date date NOT NULL DEFAULT (now()::date),
  due_date date NULL,
  currency_code text NOT NULL DEFAULT 'USD',
  subtotal numeric(12,2) NOT NULL DEFAULT 0,
  tax_total numeric(12,2) NOT NULL DEFAULT 0,
  total numeric(12,2) NOT NULL DEFAULT 0,
  notes text NULL,
  deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS dealer_invoices_org_invoice_number_uniq
  ON public."DealerInvoices"(organization_id, invoice_number) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS dealer_invoices_org_dealer_idx
  ON public."DealerInvoices"(organization_id, dealer_id);
CREATE INDEX IF NOT EXISTS dealer_invoices_sales_order_idx
  ON public."DealerInvoices"(sales_order_id);

-- ============================================================
-- 3. DealerInvoiceLines
-- ============================================================
CREATE TABLE IF NOT EXISTS public."DealerInvoiceLines" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL REFERENCES public."DealerInvoices"(id) ON DELETE CASCADE,
  sales_order_line_id uuid NULL,
  sort_order int NOT NULL DEFAULT 0,
  description text NOT NULL,
  qty numeric(12,4) NOT NULL DEFAULT 1 CHECK (qty >= 0),
  unit_price numeric(12,4) NOT NULL DEFAULT 0 CHECK (unit_price >= 0),
  tax_pct numeric(7,4) NOT NULL DEFAULT 0 CHECK (tax_pct >= 0),
  line_subtotal numeric(12,2) NOT NULL DEFAULT 0,
  line_tax numeric(12,2) NOT NULL DEFAULT 0,
  line_total numeric(12,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS dealer_invoice_lines_invoice_idx ON public."DealerInvoiceLines"(invoice_id);

-- ============================================================
-- 4. PaymentApplications
-- ============================================================
CREATE TABLE IF NOT EXISTS public."PaymentApplications" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  dealer_id uuid NOT NULL,
  payment_id uuid NOT NULL REFERENCES public."Payments"(id) ON DELETE CASCADE,
  invoice_id uuid NOT NULL REFERENCES public."DealerInvoices"(id) ON DELETE CASCADE,
  applied_amount numeric(12,2) NOT NULL CHECK (applied_amount > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payment_apps_payment_idx ON public."PaymentApplications"(payment_id);
CREATE INDEX IF NOT EXISTS payment_apps_invoice_idx ON public."PaymentApplications"(invoice_id);
CREATE UNIQUE INDEX IF NOT EXISTS payment_apps_payment_invoice_uniq
  ON public."PaymentApplications"(payment_id, invoice_id);

-- ============================================================
-- 5. compute_invoice_totals
-- ============================================================
CREATE OR REPLACE FUNCTION public.compute_invoice_totals(p_invoice_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_sub numeric(12,2); v_tax numeric(12,2); v_total numeric(12,2); v_paid numeric(12,2);
BEGIN
  SELECT COALESCE(SUM(line_subtotal),0), COALESCE(SUM(line_tax),0), COALESCE(SUM(line_total),0)
  INTO v_sub, v_tax, v_total
  FROM public."DealerInvoiceLines" WHERE invoice_id = p_invoice_id;

  SELECT COALESCE(SUM(applied_amount),0) INTO v_paid
  FROM public."PaymentApplications" WHERE invoice_id = p_invoice_id;

  UPDATE public."DealerInvoices"
  SET subtotal = v_sub, tax_total = v_tax, total = v_total,
      status = CASE
        WHEN status = 'void' THEN 'void'
        WHEN status = 'draft' THEN 'draft'
        WHEN v_total = 0 THEN 'issued'
        WHEN v_paid <= 0 THEN 'issued'
        WHEN v_paid < v_total THEN 'partial'
        ELSE 'paid'
      END,
      updated_at = now()
  WHERE id = p_invoice_id;
END;
$$;

-- ============================================================
-- 6. Triggers on DealerInvoiceLines
-- ============================================================
CREATE OR REPLACE FUNCTION public.trg_invoice_lines_recalc()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.line_subtotal := ROUND((NEW.qty * NEW.unit_price)::numeric, 2);
  NEW.line_tax      := ROUND((NEW.line_subtotal * NEW.tax_pct)::numeric, 2);
  NEW.line_total    := NEW.line_subtotal + NEW.line_tax;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_invoice_lines_recalc ON public."DealerInvoiceLines";
CREATE TRIGGER trg_invoice_lines_recalc
  BEFORE INSERT OR UPDATE ON public."DealerInvoiceLines"
  FOR EACH ROW EXECUTE FUNCTION public.trg_invoice_lines_recalc();

CREATE OR REPLACE FUNCTION public.trg_invoice_lines_after_change()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM public.compute_invoice_totals(COALESCE(NEW.invoice_id, OLD.invoice_id));
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_invoice_lines_after_change ON public."DealerInvoiceLines";
CREATE TRIGGER trg_invoice_lines_after_change
  AFTER INSERT OR UPDATE OR DELETE ON public."DealerInvoiceLines"
  FOR EACH ROW EXECUTE FUNCTION public.trg_invoice_lines_after_change();

CREATE OR REPLACE FUNCTION public.trg_payment_applications_after_change()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  PERFORM public.compute_invoice_totals(COALESCE(NEW.invoice_id, OLD.invoice_id));
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_payment_applications_after_change ON public."PaymentApplications";
CREATE TRIGGER trg_payment_applications_after_change
  AFTER INSERT OR UPDATE OR DELETE ON public."PaymentApplications"
  FOR EACH ROW EXECUTE FUNCTION public.trg_payment_applications_after_change();

-- ============================================================
-- 7. apply_payment / unapply_payment
-- ============================================================
CREATE OR REPLACE FUNCTION public.apply_payment(p_payment_id uuid, p_invoice_id uuid, p_amount numeric)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_app_id uuid; v_org_id uuid; v_dealer_id uuid;
  v_invoice_total numeric; v_invoice_paid numeric;
  v_payment_amount numeric; v_payment_applied numeric;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN RAISE EXCEPTION 'Amount must be > 0'; END IF;

  SELECT organization_id, dealer_id, total INTO v_org_id, v_dealer_id, v_invoice_total
  FROM public."DealerInvoices" WHERE id = p_invoice_id FOR UPDATE;

  SELECT amount INTO v_payment_amount FROM public."Payments" WHERE id = p_payment_id FOR UPDATE;

  IF v_payment_amount IS NULL THEN RAISE EXCEPTION 'Payment not found'; END IF;

  SELECT COALESCE(SUM(applied_amount),0) INTO v_invoice_paid
  FROM public."PaymentApplications" WHERE invoice_id = p_invoice_id;

  SELECT COALESCE(SUM(applied_amount),0) INTO v_payment_applied
  FROM public."PaymentApplications" WHERE payment_id = p_payment_id;

  IF p_amount > GREATEST(v_invoice_total - v_invoice_paid, 0) THEN
    RAISE EXCEPTION 'Amount exceeds invoice balance';
  END IF;
  IF p_amount > GREATEST(v_payment_amount - v_payment_applied, 0) THEN
    RAISE EXCEPTION 'Amount exceeds payment unapplied balance';
  END IF;

  INSERT INTO public."PaymentApplications"(organization_id, dealer_id, payment_id, invoice_id, applied_amount)
  VALUES (v_org_id, v_dealer_id, p_payment_id, p_invoice_id, ROUND(p_amount, 2))
  RETURNING id INTO v_app_id;

  RETURN v_app_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.unapply_payment(p_application_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM public."PaymentApplications" WHERE id = p_application_id;
END;
$$;

-- ============================================================
-- 8. sales_order_financial_summary VIEW
-- ============================================================
CREATE OR REPLACE VIEW public.sales_order_financial_summary AS
SELECT
  di.sales_order_id,
  di.organization_id,
  di.dealer_id,
  COUNT(DISTINCT di.id)::int                                        AS invoice_count,
  COALESCE(SUM(di.total), 0)                                       AS total_invoiced,
  COALESCE(SUM(pa_totals.applied), 0)                              AS total_paid,
  GREATEST(COALESCE(SUM(di.total), 0)
    - COALESCE(SUM(pa_totals.applied), 0), 0)                      AS balance_due,
  CASE
    WHEN COALESCE(SUM(di.total), 0) = 0 THEN 'none'
    WHEN COALESCE(SUM(pa_totals.applied), 0) = 0 THEN 'issued'
    WHEN COALESCE(SUM(pa_totals.applied), 0)
       < COALESCE(SUM(di.total), 0) THEN 'partial'
    ELSE 'paid'
  END                                                               AS invoice_status,
  (SELECT di2.id FROM public."DealerInvoices" di2
   WHERE di2.sales_order_id = di.sales_order_id AND di2.deleted = false AND di2.status <> 'void'
   ORDER BY di2.created_at DESC LIMIT 1)                           AS latest_invoice_id,
  (SELECT di2.invoice_number FROM public."DealerInvoices" di2
   WHERE di2.sales_order_id = di.sales_order_id AND di2.deleted = false AND di2.status <> 'void'
   ORDER BY di2.created_at DESC LIMIT 1)                           AS latest_invoice_number
FROM public."DealerInvoices" di
LEFT JOIN (
  SELECT invoice_id, SUM(applied_amount) AS applied
  FROM public."PaymentApplications"
  GROUP BY invoice_id
) pa_totals ON pa_totals.invoice_id = di.id
WHERE di.sales_order_id IS NOT NULL
  AND di.deleted = false
  AND di.status <> 'void'
GROUP BY di.sales_order_id, di.organization_id, di.dealer_id;

-- ============================================================
-- 9. RLS
-- ============================================================
ALTER TABLE public."DealerInvoices" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS dealer_invoices_select ON public."DealerInvoices";
CREATE POLICY dealer_invoices_select ON public."DealerInvoices" FOR SELECT
  USING (is_org_user_member_strict(organization_id) OR is_portal_user_in_org(organization_id));
DROP POLICY IF EXISTS dealer_invoices_write ON public."DealerInvoices";
CREATE POLICY dealer_invoices_write ON public."DealerInvoices" FOR ALL
  USING (is_org_user_superadmin(organization_id));

ALTER TABLE public."DealerInvoiceLines" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS dealer_invoice_lines_select ON public."DealerInvoiceLines";
CREATE POLICY dealer_invoice_lines_select ON public."DealerInvoiceLines" FOR SELECT
  USING (EXISTS (SELECT 1 FROM public."DealerInvoices" di WHERE di.id = invoice_id
    AND (is_org_user_member_strict(di.organization_id) OR is_portal_user_in_org(di.organization_id))));
DROP POLICY IF EXISTS dealer_invoice_lines_write ON public."DealerInvoiceLines";
CREATE POLICY dealer_invoice_lines_write ON public."DealerInvoiceLines" FOR ALL
  USING (EXISTS (SELECT 1 FROM public."DealerInvoices" di WHERE di.id = invoice_id
    AND is_org_user_superadmin(di.organization_id)));

ALTER TABLE public."PaymentApplications" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS payment_apps_select ON public."PaymentApplications";
CREATE POLICY payment_apps_select ON public."PaymentApplications" FOR SELECT
  USING (is_org_user_member_strict(organization_id) OR is_portal_user_in_org(organization_id));
DROP POLICY IF EXISTS payment_apps_write ON public."PaymentApplications";
CREATE POLICY payment_apps_write ON public."PaymentApplications" FOR ALL
  USING (is_org_user_superadmin(organization_id));

-- ============================================================
-- 10. Drop payment_status and amount_paid from SalesOrders
-- ============================================================
ALTER TABLE public."SalesOrders"
  DROP COLUMN IF EXISTS payment_status,
  DROP COLUMN IF EXISTS amount_paid;

COMMIT;
;
