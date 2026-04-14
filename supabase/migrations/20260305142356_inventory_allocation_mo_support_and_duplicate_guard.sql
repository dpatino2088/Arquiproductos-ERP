-- ============================================================
-- 1) Add manufacturing_order_id to InventoryAllocations
-- ============================================================
ALTER TABLE public."InventoryAllocations"
  ADD COLUMN IF NOT EXISTS manufacturing_order_id uuid NULL
  REFERENCES public."ManufacturingOrders"(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_inv_alloc_mo
  ON public."InventoryAllocations"(manufacturing_order_id)
  WHERE manufacturing_order_id IS NOT NULL;

-- Make sales_order_id nullable (allocations can be MO-only)
ALTER TABLE public."InventoryAllocations"
  ALTER COLUMN sales_order_id DROP NOT NULL;

-- ============================================================
-- 2) Update inventory_allocated view to include MO dimension
-- ============================================================
CREATE OR REPLACE VIEW public.inventory_allocated AS
SELECT
  organization_id,
  warehouse_id,
  catalog_item_id,
  SUM(allocated_qty) AS allocated_qty
FROM "InventoryAllocations"
WHERE status = 'reserved'
GROUP BY organization_id, warehouse_id, catalog_item_id;

-- Per-MO allocation view
CREATE OR REPLACE VIEW public.inventory_allocated_by_mo AS
SELECT
  organization_id,
  warehouse_id,
  catalog_item_id,
  manufacturing_order_id,
  SUM(allocated_qty) AS allocated_qty
FROM "InventoryAllocations"
WHERE status = 'reserved'
  AND manufacturing_order_id IS NOT NULL
GROUP BY organization_id, warehouse_id, catalog_item_id, manufacturing_order_id;

-- ============================================================
-- 3) RPC: allocate_inventory_to_mo
-- ============================================================
CREATE OR REPLACE FUNCTION public.allocate_inventory_to_mo(
  p_org_id uuid,
  p_warehouse_id uuid,
  p_manufacturing_order_id uuid,
  p_items jsonb  -- [{"catalog_item_id": "...", "qty": 5}]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_item record;
  v_on_hand numeric;
  v_already_allocated numeric;
  v_available numeric;
  v_alloc_qty numeric;
  v_results jsonb := '[]'::jsonb;
  v_so_id uuid;
BEGIN
  -- Get SO from MO
  SELECT sales_order_id INTO v_so_id
  FROM "ManufacturingOrders"
  WHERE id = p_manufacturing_order_id AND deleted = false;

  FOR v_item IN
    SELECT
      (elem ->> 'catalog_item_id')::uuid AS catalog_item_id,
      (elem ->> 'qty')::numeric AS qty
    FROM jsonb_array_elements(p_items) AS elem
  LOOP
    -- Current on_hand
    SELECT COALESCE(SUM(ib.on_hand), 0) INTO v_on_hand
    FROM "InventoryBalances" ib
    WHERE ib.organization_id = p_org_id
      AND ib.warehouse_id = p_warehouse_id
      AND ib.catalog_item_id = v_item.catalog_item_id;

    -- Already allocated (all MOs/SOs)
    SELECT COALESCE(SUM(ia.allocated_qty), 0) INTO v_already_allocated
    FROM "InventoryAllocations" ia
    WHERE ia.organization_id = p_org_id
      AND ia.warehouse_id = p_warehouse_id
      AND ia.catalog_item_id = v_item.catalog_item_id
      AND ia.status = 'reserved';

    v_available := v_on_hand - v_already_allocated;
    v_alloc_qty := LEAST(v_item.qty, GREATEST(0, v_available));

    IF v_alloc_qty > 0 THEN
      INSERT INTO "InventoryAllocations" (
        organization_id, warehouse_id, catalog_item_id,
        manufacturing_order_id, sales_order_id,
        allocated_qty, status, source
      ) VALUES (
        p_org_id, p_warehouse_id, v_item.catalog_item_id,
        p_manufacturing_order_id, v_so_id,
        v_alloc_qty, 'reserved', 'auto'
      );
    END IF;

    v_results := v_results || jsonb_build_object(
      'catalog_item_id', v_item.catalog_item_id,
      'requested', v_item.qty,
      'allocated', v_alloc_qty,
      'available_before', v_available,
      'ok', v_alloc_qty >= v_item.qty
    );
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'results', v_results);
END;
$$;

-- ============================================================
-- 4) RPC: release_mo_allocation
-- ============================================================
CREATE OR REPLACE FUNCTION public.release_mo_allocation(
  p_manufacturing_order_id uuid,
  p_catalog_item_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_released int;
BEGIN
  UPDATE "InventoryAllocations"
  SET status = 'released', released_at = now(), updated_at = now()
  WHERE manufacturing_order_id = p_manufacturing_order_id
    AND status = 'reserved'
    AND (p_catalog_item_id IS NULL OR catalog_item_id = p_catalog_item_id);

  GET DIAGNOSTICS v_released = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'released_count', v_released);
END;
$$;

-- ============================================================
-- 5) RPC: reassign_allocation (move from one MO to another)
-- ============================================================
CREATE OR REPLACE FUNCTION public.reassign_allocation(
  p_allocation_id uuid,
  p_new_manufacturing_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_alloc record;
  v_new_so_id uuid;
BEGIN
  SELECT * INTO v_alloc
  FROM "InventoryAllocations"
  WHERE id = p_allocation_id AND status = 'reserved';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Allocation not found or already released');
  END IF;

  SELECT sales_order_id INTO v_new_so_id
  FROM "ManufacturingOrders"
  WHERE id = p_new_manufacturing_order_id AND deleted = false;

  UPDATE "InventoryAllocations"
  SET manufacturing_order_id = p_new_manufacturing_order_id,
      sales_order_id = COALESCE(v_new_so_id, sales_order_id),
      updated_at = now()
  WHERE id = p_allocation_id;

  RETURN jsonb_build_object('ok', true, 'allocation_id', p_allocation_id, 'new_mo_id', p_new_manufacturing_order_id);
END;
$$;

-- ============================================================
-- 6) Guard: prevent duplicate MOs for same SO when sales_order_line_id is null
-- We use a partial unique index: only one MO per SO when line_id is null
-- ============================================================
-- NOTE: Not adding a strict unique constraint since the user already has
-- legitimate duplicate MOs. Instead we'll guard in the RPC.

-- Update create_manufacturing_order to check for existing active MO
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

  -- Guard against duplicate MOs
  IF p_sales_order_line_id IS NOT NULL THEN
    SELECT id INTO v_existing_mo_id
    FROM "ManufacturingOrders"
    WHERE sales_order_id = p_sales_order_id
      AND sales_order_line_id = p_sales_order_line_id
      AND deleted = false
      AND status NOT IN ('cancelled')
    LIMIT 1;
    IF v_existing_mo_id IS NOT NULL THEN
      RAISE EXCEPTION 'An active Manufacturing Order already exists for this SO line';
    END IF;
  ELSE
    SELECT id INTO v_existing_mo_id
    FROM "ManufacturingOrders"
    WHERE sales_order_id = p_sales_order_id
      AND sales_order_line_id IS NULL
      AND deleted = false
      AND status NOT IN ('cancelled')
    LIMIT 1;
    IF v_existing_mo_id IS NOT NULL THEN
      RAISE EXCEPTION 'A global Manufacturing Order already exists for this SO. Use per-line MO creation instead.';
    END IF;
  END IF;

  v_product_name := 'Product';
  v_quantity := 1;
  IF p_sales_order_line_id IS NOT NULL THEN
    SELECT *
    INTO v_sol
    FROM "SaleOrderLines"
    WHERE id = p_sales_order_line_id
      AND sales_order_id = p_sales_order_id;
    IF FOUND THEN
      v_product_name := COALESCE(v_sol.description, v_sol.collection_name, 'Product');
      v_quantity := COALESCE(v_sol.quantity::int, 1);
    END IF;
  END IF;

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
    p_sales_order_line_id,
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
;
