-- ============================================================================
-- Fix complete_delivery_note SalesOrder status transition
-- ============================================================================
-- SalesOrders enum does not include 'fulfilled'. Use 'delivered' to match
-- current SalesOrder lifecycle and MO->SO propagation rules.
-- ============================================================================

SET search_path = public;

CREATE OR REPLACE FUNCTION public.complete_delivery_note(p_delivery_note_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $fn$
DECLARE
  v_dn        record;
  v_total     integer;
  v_checked   integer;
  v_mo_id     uuid;
  v_new_dn_status text;
  v_all_mol_delivered boolean;
  v_so_id     uuid;
  v_all_mo_delivered boolean;
  v_org_id    uuid;
  v_mo_no     text;
  v_gate      record;
BEGIN
  SELECT * INTO v_dn FROM public."DeliveryNotes"
  WHERE id = p_delivery_note_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Delivery note not found');
  END IF;

  v_mo_id := v_dn.manufacturing_order_id;
  v_org_id := v_dn.organization_id;

  SELECT manufacturing_order_no, sales_order_id
  INTO v_mo_no, v_so_id
  FROM public."ManufacturingOrders"
  WHERE id = v_mo_id;

  IF v_so_id IS NOT NULL THEN
    SELECT * INTO v_gate
    FROM public.get_sales_order_delivery_gate(v_so_id);

    IF NOT COALESCE(v_gate.delivery_allowed, false) THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', format('Delivery blocked: balance due is $%s. Financials must settle to 0.00 or issue override.', to_char(COALESCE(v_gate.balance_due, 0), 'FM999999990.00')),
        'balance_due', COALESCE(v_gate.balance_due, 0)
      );
    END IF;
  END IF;

  SELECT count(*), count(*) FILTER (WHERE checked = true)
  INTO v_total, v_checked
  FROM public."DeliveryNoteLines"
  WHERE delivery_note_id = p_delivery_note_id;

  IF v_total = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No lines in delivery note');
  END IF;

  IF v_checked = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No lines checked for delivery');
  END IF;

  v_new_dn_status := CASE WHEN v_checked >= v_total THEN 'completed' ELSE 'partial' END;

  UPDATE public."DeliveryNotes"
  SET status = v_new_dn_status,
      completed_at = CASE WHEN v_new_dn_status = 'completed' THEN now() ELSE completed_at END,
      updated_at = now()
  WHERE id = p_delivery_note_id;

  UPDATE public."ManufacturingOrderLines" mol
  SET delivery_status = 'delivered',
      delivered_at = now(),
      delivered_qty = mol.quantity,
      updated_at = now()
  FROM public."DeliveryNoteLines" dnl
  WHERE dnl.delivery_note_id = p_delivery_note_id
    AND dnl.mo_line_id = mol.id
    AND dnl.checked = true;

  SELECT NOT EXISTS (
    SELECT 1 FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = v_mo_id
      AND deleted = false
      AND delivery_status <> 'delivered'
  ) INTO v_all_mol_delivered;

  IF v_all_mol_delivered THEN
    UPDATE public."ManufacturingOrders"
    SET status = 'delivered', delivered_at = now(), updated_at = now()
    WHERE id = v_mo_id AND status <> 'delivered';

    IF v_so_id IS NOT NULL THEN
      SELECT NOT EXISTS (
        SELECT 1 FROM public."ManufacturingOrders"
        WHERE sales_order_id = v_so_id
          AND deleted = false
          AND status <> 'delivered'
          AND status <> 'cancelled'
      ) INTO v_all_mo_delivered;

      IF v_all_mo_delivered THEN
        UPDATE public."SalesOrders"
        SET status = 'delivered', updated_at = now()
        WHERE id = v_so_id AND status <> 'delivered';
      END IF;

      IF COALESCE(v_gate.payment_complete, false) = false
         AND v_gate.active_override_id IS NOT NULL THEN
        UPDATE public."SalesOrderDeliveryOverrides"
        SET status = 'used',
            used_by = v_dn.delivered_by_user_id,
            used_by_name = COALESCE(v_dn.delivered_by_name, 'System'),
            used_source = 'delivery_note',
            used_delivery_note_id = p_delivery_note_id,
            used_at = now(),
            updated_at = now()
        WHERE id = v_gate.active_override_id
          AND status = 'active'
          AND deleted = false;
      END IF;
    END IF;
  END IF;

  INSERT INTO public."ActivityTimeline" (
    entity_type, entity_id, action, description, user_name, organization_id
  ) VALUES (
    'manufacturing_order', v_mo_id,
    CASE WHEN v_new_dn_status = 'completed' THEN 'delivery_completed' ELSE 'delivery_partial' END,
    format('%s: %s/%s lines delivered%s',
      v_dn.delivery_number, v_checked, v_total,
      CASE WHEN v_dn.received_by_name IS NOT NULL
        THEN format(' — received by %s', v_dn.received_by_name) ELSE '' END
    ),
    COALESCE(v_dn.delivered_by_name, 'System'),
    v_org_id
  );

  IF v_all_mol_delivered THEN
    INSERT INTO public."ActivityTimeline" (
      entity_type, entity_id, action, description, user_name, organization_id
    ) VALUES (
      'manufacturing_order', v_mo_id,
      'status_change',
      'Manufacturing order marked as Delivered — all lines delivered',
      COALESCE(v_dn.delivered_by_name, 'System'),
      v_org_id
    );
  END IF;

  IF v_all_mo_delivered AND v_so_id IS NOT NULL THEN
    INSERT INTO public."ActivityTimeline" (
      entity_type, entity_id, action, description, user_name, organization_id
    ) VALUES (
      'sales_order', v_so_id,
      'status_change',
      'Sales order delivered — all manufacturing orders delivered',
      'System (auto)',
      v_org_id
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'delivery_note_status', v_new_dn_status,
    'checked_count', v_checked,
    'total_count', v_total,
    'mo_delivered', v_all_mol_delivered
  );
END;
$fn$;

NOTIFY pgrst, 'reload schema';
