-- ============================================================
-- Invoice Status: DB-driven triggers (no frontend calculation)
-- ============================================================
-- 1. Improve compute_invoice_totals to consider DealerCreditNotes
-- 2. Add trigger on DealerCreditNotes to auto-recalc invoice status
-- 3. Persist sales_order_financial_summary view in migration
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Enhanced compute_invoice_totals
--    Now considers credit notes when computing status.
--    Separates line-total recalc from status recalc so both
--    PaymentApplications and CreditNotes changes work correctly.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.compute_invoice_totals(p_invoice_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_sub     numeric(14,2);
  v_tax     numeric(14,2);
  v_total   numeric(14,2);
  v_paid    numeric(14,2);
  v_credited numeric(14,2);
  v_covered numeric(14,2);
  v_current_status text;
  v_new_status     text;
BEGIN
  -- Recalculate line totals
  SELECT COALESCE(SUM(line_subtotal), 0),
         COALESCE(SUM(line_tax), 0),
         COALESCE(SUM(line_total), 0)
  INTO v_sub, v_tax, v_total
  FROM public."DealerInvoiceLines"
  WHERE invoice_id = p_invoice_id;

  -- Sum applied payments
  SELECT COALESCE(SUM(applied_amount), 0) INTO v_paid
  FROM public."PaymentApplications"
  WHERE invoice_id = p_invoice_id;

  -- Sum non-void credit notes
  SELECT COALESCE(SUM(amount), 0) INTO v_credited
  FROM public."DealerCreditNotes"
  WHERE invoice_id = p_invoice_id
    AND deleted = false
    AND status <> 'void';

  v_covered := v_paid + v_credited;

  -- Get current status to preserve void/draft
  SELECT status INTO v_current_status
  FROM public."DealerInvoices"
  WHERE id = p_invoice_id;

  -- Compute new status
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
$function$;

-- ────────────────────────────────────────────────────────────
-- 2. Trigger on DealerCreditNotes
--    When a credit note is created, updated, or deleted,
--    recalculate the linked invoice's status.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_credit_notes_after_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_invoice_id uuid;
BEGIN
  v_invoice_id := COALESCE(NEW.invoice_id, OLD.invoice_id);
  IF v_invoice_id IS NOT NULL THEN
    PERFORM public.compute_invoice_totals(v_invoice_id);
  END IF;
  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS trg_credit_notes_after_change ON public."DealerCreditNotes";
CREATE TRIGGER trg_credit_notes_after_change
  AFTER INSERT OR UPDATE OR DELETE ON public."DealerCreditNotes"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_credit_notes_after_change();

-- ────────────────────────────────────────────────────────────
-- 3. Trigger on DealerInvoiceLines
--    When lines change, recalculate invoice totals + status.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_invoice_lines_after_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_invoice_id uuid;
BEGIN
  v_invoice_id := COALESCE(NEW.invoice_id, OLD.invoice_id);
  IF v_invoice_id IS NOT NULL THEN
    PERFORM public.compute_invoice_totals(v_invoice_id);
  END IF;
  RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS trg_invoice_lines_after_change ON public."DealerInvoiceLines";
CREATE TRIGGER trg_invoice_lines_after_change
  AFTER INSERT OR UPDATE OR DELETE ON public."DealerInvoiceLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_invoice_lines_after_change();

-- ────────────────────────────────────────────────────────────
-- 4. Persist sales_order_financial_summary view
--    Improved: considers credit notes in total_paid calculation
-- ────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.sales_order_financial_summary CASCADE;
CREATE VIEW public.sales_order_financial_summary AS
WITH pa_totals AS (
  SELECT
    invoice_id,
    SUM(applied_amount) AS applied
  FROM public."PaymentApplications"
  GROUP BY invoice_id
),
cn_totals AS (
  SELECT
    invoice_id,
    SUM(amount) AS credited
  FROM public."DealerCreditNotes"
  WHERE deleted = false AND status <> 'void'
  GROUP BY invoice_id
)
SELECT
  di.sales_order_id,
  di.organization_id,
  di.dealer_id,
  COUNT(DISTINCT di.id)::integer AS invoice_count,
  COALESCE(SUM(di.total), 0)::numeric(14,2) AS total_invoiced,
  COALESCE(SUM(pa.applied), 0)::numeric(14,2) AS total_paid,
  GREATEST(
    COALESCE(SUM(di.total), 0) - COALESCE(SUM(pa.applied), 0) - COALESCE(SUM(cn.credited), 0),
    0
  )::numeric(14,2) AS balance_due,
  CASE
    WHEN COALESCE(SUM(di.total), 0) = 0 THEN 'none'
    WHEN COALESCE(SUM(pa.applied), 0) + COALESCE(SUM(cn.credited), 0) <= 0 THEN 'issued'
    WHEN COALESCE(SUM(pa.applied), 0) + COALESCE(SUM(cn.credited), 0)
         < COALESCE(SUM(di.total), 0) - 0.005 THEN 'partial'
    ELSE 'paid'
  END AS invoice_status,
  (SELECT di2.id
   FROM public."DealerInvoices" di2
   WHERE di2.sales_order_id = di.sales_order_id
     AND di2.deleted = false AND di2.status <> 'void'
   ORDER BY di2.created_at DESC LIMIT 1
  ) AS latest_invoice_id,
  (SELECT di2.invoice_number
   FROM public."DealerInvoices" di2
   WHERE di2.sales_order_id = di.sales_order_id
     AND di2.deleted = false AND di2.status <> 'void'
   ORDER BY di2.created_at DESC LIMIT 1
  ) AS latest_invoice_number
FROM public."DealerInvoices" di
LEFT JOIN pa_totals pa ON pa.invoice_id = di.id
LEFT JOIN cn_totals cn ON cn.invoice_id = di.id
WHERE di.sales_order_id IS NOT NULL
  AND di.deleted = false
  AND di.status <> 'void'
GROUP BY di.sales_order_id, di.organization_id, di.dealer_id;

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
