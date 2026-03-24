-- Portal My Financials (read-only) - robust cutover
-- - Adds portal.financials.* permissions
-- - Grants by dealer role
-- - Tightens portal SELECT visibility to dealer-owned rows only
-- - Keeps internal Financials behavior unchanged
-- - Adds portal-friendly AR views

-- 1) Portal permissions catalog
INSERT INTO public."Permissions" (code, module, description)
VALUES
  ('portal.financials.read', 'financials', 'View portal My Financials module'),
  ('portal.financials.invoices.read', 'financials', 'View portal invoice list/detail'),
  ('portal.financials.payments.read', 'financials', 'View portal payment list/detail'),
  ('portal.financials.statement.read', 'financials', 'View portal account statement/aging'),
  ('portal.financials.invoice_pdf.read', 'financials', 'Download portal invoice PDF')
ON CONFLICT (code) DO UPDATE
SET module = EXCLUDED.module,
    description = EXCLUDED.description;

-- 2) Grants by role
INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
SELECT g.role_code, g.permission_code
FROM (
  SELECT 'dealer_manager'::text AS role_code, unnest(ARRAY[
    'portal.financials.read',
    'portal.financials.invoices.read',
    'portal.financials.payments.read',
    'portal.financials.statement.read',
    'portal.financials.invoice_pdf.read'
  ]::text[]) AS permission_code
  UNION ALL
  SELECT 'dealer_member'::text AS role_code, unnest(ARRAY[
    'portal.financials.read',
    'portal.financials.invoices.read',
    'portal.financials.payments.read',
    'portal.financials.invoice_pdf.read'
  ]::text[]) AS permission_code
) AS g
ON CONFLICT (role_code, permission_code) DO NOTHING;

-- 3) Portal helpers
CREATE OR REPLACE FUNCTION public.can_read_portal_financials_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    session_is_dealer_user(p_org_id)
    AND user_has_org_permission(
      p_org_id,
      ARRAY['portal.financials.read']::text[]
    );
$$;

CREATE OR REPLACE FUNCTION public.can_read_portal_financials_invoice_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    can_read_portal_financials_org(p_org_id)
    AND user_has_org_permission(
      p_org_id,
      ARRAY['portal.financials.invoices.read']::text[]
    );
$$;

CREATE OR REPLACE FUNCTION public.can_read_portal_financials_payment_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    can_read_portal_financials_org(p_org_id)
    AND user_has_org_permission(
      p_org_id,
      ARRAY['portal.financials.payments.read']::text[]
    );
$$;

CREATE OR REPLACE FUNCTION public.can_read_portal_financials_statement_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    can_read_portal_financials_org(p_org_id)
    AND user_has_org_permission(
      p_org_id,
      ARRAY['portal.financials.statement.read']::text[]
    );
$$;

GRANT EXECUTE ON FUNCTION public.can_read_portal_financials_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_portal_financials_invoice_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_portal_financials_payment_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_portal_financials_statement_org(uuid) TO authenticated;

-- 4) RLS - SELECT dealer-owned rows only for portal
DROP POLICY IF EXISTS dealer_invoices_select ON public."DealerInvoices";
CREATE POLICY dealer_invoices_select ON public."DealerInvoices"
  FOR SELECT TO authenticated
  USING (
    (
      can_read_financials_org(organization_id)
    )
    OR
    (
      can_read_portal_financials_invoice_org(organization_id)
      AND dealer_id = current_dealer_id()
    )
  );

DROP POLICY IF EXISTS dealer_invoice_lines_select ON public."DealerInvoiceLines";
CREATE POLICY dealer_invoice_lines_select ON public."DealerInvoiceLines"
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND (
          can_read_financials_org(di.organization_id)
          OR (
            can_read_portal_financials_invoice_org(di.organization_id)
            AND di.dealer_id = current_dealer_id()
          )
        )
    )
  );

DROP POLICY IF EXISTS payments_select_own_org ON public."Payments";
CREATE POLICY payments_select_own_org ON public."Payments"
  FOR SELECT TO authenticated
  USING (
    (
      can_read_financials_org(organization_id)
    )
    OR
    (
      can_read_portal_financials_payment_org(organization_id)
      AND dealer_id = current_dealer_id()
    )
  );

DROP POLICY IF EXISTS payment_apps_select ON public."PaymentApplications";
CREATE POLICY payment_apps_select ON public."PaymentApplications"
  FOR SELECT TO authenticated
  USING (
    (
      can_read_financials_org(organization_id)
    )
    OR
    (
      can_read_portal_financials_payment_org(organization_id)
      AND EXISTS (
        SELECT 1
        FROM public."DealerInvoices" di
        WHERE di.id = public."PaymentApplications".invoice_id
          AND di.organization_id = public."PaymentApplications".organization_id
          AND di.dealer_id = current_dealer_id()
      )
      AND EXISTS (
        SELECT 1
        FROM public."Payments" p
        WHERE p.id = public."PaymentApplications".payment_id
          AND p.organization_id = public."PaymentApplications".organization_id
          AND p.dealer_id = current_dealer_id()
      )
    )
  );

-- 5) Portal views (consumer-facing, read-only)
CREATE OR REPLACE VIEW public.portal_dealer_invoices_v1 AS
SELECT
  di.organization_id,
  di.dealer_id,
  di.id AS invoice_id,
  di.invoice_number,
  di.status,
  di.issue_date,
  di.due_date,
  di.currency_code,
  di.subtotal,
  di.tax_total,
  di.total,
  COALESCE(SUM(pa.applied_amount), 0::numeric) AS applied_total,
  GREATEST(di.total - COALESCE(SUM(pa.applied_amount), 0::numeric), 0::numeric) AS balance_due
FROM public."DealerInvoices" di
LEFT JOIN public."PaymentApplications" pa ON pa.invoice_id = di.id
WHERE di.deleted = false
GROUP BY di.organization_id, di.dealer_id, di.id, di.invoice_number, di.status, di.issue_date, di.due_date, di.currency_code, di.subtotal, di.tax_total, di.total;

CREATE OR REPLACE VIEW public.portal_dealer_payments_v1 AS
SELECT
  p.organization_id,
  p.dealer_id,
  p.id AS payment_id,
  p.payment_date,
  p.payment_method,
  p.reference_number,
  p.amount,
  p.status,
  p.recorded_by_name,
  p.created_at,
  COALESCE(SUM(pa.applied_amount), 0::numeric) AS applied_total,
  GREATEST(p.amount - COALESCE(SUM(pa.applied_amount), 0::numeric), 0::numeric) AS unapplied_total
FROM public."Payments" p
LEFT JOIN public."PaymentApplications" pa ON pa.payment_id = p.id
WHERE p.deleted = false
GROUP BY p.organization_id, p.dealer_id, p.id, p.payment_date, p.payment_method, p.reference_number, p.amount, p.status, p.recorded_by_name, p.created_at;

CREATE OR REPLACE VIEW public.portal_dealer_timeline_v1 AS
SELECT
  x.organization_id,
  x.dealer_id,
  x.event_date,
  x.event_type,
  x.reference_no,
  x.amount,
  x.status,
  x.metadata
FROM (
  SELECT
    di.organization_id,
    di.dealer_id,
    di.issue_date AS event_date,
    'invoice'::text AS event_type,
    di.invoice_number AS reference_no,
    di.total AS amount,
    di.status::text AS status,
    jsonb_build_object('invoice_id', di.id) AS metadata
  FROM public."DealerInvoices" di
  WHERE di.deleted = false

  UNION ALL

  SELECT
    p.organization_id,
    p.dealer_id,
    p.payment_date AS event_date,
    'payment'::text AS event_type,
    COALESCE(p.reference_number, p.id::text) AS reference_no,
    p.amount AS amount,
    p.status::text AS status,
    jsonb_build_object('payment_id', p.id) AS metadata
  FROM public."Payments" p
  WHERE p.deleted = false
) AS x;

CREATE OR REPLACE VIEW public.portal_dealer_statement_v1 AS
SELECT
  i.organization_id,
  i.dealer_id,
  COUNT(*) FILTER (WHERE i.status <> 'void')::int AS invoices_count,
  COUNT(*) FILTER (WHERE i.status <> 'void' AND i.balance_due > 0)::int AS open_invoices_count,
  COALESCE(SUM(i.total) FILTER (WHERE i.status <> 'void'), 0::numeric) AS total_invoiced,
  COALESCE(SUM(i.applied_total) FILTER (WHERE i.status <> 'void'), 0::numeric) AS total_paid_applied,
  COALESCE(SUM(i.balance_due) FILTER (WHERE i.status <> 'void'), 0::numeric) AS open_ar,
  COALESCE(SUM(i.balance_due) FILTER (WHERE i.status <> 'void' AND i.due_date < CURRENT_DATE), 0::numeric) AS past_due,
  COALESCE(SUM(i.balance_due) FILTER (WHERE i.status <> 'void' AND i.due_date >= CURRENT_DATE), 0::numeric) AS current_due,
  COALESCE(SUM(i.balance_due) FILTER (WHERE i.status <> 'void' AND i.due_date >= CURRENT_DATE - INTERVAL '30 day' AND i.due_date < CURRENT_DATE), 0::numeric) AS bucket_0_30,
  COALESCE(SUM(i.balance_due) FILTER (WHERE i.status <> 'void' AND i.due_date >= CURRENT_DATE - INTERVAL '60 day' AND i.due_date < CURRENT_DATE - INTERVAL '30 day'), 0::numeric) AS bucket_31_60,
  COALESCE(SUM(i.balance_due) FILTER (WHERE i.status <> 'void' AND i.due_date >= CURRENT_DATE - INTERVAL '90 day' AND i.due_date < CURRENT_DATE - INTERVAL '60 day'), 0::numeric) AS bucket_61_90,
  COALESCE(SUM(i.balance_due) FILTER (WHERE i.status <> 'void' AND i.due_date < CURRENT_DATE - INTERVAL '90 day'), 0::numeric) AS bucket_over_90
FROM public.portal_dealer_invoices_v1 i
GROUP BY i.organization_id, i.dealer_id;

GRANT SELECT ON public.portal_dealer_invoices_v1 TO authenticated;
GRANT SELECT ON public.portal_dealer_payments_v1 TO authenticated;
GRANT SELECT ON public.portal_dealer_timeline_v1 TO authenticated;
GRANT SELECT ON public.portal_dealer_statement_v1 TO authenticated;
