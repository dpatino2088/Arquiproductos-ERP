-- Enforce the production gate where the Manufacturing Order is actually created.
--
-- Until now create_manufacturing_order validated structure only (open SO, no
-- active MO, at least one line, BOM generates), so the deposit rule could be
-- skipped by releasing from the Manufacturing order list or by calling the RPC
-- directly. Everything else in this function is unchanged.

CREATE OR REPLACE FUNCTION public.create_manufacturing_order(p_sales_order_id uuid, p_user_id uuid, p_sales_order_line_id uuid DEFAULT NULL::uuid, p_user_name text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_so record;
  v_sol record;
  v_mo_id uuid;
  v_mo_number text;
  v_product_name text;
  v_quantity int;
  v_bom_result jsonb;
  v_bom_ok boolean;
  v_bom_errors text[];
  v_existing_mo_id uuid;
  v_gate record;
BEGIN
  SELECT *
  INTO v_so
  FROM "SalesOrders"
  WHERE id = p_sales_order_id
    AND deleted = false;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sales Order not found';
  END IF;

  IF v_so.status NOT IN ('draft', 'confirmed') THEN
    RAISE EXCEPTION 'SO must be open to create MO (current: %)', v_so.status;
  END IF;

  -- 1:1 rule: only 1 active MO per SO
  SELECT id INTO v_existing_mo_id
  FROM "ManufacturingOrders"
  WHERE sales_order_id = p_sales_order_id
    AND deleted = false
    AND status != 'cancelled'
  LIMIT 1;

  IF v_existing_mo_id IS NOT NULL THEN
    RAISE EXCEPTION 'An active Manufacturing Order already exists for this SO. Use the existing MO lines instead.';
  END IF;

  -- Deposit gate: collected money, a settled balance, or an authorized override.
  SELECT * INTO v_gate
  FROM public.get_sales_order_production_gate(p_sales_order_id);

  IF NOT COALESCE(v_gate.production_allowed, false) THEN
    RAISE EXCEPTION 'Production requires a deposit of % but only % was received. Record the payment or authorize a financial override in Financials.',
      TO_CHAR(v_gate.required_deposit, 'FM999999990.00'),
      TO_CHAR(v_gate.total_paid, 'FM999999990.00');
  END IF;

  SELECT *
  INTO v_sol
  FROM "SaleOrderLines"
  WHERE sales_order_id = p_sales_order_id
    AND deleted = false
  ORDER BY line_number ASC NULLS LAST, created_at ASC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sales Order must have at least one active line before creating a Manufacturing Order';
  END IF;

  v_product_name := COALESCE(v_sol.description, v_sol.collection_name, 'Product');
  v_quantity := COALESCE(v_sol.quantity::int, 1);

  INSERT INTO "ManufacturingOrders" (
    organization_id,
    sales_order_id,
    sales_order_line_id,
    status,
    mo_type,
    priority,
    dealer_id,
    product_name,
    quantity,
    created_by
  ) VALUES (
    v_so.organization_id,
    p_sales_order_id,
    NULL,
    'draft',
    'primary',
    COALESCE(v_so.priority, 'normal'),
    v_so.dealer_id,
    v_product_name,
    v_quantity,
    p_user_id
  )
  RETURNING id, manufacturing_order_no
  INTO v_mo_id, v_mo_number;

  SELECT public.generate_bom_for_manufacturing_order(v_mo_id)
  INTO v_bom_result;

  v_bom_ok := COALESCE((v_bom_result ->> 'ok')::boolean, false);
  IF jsonb_typeof(v_bom_result -> 'errors') = 'array' THEN
    SELECT COALESCE(array_agg(value), ARRAY[]::text[])
    INTO v_bom_errors
    FROM jsonb_array_elements_text(v_bom_result -> 'errors');
  ELSE
    v_bom_errors := ARRAY[]::text[];
  END IF;

  IF v_bom_ok = false OR COALESCE(array_length(v_bom_errors, 1), 0) > 0 THEN
    RAISE EXCEPTION 'Failed to generate BOM for MO %: %',
      v_mo_number,
      COALESCE(array_to_string(v_bom_errors, '; '), 'unknown error');
  END IF;

  PERFORM _insert_timeline(
    v_so.organization_id,
    'manufacturing_order',
    v_mo_id,
    'created',
    'Manufacturing Order created',
    p_user_id,
    p_user_name,
    jsonb_build_object('so_id', p_sales_order_id, 'so_number', v_so.sales_order_no)
  );

  PERFORM _insert_timeline(
    v_so.organization_id,
    'sales_order',
    p_sales_order_id,
    'mo_created',
    'Manufacturing Order ' || v_mo_number || ' created',
    p_user_id,
    p_user_name,
    jsonb_build_object('mo_id', v_mo_id, 'mo_number', v_mo_number)
  );

  RETURN jsonb_build_object(
    'ok', true,
    'mo_id', v_mo_id,
    'mo_number', v_mo_number,
    'bom', v_bom_result
  );
END;
$function$;

NOTIFY pgrst, 'reload schema';
