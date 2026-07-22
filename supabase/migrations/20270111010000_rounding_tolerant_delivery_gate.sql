-- Rounding-tolerant delivery gate.
--
-- Problem observed on SO-00100:
--   * SO total          = 1463.26
--   * Invoiced (2 inv.)  = 1463.25  (731.62 + 731.63)  -> 1 cent short
--   * Paid              = 1462.90
--   * ar_balance         = 0.35   (the real unpaid amount on INV-00100)
--
-- The 1-cent gap comes from per-invoice 7% tax rounding when an order is split
-- into partial invoices. Two bugs resulted:
--   1) fully_invoiced was false because the tolerance (0.005) was tighter than a
--      penny, so the order looked "not fully invoiced".
--   2) The gate measured payment against the SO total, so the un-invoiced penny
--      became IMPOSSIBLE to pay (payments only apply to issued invoices) and the
--      order could never reach balance 0.
--
-- Fix (industry-standard): tolerate sub-cent rounding that accumulates across
-- partial invoices, and gate delivery on:
--     100% invoiced (within rounding)  AND  all issued invoices paid (ar_balance ~ 0)
-- The financial readiness is computed once in the view (delivery_financials_ok)
-- and the server gate + every UI reads that single flag.
--
-- Tolerance = LEAST(0.05, 0.005 + 0.01 * invoice_count): up to one cent of drift
-- per invoice, capped at 5 cents so genuine shortfalls (e.g. $0.35) still block.

SET search_path = public;

CREATE OR REPLACE VIEW public.sales_order_financial_summary AS
WITH pa_totals AS (
  SELECT "PaymentApplications".invoice_id,
         sum("PaymentApplications".applied_amount) AS applied
  FROM "PaymentApplications"
  GROUP BY "PaymentApplications".invoice_id
), cn_totals AS (
  SELECT "DealerCreditNotes".invoice_id,
         sum("DealerCreditNotes".amount) AS credited
  FROM "DealerCreditNotes"
  WHERE "DealerCreditNotes".deleted = false
    AND "DealerCreditNotes".status <> 'void'::text
  GROUP BY "DealerCreditNotes".invoice_id
)
SELECT di.sales_order_id,
  di.organization_id,
  di.dealer_id,
  count(DISTINCT di.id)::integer AS invoice_count,
  COALESCE(sum(di.total), 0::numeric)::numeric(14,2) AS total_invoiced,
  COALESCE(sum(pa.applied), 0::numeric)::numeric(14,2) AS total_paid,
  -- SO-based balance: what still must be collected on the whole order.
  GREATEST(
    COALESCE(max(so.total_amount), 0::numeric)
    - COALESCE(sum(pa.applied), 0::numeric)
    - COALESCE(sum(cn.credited), 0::numeric),
    0::numeric
  )::numeric(14,2) AS balance_due,
  CASE
    WHEN COALESCE(sum(di.total), 0::numeric) = 0::numeric THEN 'none'::text
    WHEN (COALESCE(sum(pa.applied), 0::numeric) + COALESCE(sum(cn.credited), 0::numeric)) <= 0::numeric THEN 'issued'::text
    WHEN (COALESCE(sum(pa.applied), 0::numeric) + COALESCE(sum(cn.credited), 0::numeric)) < (COALESCE(sum(di.total), 0::numeric) - 0.005) THEN 'partial'::text
    ELSE 'paid'::text
  END AS invoice_status,
  ( SELECT di2.id
      FROM "DealerInvoices" di2
     WHERE di2.sales_order_id = di.sales_order_id AND di2.deleted = false AND di2.status <> 'void'::text
     ORDER BY di2.created_at DESC
     LIMIT 1) AS latest_invoice_id,
  ( SELECT di2.invoice_number
      FROM "DealerInvoices" di2
     WHERE di2.sales_order_id = di.sales_order_id AND di2.deleted = false AND di2.status <> 'void'::text
     ORDER BY di2.created_at DESC
     LIMIT 1) AS latest_invoice_number,
  COALESCE(max(so.total_amount), 0::numeric)::numeric(14,2) AS so_total,
  COALESCE(sum(cn.credited), 0::numeric)::numeric(14,2) AS total_credited,
  GREATEST(COALESCE(max(so.total_amount), 0::numeric) - COALESCE(sum(di.total), 0::numeric), 0::numeric)::numeric(14,2) AS total_uninvoiced,
  -- Fully invoiced within rounding tolerance (penny drift per partial invoice).
  (
    (COALESCE(max(so.total_amount), 0::numeric) - COALESCE(sum(di.total), 0::numeric))
    <= LEAST(0.05, 0.005 + 0.01 * count(DISTINCT di.id))
  ) AS fully_invoiced,
  -- Invoice-only (AR) balance: outstanding on ISSUED invoices (what is collectable).
  GREATEST(
    COALESCE(sum(di.total), 0::numeric)
    - COALESCE(sum(pa.applied), 0::numeric)
    - COALESCE(sum(cn.credited), 0::numeric),
    0::numeric
  )::numeric(14,2) AS ar_balance,
  -- Financial readiness for delivery (single source of truth):
  --   fully invoiced (within rounding) AND all issued invoices settled (within rounding).
  (
    (
      (COALESCE(max(so.total_amount), 0::numeric) - COALESCE(sum(di.total), 0::numeric))
      <= LEAST(0.05, 0.005 + 0.01 * count(DISTINCT di.id))
    )
    AND
    (
      (COALESCE(sum(di.total), 0::numeric)
       - COALESCE(sum(pa.applied), 0::numeric)
       - COALESCE(sum(cn.credited), 0::numeric))
      <= LEAST(0.05, 0.005 + 0.01 * count(DISTINCT di.id))
    )
  ) AS delivery_financials_ok
FROM "DealerInvoices" di
  LEFT JOIN pa_totals pa ON pa.invoice_id = di.id
  LEFT JOIN cn_totals cn ON cn.invoice_id = di.id
  LEFT JOIN "SalesOrders" so ON so.id = di.sales_order_id
WHERE di.sales_order_id IS NOT NULL AND di.deleted = false AND di.status <> 'void'::text
GROUP BY di.sales_order_id, di.organization_id, di.dealer_id;

-- Rewrite the gate to consume the view's readiness flag and report the
-- collectable (AR) balance, so an un-invoiced rounding penny can never block.
DROP FUNCTION IF EXISTS public.get_sales_order_delivery_gate(uuid);
CREATE OR REPLACE FUNCTION public.get_sales_order_delivery_gate(p_sales_order_id uuid)
RETURNS TABLE (
  sales_order_id uuid,
  balance_due numeric(14,2),
  payment_complete boolean,
  has_active_override boolean,
  active_override_id uuid,
  delivery_allowed boolean,
  fully_invoiced boolean,
  total_invoiced numeric(14,2),
  so_total numeric(14,2)
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_found      boolean := false;
  v_ar         numeric(14,2) := 0;
  v_fully      boolean := false;
  v_ok         boolean := false;
  v_invoiced   numeric(14,2) := 0;
  v_so_total   numeric(14,2) := 0;
  v_count      integer := 0;
  v_tol        numeric := 0.005;
BEGIN
  SELECT true, s.ar_balance, s.fully_invoiced, s.delivery_financials_ok,
         s.total_invoiced, s.so_total, s.invoice_count
    INTO v_found, v_ar, v_fully, v_ok, v_invoiced, v_so_total, v_count
  FROM public.sales_order_financial_summary s
  WHERE s.sales_order_id = p_sales_order_id;

  IF NOT COALESCE(v_found, false) THEN
    -- No invoices exist yet: nothing invoiced, nothing collectable on invoices.
    SELECT COALESCE(so.total_amount, 0)::numeric(14,2)
      INTO v_so_total
    FROM public."SalesOrders" so
    WHERE so.id = p_sales_order_id
      AND so.deleted = false;

    v_so_total := COALESCE(v_so_total, 0);
    v_invoiced := 0;
    v_ar       := 0;
    v_count    := 0;
    v_fully    := (v_so_total <= 0.005);
    v_ok       := v_fully;  -- a zero-value order is trivially ready
  END IF;

  v_tol := LEAST(0.05, 0.005 + 0.01 * GREATEST(v_count, 1));

  sales_order_id := p_sales_order_id;
  -- Report the collectable outstanding on issued invoices (immune to the
  -- un-invoiced rounding penny). This is the amount that must still be paid.
  balance_due      := GREATEST(v_ar, 0)::numeric(14,2);
  total_invoiced   := v_invoiced;
  so_total         := v_so_total;
  fully_invoiced   := v_fully;
  payment_complete := (v_ar <= v_tol);

  SELECT EXISTS (
    SELECT 1 FROM public."SalesOrderDeliveryOverrides" o
    WHERE o.sales_order_id = p_sales_order_id
      AND o.status = 'active' AND o.deleted = false
  ) INTO has_active_override;

  SELECT o.id INTO active_override_id
  FROM public."SalesOrderDeliveryOverrides" o
  WHERE o.sales_order_id = p_sales_order_id
    AND o.status = 'active' AND o.deleted = false
  ORDER BY o.created_at DESC
  LIMIT 1;

  -- Release rule: 100% invoiced AND all issued invoices paid (within rounding),
  -- or an authorized override.
  delivery_allowed := COALESCE(v_ok, false) OR has_active_override;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_sales_order_delivery_gate(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
