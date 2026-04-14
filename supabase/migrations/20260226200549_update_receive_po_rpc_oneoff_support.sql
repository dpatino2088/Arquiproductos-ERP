
CREATE OR REPLACE FUNCTION public.receive_purchase_order(p_purchase_order_id uuid, p_lines jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_po RECORD;
  v_movement_id uuid;
  v_movement_no text;
  v_line_count integer := 0;
  v_line jsonb;
  v_pol RECORD;
  v_remaining numeric;
  v_new_received numeric;
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
    SELECT pol.id, pol.catalog_item_id, pol.ordered_qty, pol.received_qty, pol.unit, pol.is_one_off
    INTO v_pol
    FROM "PurchaseOrderLines" pol
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

    -- Movement line: use catalog_item_id if available (may be NULL for one-off items)
    IF v_pol.catalog_item_id IS NOT NULL THEN
      INSERT INTO "InventoryMovementLines" (
        inventory_movement_id, catalog_item_id, quantity, unit, created_at, updated_at
      ) VALUES (
        v_movement_id, v_pol.catalog_item_id, v_new_received, COALESCE(v_pol.unit, 'ea'), now(), now()
      );
    END IF;
    v_line_count := v_line_count + 1;

    UPDATE "PurchaseOrderLines"
    SET received_qty = received_qty + v_new_received, updated_at = now()
    WHERE id = v_pol.id;

    -- Only update inventory balances for catalog items (skip one-off)
    IF v_pol.catalog_item_id IS NOT NULL THEN
      INSERT INTO "InventoryBalances" (organization_id, warehouse_id, catalog_item_id, quantity, updated_at)
      VALUES (v_po.organization_id, v_po.warehouse_id, v_pol.catalog_item_id, v_new_received, now())
      ON CONFLICT (organization_id, warehouse_id, catalog_item_id)
      DO UPDATE SET quantity = "InventoryBalances".quantity + v_new_received, updated_at = now();
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
$function$;
;
