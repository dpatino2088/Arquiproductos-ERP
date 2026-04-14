-- RPC: issue_materials_for_manufacturing_order
-- Reads BOM for an MO, creates a confirmed InventoryMovement with negative qty lines, decrements InventoryBalances.

CREATE OR REPLACE FUNCTION public.issue_materials_for_manufacturing_order(
  p_manufacturing_order_id uuid,
  p_warehouse_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo RECORD;
  v_movement_id uuid;
  v_movement_no text;
  v_line_count integer := 0;
  v_bil RECORD;
BEGIN
  -- 1. Validate MO
  SELECT id, organization_id, status, manufacturing_order_no
  INTO v_mo
  FROM "ManufacturingOrders"
  WHERE id = p_manufacturing_order_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Manufacturing Order not found or deleted.');
  END IF;

  -- 2. Idempotent guard: skip if already issued
  IF EXISTS (
    SELECT 1 FROM "InventoryMovements"
    WHERE reference_type = 'manufacturing_order'
      AND reference_id = p_manufacturing_order_id
      AND movement_type = 'issue_to_production'
      AND status = 'confirmed'
      AND deleted = false
  ) THEN
    RETURN jsonb_build_object('ok', true, 'skipped', true, 'message', 'Materials already issued for this MO.');
  END IF;

  -- 3. Generate movement number
  SELECT 'INV-' || LPAD((COALESCE(MAX(
    CASE WHEN movement_no ~ '^INV-\d+$' THEN CAST(SUBSTRING(movement_no FROM 'INV-(\d+)') AS integer) ELSE 0 END
  ), 0) + 1)::text, 6, '0')
  INTO v_movement_no
  FROM "InventoryMovements"
  WHERE organization_id = v_mo.organization_id;

  -- 4. Create movement header
  INSERT INTO "InventoryMovements" (
    organization_id, warehouse_id, movement_type, reference_type, reference_id,
    movement_no, movement_date, status, confirmed_at, notes, created_at, updated_at
  ) VALUES (
    v_mo.organization_id, p_warehouse_id, 'issue_to_production',
    'manufacturing_order', p_manufacturing_order_id,
    v_movement_no, CURRENT_DATE, 'confirmed', now(),
    'Auto-issued materials for ' || v_mo.manufacturing_order_no,
    now(), now()
  ) RETURNING id INTO v_movement_id;

  -- 5. Insert lines from BOM and decrement balances
  FOR v_bil IN
    SELECT bil.resolved_part_id AS catalog_item_id, SUM(bil.qty) AS total_qty, bil.uom
    FROM "BomInstanceLines" bil
    JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    WHERE bi.manufacturing_order_id = p_manufacturing_order_id
      AND bi.deleted = false AND bil.deleted = false
      AND bil.resolved_part_id IS NOT NULL
    GROUP BY bil.resolved_part_id, bil.uom
  LOOP
    INSERT INTO "InventoryMovementLines" (
      inventory_movement_id, catalog_item_id, quantity, unit, created_at, updated_at
    ) VALUES (
      v_movement_id, v_bil.catalog_item_id, -(v_bil.total_qty), COALESCE(v_bil.uom, 'ea'), now(), now()
    );
    v_line_count := v_line_count + 1;

    -- Decrement InventoryBalances (upsert)
    INSERT INTO "InventoryBalances" (organization_id, warehouse_id, catalog_item_id, quantity, updated_at)
    VALUES (v_mo.organization_id, p_warehouse_id, v_bil.catalog_item_id, -(v_bil.total_qty), now())
    ON CONFLICT (organization_id, warehouse_id, catalog_item_id)
    DO UPDATE SET quantity = "InventoryBalances".quantity - v_bil.total_qty, updated_at = now();
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'movement_id', v_movement_id,
    'movement_no', v_movement_no,
    'lines_count', v_line_count,
    'manufacturing_order_no', v_mo.manufacturing_order_no
  );
END;
$$;

COMMENT ON FUNCTION public.issue_materials_for_manufacturing_order IS 'Issue BOM materials to production for an MO. Creates confirmed InventoryMovement and decrements InventoryBalances.';
GRANT EXECUTE ON FUNCTION public.issue_materials_for_manufacturing_order(uuid, uuid) TO authenticated;;
