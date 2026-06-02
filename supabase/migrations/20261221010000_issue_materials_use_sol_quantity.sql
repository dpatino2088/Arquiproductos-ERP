-- Consume materials by per-unit BOM qty x sales-order-line quantity, matching the
-- material demand view (SUM(bil.qty * sol.quantity)). Previously SUM(bil.qty)
-- under-issued for lines with quantity > 1 (e.g. MO-000002 fabric: 5.80m vs 11.60m).
CREATE OR REPLACE FUNCTION public.issue_materials_for_manufacturing_order(p_manufacturing_order_id uuid, p_warehouse_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_mo RECORD;
  v_movement_id uuid;
  v_movement_no text;
  v_line_count integer := 0;
  v_bil RECORD;
BEGIN
  SELECT id, organization_id, status, manufacturing_order_no
  INTO v_mo
  FROM "ManufacturingOrders"
  WHERE id = p_manufacturing_order_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Manufacturing Order not found or deleted.');
  END IF;

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

  SELECT 'INV-' || LPAD((COALESCE(MAX(
    CASE WHEN movement_no ~ '^INV-\d+$' THEN CAST(SUBSTRING(movement_no FROM 'INV-(\d+)') AS integer) ELSE 0 END
  ), 0) + 1)::text, 6, '0')
  INTO v_movement_no
  FROM "InventoryMovements"
  WHERE organization_id = v_mo.organization_id;

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

  FOR v_bil IN
    SELECT bil.resolved_part_id AS catalog_item_id,
           SUM(bil.qty * COALESCE(sol.quantity, 1)) AS total_qty,
           bil.uom
    FROM "BOMInstanceLines" bil
    JOIN "BOMInstances" bi ON bi.id = bil.bom_instance_id
    LEFT JOIN "SaleOrderLines" sol ON sol.id = bi.sales_order_line_id
    WHERE bi.manufacturing_order_id = p_manufacturing_order_id
      AND bi.deleted = false AND bil.deleted = false
      AND bil.excluded = false
      AND bil.resolved_part_id IS NOT NULL
    GROUP BY bil.resolved_part_id, bil.uom
  LOOP
    INSERT INTO "InventoryMovementLines" (
      inventory_movement_id, catalog_item_id, quantity, unit, created_at, updated_at
    ) VALUES (
      v_movement_id, v_bil.catalog_item_id, -(v_bil.total_qty), COALESCE(v_bil.uom, 'ea'), now(), now()
    );
    v_line_count := v_line_count + 1;

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
$function$;
