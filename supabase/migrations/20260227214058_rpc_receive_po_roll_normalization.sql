CREATE OR REPLACE FUNCTION public.receive_purchase_order(
  p_purchase_order_id uuid,
  p_lines jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_po RECORD;
  v_movement_id uuid;
  v_movement_no text;
  v_line_count integer := 0;
  v_line jsonb;
  v_pol RECORD;
  v_remaining numeric;
  v_new_received numeric;
  v_inventory_delta numeric;
  v_inventory_unit text;
  v_roll_length_value numeric;
  v_roll_length_uom text;
  v_length_m_per_purchase numeric;
BEGIN
  SELECT id, organization_id, warehouse_id, status, po_number
  INTO v_po
  FROM "PurchaseOrders"
  WHERE id = p_purchase_order_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Purchase order not found.');
  END IF;

  IF v_po.status NOT IN ('OPEN', 'PARTIAL') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Purchase order is closed. Cannot receive.');
  END IF;

  SELECT 'REC-' || LPAD((COALESCE(MAX(
    CASE WHEN movement_no ~ '^REC-\d+$' THEN CAST(SUBSTRING(movement_no FROM 'REC-(\d+)') AS integer) ELSE 0 END
  ), 0) + 1)::text, 6, '0')
  INTO v_movement_no
  FROM "InventoryMovements"
  WHERE organization_id = v_po.organization_id;

  INSERT INTO "InventoryMovements" (
    organization_id, warehouse_id, movement_type, reference_type, reference_id,
    movement_no, movement_date, status, confirmed_at, notes, deleted, created_at, updated_at
  ) VALUES (
    v_po.organization_id, v_po.warehouse_id, 'receipt',
    'purchase_order', p_purchase_order_id,
    v_movement_no, CURRENT_DATE, 'confirmed', now(),
    'Receipt for PO ' || COALESCE(v_po.po_number, v_po.id::text),
    false, now(), now()
  ) RETURNING id INTO v_movement_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(p_lines)
  LOOP
    SELECT
      pol.id,
      pol.catalog_item_id,
      pol.ordered_qty,
      pol.received_qty,
      pol.unit,
      pol.is_one_off,
      COALESCE(pol.unit_of_measure_snapshot, ci.unit_of_measure, pol.unit, 'ea') AS unit_of_measure_snapshot,
      COALESCE(pol.is_roll_snapshot, ci.is_roll, false) AS is_roll_snapshot,
      COALESCE(pol.roll_length_value_snapshot, ci.roll_length_value) AS roll_length_value_snapshot,
      COALESCE(pol.roll_length_uom_snapshot, ci.roll_length_uom) AS roll_length_uom_snapshot
    INTO v_pol
    FROM "PurchaseOrderLines" pol
    LEFT JOIN "CatalogItems" ci ON ci.id = pol.catalog_item_id
    WHERE pol.id = (v_line->>'purchase_order_line_id')::uuid
      AND pol.purchase_order_id = p_purchase_order_id;

    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    v_remaining := v_pol.ordered_qty - COALESCE(v_pol.received_qty, 0);
    v_new_received := LEAST((v_line->>'received_qty')::numeric, v_remaining);

    IF v_new_received <= 0 THEN
      CONTINUE;
    END IF;

    v_inventory_delta := v_new_received;
    v_inventory_unit := COALESCE(v_pol.unit_of_measure_snapshot, v_pol.unit, 'ea');
    IF v_pol.catalog_item_id IS NOT NULL AND COALESCE(v_pol.is_roll_snapshot, false) = true THEN
      v_roll_length_value := COALESCE(v_pol.roll_length_value_snapshot, 0);
      v_roll_length_uom := LOWER(COALESCE(v_pol.roll_length_uom_snapshot, ''));
      v_length_m_per_purchase := CASE
        WHEN v_roll_length_value <= 0 THEN NULL
        WHEN v_roll_length_uom IN ('m', 'meter', 'meters', 'metre', 'metres') THEN v_roll_length_value
        WHEN v_roll_length_uom IN ('yd', 'yard', 'yards') THEN v_roll_length_value * 0.9144
        WHEN v_roll_length_uom IN ('ft', 'foot', 'feet') THEN v_roll_length_value * 0.3048
        WHEN v_roll_length_uom IN ('in', 'inch', 'inches') THEN v_roll_length_value * 0.0254
        WHEN v_roll_length_uom IN ('cm', 'centimeter', 'centimeters', 'centimetre', 'centimetres') THEN v_roll_length_value / 100.0
        WHEN v_roll_length_uom IN ('mm', 'millimeter', 'millimeters', 'millimetre', 'millimetres') THEN v_roll_length_value / 1000.0
        ELSE NULL
      END;
      IF v_length_m_per_purchase IS NOT NULL AND v_length_m_per_purchase > 0 THEN
        v_inventory_delta := v_new_received * v_length_m_per_purchase;
        v_inventory_unit := 'm';
      END IF;
    END IF;

    IF v_pol.catalog_item_id IS NOT NULL THEN
      INSERT INTO "InventoryMovementLines" (
        inventory_movement_id, catalog_item_id, quantity, unit, notes, created_at, updated_at
      ) VALUES (
        v_movement_id,
        v_pol.catalog_item_id,
        v_inventory_delta,
        v_inventory_unit,
        CASE
          WHEN COALESCE(v_pol.is_roll_snapshot, false) = true
            THEN format('Received %s %s (normalized to %s m)',
                        v_new_received,
                        COALESCE(v_pol.unit, 'roll'),
                        ROUND(v_inventory_delta, 6))
          ELSE NULL
        END,
        now(),
        now()
      );
    END IF;
    v_line_count := v_line_count + 1;

    UPDATE "PurchaseOrderLines"
    SET received_qty = received_qty + v_new_received, updated_at = now()
    WHERE id = v_pol.id;

    IF v_pol.catalog_item_id IS NOT NULL THEN
      INSERT INTO "InventoryBalances" (organization_id, warehouse_id, catalog_item_id, quantity, updated_at)
      VALUES (v_po.organization_id, v_po.warehouse_id, v_pol.catalog_item_id, v_inventory_delta, now())
      ON CONFLICT (organization_id, warehouse_id, catalog_item_id)
      DO UPDATE SET quantity = "InventoryBalances".quantity + v_inventory_delta, updated_at = now();
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM "PurchaseOrderLines"
    WHERE purchase_order_id = p_purchase_order_id
      AND (ordered_qty - received_qty) > 0
  ) THEN
    UPDATE "PurchaseOrders" SET status = 'CLOSED', updated_at = now() WHERE id = p_purchase_order_id;
  ELSE
    UPDATE "PurchaseOrders" SET status = 'PARTIAL', updated_at = now() WHERE id = p_purchase_order_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'movement_id', v_movement_id,
    'movement_no', v_movement_no,
    'lines_count', v_line_count,
    'po_number', v_po.po_number
  );
END;
$$;;
