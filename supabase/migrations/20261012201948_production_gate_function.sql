-- Production gate: one place that decides whether a Sales Order can go to production.
--
-- The 15% deposit rule lived only in SalesOrderDetail.tsx, which left three holes:
-- the Manufacturing order list released production without checking it, a direct
-- RPC call ignored it entirely, and an override authorized in Financials released
-- dispatch but never production.
--
-- This function owns the rule so the UI and create_manufacturing_order read the
-- same numbers, mirroring what get_sales_order_delivery_gate does for dispatch.

SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_sales_order_production_gate(p_sales_order_id uuid)
RETURNS TABLE (
  sales_order_id uuid,
  so_total numeric(14,2),
  total_paid numeric(14,2),
  min_deposit_pct numeric,
  required_deposit numeric(14,2),
  deposit_met boolean,
  financials_settled boolean,
  has_active_override boolean,
  production_allowed boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  -- Single definition of the deposit requirement. The UI reads it from here.
  v_pct      numeric := 0.15;
  v_found    boolean := false;
  v_paid     numeric(14,2) := 0;
  v_total    numeric(14,2) := 0;
  v_settled  boolean := false;
  v_override boolean := false;
BEGIN
  -- The override lookup stays owned by the delivery gate so both gates always
  -- agree on what an authorized override is.
  SELECT COALESCE(g.has_active_override, false)
    INTO v_override
  FROM public.get_sales_order_delivery_gate(p_sales_order_id) g;

  SELECT true, COALESCE(s.total_paid, 0), COALESCE(s.so_total, 0),
         COALESCE(s.delivery_financials_ok, false)
    INTO v_found, v_paid, v_total, v_settled
  FROM public.sales_order_financial_summary s
  WHERE s.sales_order_id = p_sales_order_id;

  IF NOT COALESCE(v_found, false) THEN
    -- No invoices yet, so nothing can have been collected against this order.
    SELECT COALESCE(so.total_amount, 0)::numeric(14,2)
      INTO v_total
    FROM public."SalesOrders" so
    WHERE so.id = p_sales_order_id
      AND so.deleted = false;

    v_total   := COALESCE(v_total, 0);
    v_paid    := 0;
    v_settled := (v_total <= 0.005);
  END IF;

  sales_order_id      := p_sales_order_id;
  so_total            := v_total;
  total_paid          := v_paid;
  min_deposit_pct     := v_pct;
  required_deposit    := ROUND(v_total * v_pct, 2);
  financials_settled  := v_settled;
  has_active_override := v_override;

  -- A zero-value order has nothing to collect, and an order with no balance left
  -- is settled even when credit notes (e.g. tax retentions) cleared it instead of
  -- cash, so neither should sit blocked waiting for a deposit.
  deposit_met := (v_total <= 0.005)
                 OR v_settled
                 OR (v_paid + 0.005 >= required_deposit);

  production_allowed := deposit_met OR v_override;
  RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_sales_order_production_gate(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
