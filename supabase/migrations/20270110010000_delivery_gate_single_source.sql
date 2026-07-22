-- Single source of truth for the delivery gate.
--
-- Problem: the UI mixed the financial view with a separately-fetched SalesOrders
-- total (and recomputed fully_invoiced), which can drift and produce errors.
--
-- Fix: get_sales_order_delivery_gate now reads ALL financial figures from the
-- canonical view public.sales_order_financial_summary, so the server enforcement
-- and the UI share exactly one computation. It also exposes fully_invoiced,
-- total_invoiced and so_total, and makes the release rule explicit:
--   delivery_allowed = (payment_complete AND fully_invoiced) OR active_override
--
-- Note: payment_complete already implies fully_invoiced in practice (payments and
-- credits can only be applied to issued invoices), but the AND makes the
-- 100%-invoiced + 100%-paid rule explicit and robust.

SET search_path = public;

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
  v_found        boolean := false;
  v_balance      numeric(14,2) := 0;
  v_fully        boolean := false;
  v_invoiced     numeric(14,2) := 0;
  v_so_total     numeric(14,2) := 0;
BEGIN
  -- Canonical figures from the single source of truth (the view).
  SELECT true, s.balance_due, s.fully_invoiced, s.total_invoiced, s.so_total
    INTO v_found, v_balance, v_fully, v_invoiced, v_so_total
  FROM public.sales_order_financial_summary s
  WHERE s.sales_order_id = p_sales_order_id;

  IF NOT COALESCE(v_found, false) THEN
    -- No invoices exist yet: nothing invoiced. Order still owes its full total.
    SELECT COALESCE(so.total_amount, 0)::numeric(14,2)
      INTO v_so_total
    FROM public."SalesOrders" so
    WHERE so.id = p_sales_order_id
      AND so.deleted = false;

    v_so_total := COALESCE(v_so_total, 0);
    v_invoiced := 0;
    v_balance  := v_so_total;
    -- Only a zero-value order counts as fully invoiced with no invoices.
    v_fully    := (v_so_total <= 0.005);
  END IF;

  sales_order_id := p_sales_order_id;
  balance_due    := GREATEST(v_balance, 0)::numeric(14,2);
  total_invoiced := v_invoiced;
  so_total       := v_so_total;
  fully_invoiced := v_fully;
  payment_complete := (balance_due = 0);

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

  -- Release rule: 100% invoiced AND 100% paid, or an authorized override.
  delivery_allowed := (payment_complete AND fully_invoiced) OR has_active_override;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_sales_order_delivery_gate(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
