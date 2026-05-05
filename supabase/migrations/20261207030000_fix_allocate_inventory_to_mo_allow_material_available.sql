-- ============================================================================
-- Fix: allocate_inventory_to_mo() rejected MOs in 'material_available' state.
-- 'material_available' is a transient pre-production state introduced in
-- 20261101080000_mol_procurement_material_available_states.sql, sitting
-- between 'procurement' and 'materials_ready'. Allocation must be allowed
-- here, otherwise an MO whose components were detected on hand (and was
-- auto-promoted to material_available by sync_mol_material_available_from_inventory)
-- can never get the remaining items reserved, leaving the MO stuck below
-- materials_ready.
--
-- This migration only changes the status guard; the allocation logic itself
-- is unchanged.
-- ============================================================================

SET search_path = public;

CREATE OR REPLACE FUNCTION public.allocate_inventory_to_mo(
  p_org_id uuid,
  p_warehouse_id uuid,
  p_manufacturing_order_id uuid,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_item record;
  v_on_hand numeric;
  v_already_allocated numeric;
  v_available numeric;
  v_alloc_qty numeric;
  v_results jsonb := '[]'::jsonb;
  v_so_id uuid;
  v_mo_status text;
BEGIN
  SELECT sales_order_id, status::text
    INTO v_so_id, v_mo_status
  FROM "ManufacturingOrders"
  WHERE id = p_manufacturing_order_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  IF v_mo_status NOT IN ('draft', 'confirmed', 'procurement', 'material_available', 'materials_ready') THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('Cannot allocate materials when MO is in %s. Only allowed up to Materials Ready.', v_mo_status)
    );
  END IF;

  FOR v_item IN
    SELECT (elem ->> 'catalog_item_id')::uuid AS catalog_item_id,
           (elem ->> 'qty')::numeric AS qty
    FROM jsonb_array_elements(p_items) AS elem
  LOOP
    SELECT COALESCE(SUM(ib.quantity), 0)
      INTO v_on_hand
    FROM "InventoryBalances" ib
    WHERE ib.organization_id = p_org_id
      AND ib.warehouse_id = p_warehouse_id
      AND ib.catalog_item_id = v_item.catalog_item_id;

    SELECT COALESCE(SUM(ia.allocated_qty), 0)
      INTO v_already_allocated
    FROM "InventoryAllocations" ia
    WHERE ia.organization_id = p_org_id
      AND ia.warehouse_id = p_warehouse_id
      AND ia.catalog_item_id = v_item.catalog_item_id
      AND ia.status = 'reserved';

    v_available := v_on_hand - v_already_allocated;
    v_alloc_qty := ROUND(LEAST(v_item.qty, GREATEST(0, v_available)), 4);

    IF v_alloc_qty >= 0.0001 THEN
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
$function$;
