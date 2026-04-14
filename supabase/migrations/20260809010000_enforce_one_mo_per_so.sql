-- Enforce 1:1 SO → MO relationship.
-- Each Sales Order can have at most 1 active (non-cancelled, non-deleted) Manufacturing Order.
-- All SO Lines become MO Lines within that single MO.

-- 1. Unique partial index: only 1 active MO per SO
CREATE UNIQUE INDEX IF NOT EXISTS uq_one_active_mo_per_so
  ON public."ManufacturingOrders" (sales_order_id)
  WHERE deleted = false AND status != 'cancelled';

-- 2. Clear legacy sales_order_line_id on MO header (link lives in MOLs, not MO)
UPDATE public."ManufacturingOrders"
SET sales_order_line_id = NULL, updated_at = now()
WHERE sales_order_line_id IS NOT NULL;

-- 3. Updated create_manufacturing_order: enforces 1:1 rule, sets sales_order_line_id = NULL
CREATE OR REPLACE FUNCTION public.create_manufacturing_order(
  p_sales_order_id uuid,
  p_user_id uuid,
  p_sales_order_line_id uuid DEFAULT NULL,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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

  SELECT id INTO v_existing_mo_id
  FROM "ManufacturingOrders"
  WHERE sales_order_id = p_sales_order_id
    AND deleted = false
    AND status != 'cancelled'
  LIMIT 1;

  IF v_existing_mo_id IS NOT NULL THEN
    RAISE EXCEPTION 'An active Manufacturing Order already exists for this SO. Use the existing MO lines instead.';
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
$$;

-- 4. Simplified MO → SO status trigger (1:1 model)
CREATE OR REPLACE FUNCTION public.trg_mo_status_propagate_to_so()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_so_id        uuid;
  v_so_status    text;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  v_so_id := NEW.sales_order_id;
  IF v_so_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT status INTO v_so_status
  FROM "SalesOrders"
  WHERE id = v_so_id AND deleted = false;

  IF v_so_status IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'in_production'
     AND v_so_status IN ('draft', 'confirmed', 'on_hold') THEN
    UPDATE "SalesOrders"
    SET status = 'in_production', updated_at = now()
    WHERE id = v_so_id AND deleted = false;
    RETURN NEW;
  END IF;

  IF NEW.status = 'ready_for_pickup'
     AND v_so_status NOT IN ('delivered', 'closed') THEN
    UPDATE "SalesOrders"
    SET status = 'ready_for_delivery', updated_at = now()
    WHERE id = v_so_id AND deleted = false;
    RETURN NEW;
  END IF;

  IF NEW.status IN ('delivered', 'completed')
     AND v_so_status <> 'delivered' THEN
    UPDATE "SalesOrders"
    SET status = 'delivered', updated_at = now()
    WHERE id = v_so_id AND deleted = false;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;
