-- ============================================================================
-- One default MO per Sales Order
-- - Converting an SO to manufacturing must create only one active MO.
-- - If an active MO already exists, return it (idempotent behavior).
-- - SO line split can be handled later from Manufacturing by operators/managers.
-- ============================================================================

SET search_path = public;

CREATE OR REPLACE FUNCTION public.create_manufacturing_order(
  p_sales_order_id uuid,
  p_user_id uuid,
  p_sales_order_line_id uuid DEFAULT NULL::uuid,
  p_user_name text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_so record;
  v_sol record;
  v_existing_mo record;
  v_mo_id uuid;
  v_mo_number text;
  v_product_name text;
  v_quantity int;
  v_bom_result jsonb;
  v_bom_ok boolean;
  v_bom_errors text[];
BEGIN
  -- Serialize by SO to avoid concurrent duplicate creation.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_sales_order_id::text, 0));

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

  -- One active MO per SO by default.
  SELECT mo.id, mo.manufacturing_order_no, mo.status
  INTO v_existing_mo
  FROM "ManufacturingOrders" mo
  WHERE mo.sales_order_id = p_sales_order_id
    AND mo.deleted = false
    AND mo.status::text <> 'cancelled'
  ORDER BY mo.created_at DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'ok', true,
      'existing', true,
      'mo_id', v_existing_mo.id,
      'mo_number', v_existing_mo.manufacturing_order_no,
      'status', v_existing_mo.status
    );
  END IF;

  -- Anchor line for summary fields only; BOM generation still uses all MO lines.
  IF p_sales_order_line_id IS NOT NULL THEN
    SELECT *
    INTO v_sol
    FROM "SaleOrderLines"
    WHERE id = p_sales_order_line_id
      AND sales_order_id = p_sales_order_id
      AND deleted = false;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Selected Sales Order line is invalid or deleted';
    END IF;
  ELSE
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
    v_sol.id,
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
    'existing', false,
    'mo_id', v_mo_id,
    'mo_number', v_mo_number,
    'bom', v_bom_result
  );
END;
$function$;

