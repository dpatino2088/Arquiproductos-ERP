
-- create_manufacturing_order
CREATE OR REPLACE FUNCTION create_manufacturing_order(
  p_sales_order_id uuid, p_user_id uuid,
  p_sales_order_line_id uuid DEFAULT NULL,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_so record;
  v_sol record;
  v_mo_id uuid;
  v_mo_number text;
BEGIN
  SELECT * INTO v_so FROM "SalesOrders" WHERE id = p_sales_order_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'Sales Order not found'; END IF;
  IF v_so.status NOT IN ('draft','confirmed') THEN RAISE EXCEPTION 'SO must be open to create MO (current: %)', v_so.status; END IF;

  IF p_sales_order_line_id IS NOT NULL THEN
    SELECT * INTO v_sol FROM "SalesOrderLines" WHERE id = p_sales_order_line_id AND sales_order_id = p_sales_order_id;
  END IF;

  INSERT INTO "ManufacturingOrders" (
    organization_id, sales_order_id, sales_order_line_id,
    status, mo_type, priority, dealer_id,
    product_name, quantity, created_by
  ) VALUES (
    v_so.organization_id, p_sales_order_id, p_sales_order_line_id,
    'draft', 'primary', COALESCE(v_so.priority, 'normal'), v_so.dealer_id,
    COALESCE(v_sol.description, v_sol.collection_name, 'Product'),
    COALESCE(v_sol.quantity::int, 1),
    p_user_id
  )
  RETURNING id, manufacturing_order_no INTO v_mo_id, v_mo_number;

  PERFORM _insert_timeline(v_so.organization_id, 'manufacturing_order', v_mo_id, 'created', 'Manufacturing Order created', p_user_id, p_user_name, jsonb_build_object('so_id', p_sales_order_id, 'so_number', v_so.sales_order_no));
  PERFORM _insert_timeline(v_so.organization_id, 'sales_order', p_sales_order_id, 'mo_created', 'Manufacturing Order ' || v_mo_number || ' created', p_user_id, p_user_name, jsonb_build_object('mo_id', v_mo_id, 'mo_number', v_mo_number));

  RETURN jsonb_build_object('ok', true, 'mo_id', v_mo_id, 'mo_number', v_mo_number);
END;
$$;

GRANT EXECUTE ON FUNCTION create_manufacturing_order(uuid, uuid, uuid, text) TO authenticated;

-- transition_mo_status
CREATE OR REPLACE FUNCTION transition_mo_status(p_mo_id uuid, p_new_status text, p_user_id uuid, p_user_name text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_mo record;
  v_valid boolean := false;
  v_old text;
BEGIN
  SELECT * INTO v_mo FROM "ManufacturingOrders" WHERE id = p_mo_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'MO not found'; END IF;
  v_old := v_mo.status::text;

  v_valid := (v_old = 'draft' AND p_new_status = 'planned')
          OR (v_old = 'planned' AND p_new_status = 'in_production')
          OR (v_old = 'in_production' AND p_new_status = 'quality_check')
          OR (v_old = 'quality_check' AND p_new_status = 'ready_for_pickup')
          OR (v_old = 'ready_for_pickup' AND p_new_status = 'delivered')
          OR (v_old IN ('draft','planned') AND p_new_status = 'cancelled');

  IF NOT v_valid THEN RAISE EXCEPTION 'Invalid transition: % -> %', v_old, p_new_status; END IF;

  UPDATE "ManufacturingOrders" SET
    status = p_new_status::manufacturing_order_status,
    released_at = CASE WHEN p_new_status = 'planned' THEN now() ELSE released_at END,
    production_started_at = CASE WHEN p_new_status = 'in_production' THEN now() ELSE production_started_at END,
    completed_at = CASE WHEN p_new_status = 'delivered' THEN now() ELSE completed_at END,
    delivered_at = CASE WHEN p_new_status = 'delivered' THEN now() ELSE delivered_at END,
    updated_at = now()
  WHERE id = p_mo_id;

  PERFORM _insert_timeline(v_mo.organization_id, 'manufacturing_order', p_mo_id, 'status_changed',
    'Status changed from ' || v_old || ' to ' || p_new_status, p_user_id, p_user_name,
    jsonb_build_object('from', v_old, 'to', p_new_status));

  RETURN jsonb_build_object('ok', true, 'from', v_old, 'to', p_new_status);
END;
$$;

GRANT EXECUTE ON FUNCTION transition_mo_status(uuid, text, uuid, text) TO authenticated;

-- transition_so_status
CREATE OR REPLACE FUNCTION transition_so_status(p_so_id uuid, p_new_status text, p_user_id uuid, p_user_name text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_so record;
  v_valid boolean := false;
  v_old text;
BEGIN
  SELECT * INTO v_so FROM "SalesOrders" WHERE id = p_so_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'SO not found'; END IF;
  v_old := v_so.status::text;

  v_valid := (v_old = 'draft' AND p_new_status = 'confirmed')
          OR (v_old = 'confirmed' AND p_new_status = 'on_hold')
          OR (v_old = 'on_hold' AND p_new_status = 'confirmed')
          OR (v_old = 'confirmed' AND p_new_status = 'delivered')
          OR (v_old = 'delivered' AND p_new_status = 'closed')
          OR (v_old IN ('draft','confirmed','on_hold') AND p_new_status = 'cancelled');

  IF NOT v_valid THEN RAISE EXCEPTION 'Invalid SO transition: % -> %', v_old, p_new_status; END IF;

  UPDATE "SalesOrders" SET
    status = p_new_status::sales_order_status,
    completed_at = CASE WHEN p_new_status = 'delivered' THEN now() ELSE completed_at END,
    closed_at = CASE WHEN p_new_status = 'closed' THEN now() ELSE closed_at END,
    updated_at = now()
  WHERE id = p_so_id;

  PERFORM _insert_timeline(v_so.organization_id, 'sales_order', p_so_id, 'status_changed',
    'Status changed from ' || v_old || ' to ' || p_new_status, p_user_id, p_user_name,
    jsonb_build_object('from', v_old, 'to', p_new_status));

  RETURN jsonb_build_object('ok', true, 'from', v_old, 'to', p_new_status);
END;
$$;

GRANT EXECUTE ON FUNCTION transition_so_status(uuid, text, uuid, text) TO authenticated;

-- record_payment
CREATE OR REPLACE FUNCTION record_payment(
  p_so_id uuid, p_amount numeric, p_method text,
  p_reference text, p_user_id uuid, p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_so record;
  v_new_paid numeric;
  v_new_status text;
  v_payment_id uuid;
BEGIN
  SELECT * INTO v_so FROM "SalesOrders" WHERE id = p_so_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'SO not found'; END IF;
  IF v_so.status IN ('closed','cancelled') THEN RAISE EXCEPTION 'Cannot record payment on % order', v_so.status; END IF;

  INSERT INTO "Payments" (organization_id, sales_order_id, amount, payment_method, reference_number, recorded_by)
  VALUES (v_so.organization_id, p_so_id, p_amount, p_method, p_reference, p_user_id)
  RETURNING id INTO v_payment_id;

  v_new_paid := COALESCE(v_so.amount_paid, 0) + p_amount;
  IF v_new_paid <= 0 THEN v_new_status := 'pending';
  ELSIF v_new_paid >= COALESCE(v_so.total_amount, 0) AND COALESCE(v_so.total_amount, 0) > 0 THEN v_new_status := 'paid';
  ELSE v_new_status := 'partial';
  END IF;

  UPDATE "SalesOrders" SET amount_paid = v_new_paid, payment_status = v_new_status, updated_at = now() WHERE id = p_so_id;

  PERFORM _insert_timeline(v_so.organization_id, 'sales_order', p_so_id, 'payment_recorded',
    'Payment of $' || p_amount::text || ' recorded (' || COALESCE(p_method,'') || ')',
    p_user_id, p_user_name,
    jsonb_build_object('amount', p_amount, 'method', p_method, 'reference', p_reference, 'payment_id', v_payment_id, 'new_status', v_new_status));

  RETURN jsonb_build_object('ok', true, 'payment_id', v_payment_id, 'new_paid', v_new_paid, 'payment_status', v_new_status);
END;
$$;

GRANT EXECUTE ON FUNCTION record_payment(uuid, numeric, text, text, uuid, text) TO authenticated;
;
