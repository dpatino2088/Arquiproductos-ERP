-- Financials Phase A: make RLS honor Permissions module for AR/AP flows.
-- Keeps org scoping but gates read/write actions by financial permission codes.

CREATE OR REPLACE FUNCTION public.can_read_financials_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'financials.read',
      'financials.create',
      'financials.edit',
      'financials.delete',
      'financials.void',
      'financials.write',
      'financials.invoices.create'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_create_financials_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'financials.invoices.create',
      'financials.create',
      'financials.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_update_financials_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'financials.edit',
      'financials.void',
      'financials.write'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_delete_financials_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'financials.delete',
      'financials.write'
    ]::text[]
  );
$$;

GRANT EXECUTE ON FUNCTION public.can_read_financials_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_create_financials_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_update_financials_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_delete_financials_org(uuid) TO authenticated;

-- DealerInvoices + DealerInvoiceLines (AR invoices)
DROP POLICY IF EXISTS dealer_invoices_select ON public."DealerInvoices";
CREATE POLICY dealer_invoices_select ON public."DealerInvoices"
  FOR SELECT
  TO authenticated
  USING (public.is_portal_user_in_org(organization_id) OR public.can_read_financials_org(organization_id));

DROP POLICY IF EXISTS dealer_invoices_write ON public."DealerInvoices";
DROP POLICY IF EXISTS dealer_invoices_insert ON public."DealerInvoices";
DROP POLICY IF EXISTS dealer_invoices_update ON public."DealerInvoices";
DROP POLICY IF EXISTS dealer_invoices_delete ON public."DealerInvoices";

CREATE POLICY dealer_invoices_insert ON public."DealerInvoices"
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_create_financials_org(organization_id));

CREATE POLICY dealer_invoices_update ON public."DealerInvoices"
  FOR UPDATE
  TO authenticated
  USING (public.can_update_financials_org(organization_id))
  WITH CHECK (public.can_update_financials_org(organization_id));

CREATE POLICY dealer_invoices_delete ON public."DealerInvoices"
  FOR DELETE
  TO authenticated
  USING (public.can_delete_financials_org(organization_id));

DROP POLICY IF EXISTS dealer_invoice_lines_select ON public."DealerInvoiceLines";
CREATE POLICY dealer_invoice_lines_select ON public."DealerInvoiceLines"
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND (public.is_portal_user_in_org(di.organization_id) OR public.can_read_financials_org(di.organization_id))
    )
  );

DROP POLICY IF EXISTS dealer_invoice_lines_write ON public."DealerInvoiceLines";
DROP POLICY IF EXISTS dealer_invoice_lines_insert ON public."DealerInvoiceLines";
DROP POLICY IF EXISTS dealer_invoice_lines_update ON public."DealerInvoiceLines";
DROP POLICY IF EXISTS dealer_invoice_lines_delete ON public."DealerInvoiceLines";

CREATE POLICY dealer_invoice_lines_insert ON public."DealerInvoiceLines"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND (public.can_create_financials_org(di.organization_id) OR public.can_update_financials_org(di.organization_id))
    )
  );

CREATE POLICY dealer_invoice_lines_update ON public."DealerInvoiceLines"
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND public.can_update_financials_org(di.organization_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND public.can_update_financials_org(di.organization_id)
    )
  );

CREATE POLICY dealer_invoice_lines_delete ON public."DealerInvoiceLines"
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND public.can_delete_financials_org(di.organization_id)
    )
  );

-- Payments + PaymentApplications (AR)
DROP POLICY IF EXISTS payments_select_own_org ON public."Payments";
CREATE POLICY payments_select_own_org ON public."Payments"
  FOR SELECT
  TO authenticated
  USING (public.is_portal_user_in_org(organization_id) OR public.can_read_financials_org(organization_id));

DROP POLICY IF EXISTS payments_write_own_org ON public."Payments";
DROP POLICY IF EXISTS payments_insert_own_org ON public."Payments";
DROP POLICY IF EXISTS payments_update_own_org ON public."Payments";
DROP POLICY IF EXISTS payments_delete_own_org ON public."Payments";

CREATE POLICY payments_insert_own_org ON public."Payments"
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_create_financials_org(organization_id));

CREATE POLICY payments_update_own_org ON public."Payments"
  FOR UPDATE
  TO authenticated
  USING (public.can_update_financials_org(organization_id))
  WITH CHECK (public.can_update_financials_org(organization_id));

CREATE POLICY payments_delete_own_org ON public."Payments"
  FOR DELETE
  TO authenticated
  USING (public.can_delete_financials_org(organization_id));

DROP POLICY IF EXISTS payment_apps_select ON public."PaymentApplications";
CREATE POLICY payment_apps_select ON public."PaymentApplications"
  FOR SELECT
  TO authenticated
  USING (public.is_portal_user_in_org(organization_id) OR public.can_read_financials_org(organization_id));

DROP POLICY IF EXISTS payment_apps_write ON public."PaymentApplications";
DROP POLICY IF EXISTS payment_apps_insert ON public."PaymentApplications";
DROP POLICY IF EXISTS payment_apps_update ON public."PaymentApplications";
DROP POLICY IF EXISTS payment_apps_delete ON public."PaymentApplications";

CREATE POLICY payment_apps_insert ON public."PaymentApplications"
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_create_financials_org(organization_id) OR public.can_update_financials_org(organization_id));

CREATE POLICY payment_apps_update ON public."PaymentApplications"
  FOR UPDATE
  TO authenticated
  USING (public.can_update_financials_org(organization_id))
  WITH CHECK (public.can_update_financials_org(organization_id));

CREATE POLICY payment_apps_delete ON public."PaymentApplications"
  FOR DELETE
  TO authenticated
  USING (public.can_delete_financials_org(organization_id));

-- VendorBills + VendorBillLines (AP)
DROP POLICY IF EXISTS "vendor_bills_select_org" ON public."VendorBills";
CREATE POLICY "vendor_bills_select_org" ON public."VendorBills"
  FOR SELECT
  TO authenticated
  USING (public.can_read_financials_org(organization_id));

DROP POLICY IF EXISTS "vendor_bills_insert_org" ON public."VendorBills";
CREATE POLICY "vendor_bills_insert_org" ON public."VendorBills"
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_create_financials_org(organization_id));

DROP POLICY IF EXISTS "vendor_bills_update_org" ON public."VendorBills";
CREATE POLICY "vendor_bills_update_org" ON public."VendorBills"
  FOR UPDATE
  TO authenticated
  USING (public.can_update_financials_org(organization_id))
  WITH CHECK (public.can_update_financials_org(organization_id));

DROP POLICY IF EXISTS "vendor_bills_delete_org" ON public."VendorBills";
CREATE POLICY "vendor_bills_delete_org" ON public."VendorBills"
  FOR DELETE
  TO authenticated
  USING (public.can_delete_financials_org(organization_id));

DROP POLICY IF EXISTS "vendor_bill_lines_select_via_bill" ON public."VendorBillLines";
CREATE POLICY "vendor_bill_lines_select_via_bill" ON public."VendorBillLines"
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."VendorBills" vb
      WHERE vb.id = public."VendorBillLines".bill_id
        AND public.can_read_financials_org(vb.organization_id)
    )
  );

DROP POLICY IF EXISTS "vendor_bill_lines_insert_via_bill" ON public."VendorBillLines";
CREATE POLICY "vendor_bill_lines_insert_via_bill" ON public."VendorBillLines"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."VendorBills" vb
      WHERE vb.id = public."VendorBillLines".bill_id
        AND (public.can_create_financials_org(vb.organization_id) OR public.can_update_financials_org(vb.organization_id))
    )
  );

DROP POLICY IF EXISTS "vendor_bill_lines_update_via_bill" ON public."VendorBillLines";
CREATE POLICY "vendor_bill_lines_update_via_bill" ON public."VendorBillLines"
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."VendorBills" vb
      WHERE vb.id = public."VendorBillLines".bill_id
        AND public.can_update_financials_org(vb.organization_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."VendorBills" vb
      WHERE vb.id = public."VendorBillLines".bill_id
        AND public.can_update_financials_org(vb.organization_id)
    )
  );

DROP POLICY IF EXISTS "vendor_bill_lines_delete_via_bill" ON public."VendorBillLines";
CREATE POLICY "vendor_bill_lines_delete_via_bill" ON public."VendorBillLines"
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."VendorBills" vb
      WHERE vb.id = public."VendorBillLines".bill_id
        AND public.can_delete_financials_org(vb.organization_id)
    )
  );

-- VendorPayments + VendorPaymentApplications (AP)
DROP POLICY IF EXISTS "vendor_payments_select_org" ON public."VendorPayments";
CREATE POLICY "vendor_payments_select_org" ON public."VendorPayments"
  FOR SELECT
  TO authenticated
  USING (public.can_read_financials_org(organization_id));

DROP POLICY IF EXISTS "vendor_payments_insert_org" ON public."VendorPayments";
CREATE POLICY "vendor_payments_insert_org" ON public."VendorPayments"
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_create_financials_org(organization_id));

DROP POLICY IF EXISTS "vendor_payments_update_org" ON public."VendorPayments";
CREATE POLICY "vendor_payments_update_org" ON public."VendorPayments"
  FOR UPDATE
  TO authenticated
  USING (public.can_update_financials_org(organization_id))
  WITH CHECK (public.can_update_financials_org(organization_id));

DROP POLICY IF EXISTS "vendor_payments_delete_org" ON public."VendorPayments";
CREATE POLICY "vendor_payments_delete_org" ON public."VendorPayments"
  FOR DELETE
  TO authenticated
  USING (public.can_delete_financials_org(organization_id));

DROP POLICY IF EXISTS "vendor_pmt_apps_select_via_pmt" ON public."VendorPaymentApplications";
CREATE POLICY "vendor_pmt_apps_select_via_pmt" ON public."VendorPaymentApplications"
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."VendorPayments" vp
      WHERE vp.id = public."VendorPaymentApplications".vendor_payment_id
        AND public.can_read_financials_org(vp.organization_id)
    )
  );

DROP POLICY IF EXISTS "vendor_pmt_apps_insert_via_pmt" ON public."VendorPaymentApplications";
CREATE POLICY "vendor_pmt_apps_insert_via_pmt" ON public."VendorPaymentApplications"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."VendorPayments" vp
      WHERE vp.id = public."VendorPaymentApplications".vendor_payment_id
        AND (public.can_create_financials_org(vp.organization_id) OR public.can_update_financials_org(vp.organization_id))
    )
  );

DROP POLICY IF EXISTS "vendor_pmt_apps_delete_via_pmt" ON public."VendorPaymentApplications";
CREATE POLICY "vendor_pmt_apps_delete_via_pmt" ON public."VendorPaymentApplications"
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."VendorPayments" vp
      WHERE vp.id = public."VendorPaymentApplications".vendor_payment_id
        AND public.can_delete_financials_org(vp.organization_id)
    )
  );

-- VendorCredits (AP)
DROP POLICY IF EXISTS "vendor_credits_select_org" ON public."VendorCredits";
CREATE POLICY "vendor_credits_select_org" ON public."VendorCredits"
  FOR SELECT
  TO authenticated
  USING (public.can_read_financials_org(organization_id));

DROP POLICY IF EXISTS "vendor_credits_insert_org" ON public."VendorCredits";
CREATE POLICY "vendor_credits_insert_org" ON public."VendorCredits"
  FOR INSERT
  TO authenticated
  WITH CHECK (public.can_create_financials_org(organization_id));

DROP POLICY IF EXISTS "vendor_credits_update_org" ON public."VendorCredits";
CREATE POLICY "vendor_credits_update_org" ON public."VendorCredits"
  FOR UPDATE
  TO authenticated
  USING (public.can_update_financials_org(organization_id))
  WITH CHECK (public.can_update_financials_org(organization_id));

DROP POLICY IF EXISTS "vendor_credits_delete_org" ON public."VendorCredits";
CREATE POLICY "vendor_credits_delete_org" ON public."VendorCredits"
  FOR DELETE
  TO authenticated
  USING (public.can_delete_financials_org(organization_id));;
