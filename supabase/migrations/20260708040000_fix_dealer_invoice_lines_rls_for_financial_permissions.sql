-- Allow invoice line writes for users allowed to write invoices in the same organization.

DROP POLICY IF EXISTS dealer_invoice_lines_write ON public."DealerInvoiceLines";

CREATE POLICY dealer_invoice_lines_write ON public."DealerInvoiceLines"
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND public.can_write_financials_org(di.organization_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."DealerInvoices" di
      WHERE di.id = public."DealerInvoiceLines".invoice_id
        AND public.can_write_financials_org(di.organization_id)
    )
  );
