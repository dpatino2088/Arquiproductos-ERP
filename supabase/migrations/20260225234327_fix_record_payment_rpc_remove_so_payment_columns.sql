
CREATE OR REPLACE FUNCTION public.record_payment(
  p_so_id uuid, p_amount numeric, p_method text, p_reference text,
  p_user_id uuid, p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_so record;
  v_payment_id uuid;
  v_user_display text;
BEGIN
  SELECT * INTO v_so FROM "SalesOrders" WHERE id = p_so_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'SO not found'; END IF;
  IF v_so.status IN ('closed','cancelled') THEN
    RAISE EXCEPTION 'Cannot record payment on % order', v_so.status;
  END IF;
  IF COALESCE(v_so.total_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'Cannot record payment — Sales Order has no total amount';
  END IF;
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Payment amount must be positive';
  END IF;

  SELECT display_name INTO v_user_display FROM "AppUsers" WHERE id = p_user_id;

  INSERT INTO "Payments" (
    organization_id, dealer_id, sales_order_id,
    amount, payment_method, reference_number,
    recorded_by, recorded_by_name
  )
  VALUES (
    v_so.organization_id, v_so.dealer_id, p_so_id,
    p_amount, p_method, p_reference,
    p_user_id, COALESCE(v_user_display, p_user_name)
  )
  RETURNING id INTO v_payment_id;

  PERFORM _insert_timeline(
    v_so.organization_id, 'sales_order', p_so_id, 'payment_recorded',
    'Payment of $' || p_amount::text || ' recorded (' || COALESCE(p_method,'') || ')',
    p_user_id, COALESCE(v_user_display, p_user_name),
    jsonb_build_object('amount', p_amount, 'method', p_method, 'reference', p_reference, 'payment_id', v_payment_id)
  );

  RETURN jsonb_build_object('ok', true, 'payment_id', v_payment_id);
END;
$$;
;
