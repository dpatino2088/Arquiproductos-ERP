-- Fix invoice tax rounding: compute tax_total at header level (subtotal × rate)
-- instead of SUM(line_tax) to prevent per-line rounding accumulation errors.
-- This aligns invoice totals with SalesOrder totals which use the same method.

CREATE OR REPLACE FUNCTION public.compute_invoice_totals(p_invoice_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sub     numeric(14,2);
  v_tax     numeric(14,2);
  v_total   numeric(14,2);
  v_paid    numeric(14,2);
  v_credited numeric(14,2);
  v_covered numeric(14,2);
  v_current_status text;
  v_new_status     text;
  v_tax_rate numeric;
BEGIN
  SELECT COALESCE(SUM(line_subtotal), 0)
  INTO v_sub
  FROM public."DealerInvoiceLines"
  WHERE invoice_id = p_invoice_id;

  SELECT COALESCE(MAX(tax_pct), 0)
  INTO v_tax_rate
  FROM public."DealerInvoiceLines"
  WHERE invoice_id = p_invoice_id;

  -- Tax at header level avoids per-line rounding drift
  v_tax   := ROUND(v_sub * v_tax_rate, 2);
  v_total := v_sub + v_tax;

  SELECT COALESCE(SUM(applied_amount), 0) INTO v_paid
  FROM public."PaymentApplications"
  WHERE invoice_id = p_invoice_id;

  SELECT COALESCE(SUM(amount), 0) INTO v_credited
  FROM public."DealerCreditNotes"
  WHERE invoice_id = p_invoice_id
    AND deleted = false
    AND status <> 'void';

  v_covered := v_paid + v_credited;

  SELECT status INTO v_current_status
  FROM public."DealerInvoices"
  WHERE id = p_invoice_id;

  IF v_current_status = 'void' THEN
    v_new_status := 'void';
  ELSIF v_current_status = 'draft' THEN
    v_new_status := 'draft';
  ELSIF v_total <= 0 THEN
    v_new_status := 'issued';
  ELSIF v_covered <= 0 THEN
    v_new_status := 'issued';
  ELSIF v_covered < v_total - 0.005 THEN
    v_new_status := 'partial';
  ELSE
    v_new_status := 'paid';
  END IF;

  UPDATE public."DealerInvoices"
  SET subtotal   = v_sub,
      tax_total  = v_tax,
      total      = v_total,
      status     = v_new_status,
      updated_at = now()
  WHERE id = p_invoice_id;
END;
$$;

-- Backfill: recalculate all active invoices to fix any existing rounding discrepancies
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT id FROM public."DealerInvoices"
    WHERE deleted = false AND status <> 'void'
  LOOP
    PERFORM public.compute_invoice_totals(r.id);
  END LOOP;
END;
$$;
