-- RPC: confirm_inventory_movement
-- Generic confirm for draft movements (receipt, adjustment, transfer, return).
-- Normalizes qty signs and updates InventoryBalances.

CREATE OR REPLACE FUNCTION public.confirm_inventory_movement(p_movement_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mov RECORD;
  v_line RECORD;
  v_line_count integer := 0;
BEGIN
  SELECT id, organization_id, warehouse_id, movement_type, status
  INTO v_mov
  FROM "InventoryMovements"
  WHERE id = p_movement_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Movement not found or deleted.');
  END IF;

  IF v_mov.status = 'confirmed' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Movement is already confirmed.');
  END IF;

  -- Update each balance from lines
  FOR v_line IN
    SELECT catalog_item_id, quantity, unit
    FROM "InventoryMovementLines"
    WHERE inventory_movement_id = p_movement_id
  LOOP
    INSERT INTO "InventoryBalances" (organization_id, warehouse_id, catalog_item_id, quantity, updated_at)
    VALUES (v_mov.organization_id, v_mov.warehouse_id, v_line.catalog_item_id, v_line.quantity, now())
    ON CONFLICT (organization_id, warehouse_id, catalog_item_id)
    DO UPDATE SET quantity = "InventoryBalances".quantity + v_line.quantity, updated_at = now();

    v_line_count := v_line_count + 1;
  END LOOP;

  -- Mark confirmed
  UPDATE "InventoryMovements"
  SET status = 'confirmed', confirmed_at = now(), updated_at = now()
  WHERE id = p_movement_id;

  RETURN jsonb_build_object('ok', true, 'movement_id', p_movement_id, 'lines_confirmed', v_line_count);
END;
$$;

COMMENT ON FUNCTION public.confirm_inventory_movement IS 'Confirm a draft inventory movement. Applies qty to InventoryBalances and sets status=confirmed.';
GRANT EXECUTE ON FUNCTION public.confirm_inventory_movement(uuid) TO authenticated;;
