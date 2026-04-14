-- ============================================================================
-- Auto-sync MOL to materials_ready after allocation changes
-- Goal:
-- - Keep Reviewed as procurement-driving status
-- - Remove need for manual "Confirm -> Material Ready" interaction
-- - Promote reviewed/confirmed lines to materials_ready automatically
--   when allocation-based readiness is fully covered
-- ============================================================================

SET search_path = public;

-- Helper: synchronize line/header statuses from allocation readiness.
CREATE OR REPLACE FUNCTION public.sync_mo_material_ready_from_allocations(
  p_mo_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_changed_lines int := 0;
  v_open_lines int := 0;
  v_header_changed int := 0;
BEGIN
  WITH ready_lines AS (
    SELECT mol.id
    FROM "ManufacturingOrderLines" mol
    JOIN public.get_mo_line_material_readiness(p_mo_id) lr
      ON lr.sales_order_line_id = mol.sales_order_line_id
    WHERE mol.manufacturing_order_id = p_mo_id
      AND mol.deleted = false
      AND mol.status IN ('reviewed', 'confirmed')
      AND lr.readiness_status = 'ok'
  )
  UPDATE "ManufacturingOrderLines" mol
  SET status = 'materials_ready',
      updated_at = now()
  FROM ready_lines rl
  WHERE mol.id = rl.id;

  GET DIAGNOSTICS v_changed_lines = ROW_COUNT;

  SELECT count(*)
  INTO v_open_lines
  FROM "ManufacturingOrderLines"
  WHERE manufacturing_order_id = p_mo_id
    AND deleted = false
    AND status NOT IN ('materials_ready', 'in_production', 'completed', 'cancelled');

  IF COALESCE(v_open_lines, 0) = 0 THEN
    UPDATE "ManufacturingOrders"
    SET status = 'materials_ready'::manufacturing_order_status,
        updated_at = now()
    WHERE id = p_mo_id
      AND deleted = false
      AND status::text IN ('confirmed', 'procurement');
    GET DIAGNOSTICS v_header_changed = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'line_updates', v_changed_lines,
    'mo_updated', v_header_changed > 0
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_mo_material_ready_from_allocations(uuid) TO authenticated;

-- Allocation RPC: after allocation, auto-sync line/header statuses.
CREATE OR REPLACE FUNCTION public.allocate_inventory_to_mo(
  p_org_id uuid,
  p_warehouse_id uuid,
  p_manufacturing_order_id uuid,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item record;
  v_on_hand numeric;
  v_already_allocated numeric;
  v_available numeric;
  v_alloc_qty numeric;
  v_results jsonb := '[]'::jsonb;
  v_so_id uuid;
  v_sync jsonb;
BEGIN
  SELECT sales_order_id INTO v_so_id
  FROM "ManufacturingOrders"
  WHERE id = p_manufacturing_order_id AND deleted = false;

  FOR v_item IN
    SELECT
      (elem ->> 'catalog_item_id')::uuid AS catalog_item_id,
      (elem ->> 'qty')::numeric AS qty
    FROM jsonb_array_elements(p_items) AS elem
  LOOP
    SELECT COALESCE(SUM(ib.on_hand), 0) INTO v_on_hand
    FROM "InventoryBalances" ib
    WHERE ib.organization_id = p_org_id
      AND ib.warehouse_id = p_warehouse_id
      AND ib.catalog_item_id = v_item.catalog_item_id;

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

  v_sync := public.sync_mo_material_ready_from_allocations(p_manufacturing_order_id);

  RETURN jsonb_build_object(
    'ok', true,
    'results', v_results,
    'sync', v_sync
  );
END;
$$;

-- PO receive readiness hook: reuse same sync logic for linked MOs.
CREATE OR REPLACE FUNCTION public.check_mo_readiness_after_po_receive(p_po_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo_id uuid;
  v_sync jsonb;
  v_total_line_updates int := 0;
  v_total_mo_updates int := 0;
BEGIN
  FOR v_mo_id IN
    SELECT DISTINCT pomo.manufacturing_order_id
    FROM "PurchaseOrderManufacturingOrders" pomo
    JOIN "ManufacturingOrders" mo ON mo.id = pomo.manufacturing_order_id AND mo.deleted = false
    WHERE pomo.purchase_order_id = p_po_id
      AND pomo.deleted = false
      AND mo.status::text IN ('confirmed', 'procurement', 'materials_ready')
  LOOP
    v_sync := public.sync_mo_material_ready_from_allocations(v_mo_id);
    v_total_line_updates := v_total_line_updates + COALESCE((v_sync->>'line_updates')::int, 0);
    IF COALESCE((v_sync->>'mo_updated')::boolean, false) THEN
      v_total_mo_updates := v_total_mo_updates + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'line_updates', v_total_line_updates,
    'advanced_count', v_total_mo_updates
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_mo_readiness_after_po_receive(uuid) TO authenticated;
