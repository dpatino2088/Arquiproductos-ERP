-- Supply delivery: on delivery-note completion, consume physical inventory for
-- delivered supply lines (catalog items) and issue their SO reservations. Also
-- stop non-deliverable supply charges (Shipping/service with no catalog item)
-- from blocking the Sales Order from reaching 'delivered'.
CREATE OR REPLACE FUNCTION public.complete_delivery_note(p_delivery_note_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_dn record; v_total integer; v_checked integer; v_mo_id uuid;
  v_new_dn_status text; v_all_mol_delivered boolean; v_so_id uuid;
  v_all_mo_delivered boolean; v_all_supply_delivered boolean; v_org_id uuid;
  v_mo_no text; v_gate record; v_claim_id uuid; v_claim_chargeable boolean;
  -- supply consumption locals
  v_wh uuid; v_mov_id uuid; v_mov_no text; v_rec record; v_take numeric; v_bal numeric; v_has_lines boolean := false;
BEGIN
  SELECT * INTO v_dn FROM public."DeliveryNotes" WHERE id = p_delivery_note_id AND deleted = false;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Delivery note not found'); END IF;

  v_mo_id := v_dn.manufacturing_order_id;
  v_org_id := v_dn.organization_id;
  v_so_id := v_dn.sales_order_id;

  IF v_mo_id IS NOT NULL THEN
    SELECT manufacturing_order_no, sales_order_id, claim_id INTO v_mo_no, v_so_id, v_claim_id
    FROM public."ManufacturingOrders" WHERE id = v_mo_id;
  ELSIF v_so_id IS NOT NULL THEN
    SELECT id INTO v_mo_id FROM public."ManufacturingOrders"
    WHERE sales_order_id = v_so_id AND deleted = false AND status IN ('ready_for_pickup', 'delivered')
    ORDER BY created_at DESC LIMIT 1;
    IF v_mo_id IS NOT NULL THEN
      SELECT manufacturing_order_no, claim_id INTO v_mo_no, v_claim_id
      FROM public."ManufacturingOrders" WHERE id = v_mo_id;
    END IF;
  END IF;

  -- Delivery gate (claim invoice paid OR SO financials settled/override)
  IF v_claim_id IS NOT NULL THEN
    SELECT COALESCE(sc.chargeable, false) INTO v_claim_chargeable
    FROM public."ServiceClaims" sc WHERE sc.id = v_claim_id AND sc.deleted = false;
    IF v_claim_chargeable THEN
      IF NOT EXISTS (
        SELECT 1 FROM public."DealerInvoices" di
        WHERE di.claim_id = v_claim_id AND di.deleted = false AND di.status = 'paid'
      ) THEN
        RETURN jsonb_build_object('ok', false, 'error', 'Delivery blocked: claim invoice is not fully paid.');
      END IF;
    END IF;
  ELSIF v_so_id IS NOT NULL THEN
    SELECT * INTO v_gate FROM public.get_sales_order_delivery_gate(v_so_id);
    IF NOT COALESCE(v_gate.delivery_allowed, false) THEN
      RETURN jsonb_build_object('ok', false,
        'error', format('Delivery blocked: balance due is $%s. Financials must settle to 0.00 or issue override.', to_char(COALESCE(v_gate.balance_due, 0), 'FM999999990.00')),
        'balance_due', COALESCE(v_gate.balance_due, 0));
    END IF;
  END IF;

  SELECT count(*), count(*) FILTER (WHERE checked = true) INTO v_total, v_checked
  FROM public."DeliveryNoteLines" WHERE delivery_note_id = p_delivery_note_id;
  IF v_total = 0 THEN RETURN jsonb_build_object('ok', false, 'error', 'No lines in delivery note'); END IF;
  IF v_checked = 0 THEN RETURN jsonb_build_object('ok', false, 'error', 'No lines checked for delivery'); END IF;

  v_new_dn_status := CASE WHEN v_checked >= v_total THEN 'completed' ELSE 'partial' END;

  UPDATE public."DeliveryNotes"
  SET status = v_new_dn_status,
      completed_at = CASE WHEN v_new_dn_status = 'completed' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_delivery_note_id;

  -- Mark MO-backed lines delivered
  UPDATE public."ManufacturingOrderLines" mol
  SET delivery_status = 'delivered', delivered_at = now(), delivered_qty = mol.quantity, updated_at = now()
  FROM public."DeliveryNoteLines" dnl
  WHERE dnl.delivery_note_id = p_delivery_note_id
    AND dnl.mo_line_id IS NOT NULL AND dnl.mo_line_id = mol.id AND dnl.checked = true;

  -- Mark supply lines delivered on SaleOrderLines
  UPDATE public."SaleOrderLines" sol
  SET delivery_status = 'delivered', updated_at = now()
  FROM public."DeliveryNoteLines" dnl
  WHERE dnl.delivery_note_id = p_delivery_note_id
    AND dnl.sale_order_line_id IS NOT NULL AND dnl.sale_order_line_id = sol.id AND dnl.checked = true;

  -- Consume physical inventory for delivered supply lines (catalog items only).
  -- Guarded so re-running completion does not double-decrement.
  IF v_org_id IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM public."InventoryMovements"
       WHERE reference_type = 'delivery_note' AND reference_id = p_delivery_note_id
         AND movement_type = 'delivery' AND deleted = false
     ) THEN
    -- Resolve a warehouse from the SO's allocations, else the org default
    SELECT ia.warehouse_id INTO v_wh
    FROM public."InventoryAllocations" ia
    WHERE ia.sales_order_id = v_so_id ORDER BY ia.allocated_at DESC LIMIT 1;
    IF v_wh IS NULL THEN
      SELECT id INTO v_wh FROM public."Warehouses"
      WHERE organization_id = v_org_id ORDER BY is_default DESC, created_at ASC LIMIT 1;
    END IF;

    IF v_wh IS NOT NULL AND v_so_id IS NOT NULL THEN
      SELECT 'INV-' || LPAD((COALESCE(MAX(
        CASE WHEN movement_no ~ '^INV-\d+$' THEN CAST(SUBSTRING(movement_no FROM 'INV-(\d+)') AS integer) ELSE 0 END
      ), 0) + 1)::text, 6, '0')
      INTO v_mov_no FROM public."InventoryMovements" WHERE organization_id = v_org_id;

      FOR v_rec IN
        SELECT sol.catalog_item_id AS cat, SUM(dnl.quantity_delivered) AS qty
        FROM public."DeliveryNoteLines" dnl
        JOIN public."SaleOrderLines" sol ON sol.id = dnl.sale_order_line_id
        WHERE dnl.delivery_note_id = p_delivery_note_id
          AND dnl.checked = true AND dnl.line_type = 'supply'
          AND sol.catalog_item_id IS NOT NULL
        GROUP BY sol.catalog_item_id
      LOOP
        -- Issue the SO reservations for this item (consumed by the delivery)
        UPDATE public."InventoryAllocations"
        SET status = 'issued', issued_at = now(), updated_at = now()
        WHERE sales_order_id = v_so_id AND catalog_item_id = v_rec.cat AND status = 'reserved';

        SELECT COALESCE(quantity, 0) INTO v_bal
        FROM public."InventoryBalances"
        WHERE organization_id = v_org_id AND warehouse_id = v_wh AND catalog_item_id = v_rec.cat;

        -- Never drive the balance below zero (respects the non-negative check)
        v_take := LEAST(COALESCE(v_bal, 0), COALESCE(v_rec.qty, 0));
        IF v_take > 0 THEN
          IF NOT v_has_lines THEN
            INSERT INTO public."InventoryMovements" (
              organization_id, warehouse_id, movement_type, reference_type, reference_id,
              movement_no, movement_date, status, confirmed_at, notes, created_at, updated_at
            ) VALUES (
              v_org_id, v_wh, 'delivery', 'delivery_note', p_delivery_note_id,
              v_mov_no, CURRENT_DATE, 'confirmed', now(),
              format('Supply delivered on %s', v_dn.delivery_number), now(), now()
            ) RETURNING id INTO v_mov_id;
            v_has_lines := true;
          END IF;

          INSERT INTO public."InventoryMovementLines" (
            inventory_movement_id, catalog_item_id, quantity, unit, created_at, updated_at
          ) VALUES (v_mov_id, v_rec.cat, -(v_take), 'ea', now(), now());

          UPDATE public."InventoryBalances"
          SET quantity = quantity - v_take, updated_at = now()
          WHERE organization_id = v_org_id AND warehouse_id = v_wh AND catalog_item_id = v_rec.cat;
        END IF;
      END LOOP;
    END IF;
  END IF;

  -- MO completeness
  IF v_mo_id IS NOT NULL THEN
    SELECT NOT EXISTS (
      SELECT 1 FROM public."ManufacturingOrderLines"
      WHERE manufacturing_order_id = v_mo_id AND deleted = false AND delivery_status <> 'delivered'
    ) INTO v_all_mol_delivered;

    IF v_all_mol_delivered THEN
      UPDATE public."ManufacturingOrders"
      SET status = 'delivered', delivered_at = now(), updated_at = now()
      WHERE id = v_mo_id AND status <> 'delivered';
    END IF;

    INSERT INTO public."ActivityTimeline" (entity_type, entity_id, action, description, user_name, organization_id)
    VALUES ('manufacturing_order', v_mo_id,
      CASE WHEN v_new_dn_status = 'completed' THEN 'delivery_completed' ELSE 'delivery_partial' END,
      format('%s: %s/%s lines delivered%s', v_dn.delivery_number, v_checked, v_total,
        CASE WHEN v_dn.received_by_name IS NOT NULL THEN format(' — received by %s', v_dn.received_by_name) ELSE '' END),
      COALESCE(v_dn.delivered_by_name, 'System'), v_org_id);

    IF v_all_mol_delivered THEN
      INSERT INTO public."ActivityTimeline" (entity_type, entity_id, action, description, user_name, organization_id)
      VALUES ('manufacturing_order', v_mo_id, 'status_change',
        'Manufacturing order marked as Delivered — all lines delivered',
        COALESCE(v_dn.delivered_by_name, 'System'), v_org_id);
    END IF;
  END IF;

  -- SO completeness (MOs + physically deliverable supply lines only).
  -- Supply charges without a catalog item (e.g. Shipping/installation) are NOT
  -- physical deliveries and must not block the order from being delivered.
  IF v_so_id IS NOT NULL THEN
    SELECT NOT EXISTS (
      SELECT 1 FROM public."ManufacturingOrders"
      WHERE sales_order_id = v_so_id AND deleted = false
        AND status <> 'delivered' AND status <> 'cancelled'
    ) INTO v_all_mo_delivered;

    SELECT NOT EXISTS (
      SELECT 1 FROM public."SaleOrderLines" sol
      JOIN public."ProductTypes" pt ON pt.code = sol.product_type AND pt.organization_id = sol.organization_id
      WHERE sol.sales_order_id = v_so_id AND sol.deleted = false
        AND pt.fulfillment_type = 'supply_only'
        AND sol.catalog_item_id IS NOT NULL
        AND sol.delivery_status <> 'delivered'
    ) INTO v_all_supply_delivered;

    IF COALESCE(v_all_mo_delivered, true) AND COALESCE(v_all_supply_delivered, true) THEN
      UPDATE public."SalesOrders" SET status = 'delivered', updated_at = now()
      WHERE id = v_so_id AND status <> 'delivered';

      IF v_gate IS NOT NULL AND COALESCE(v_gate.payment_complete, false) = false AND v_gate.active_override_id IS NOT NULL THEN
        UPDATE public."SalesOrderDeliveryOverrides"
        SET status = 'used', used_by = v_dn.delivered_by_user_id,
            used_by_name = COALESCE(v_dn.delivered_by_name, 'System'),
            used_source = 'delivery_note', used_delivery_note_id = p_delivery_note_id,
            used_at = now(), updated_at = now()
        WHERE id = v_gate.active_override_id AND status = 'active' AND deleted = false;
      END IF;

      INSERT INTO public."ActivityTimeline" (entity_type, entity_id, action, description, user_name, organization_id)
      VALUES ('sales_order', v_so_id, 'status_change',
        'Sales order delivered — all lines delivered', 'System (auto)', v_org_id);
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'delivery_note_status', v_new_dn_status,
    'checked_count', v_checked, 'total_count', v_total, 'mo_delivered', COALESCE(v_all_mol_delivered, false));
END;
$function$;
