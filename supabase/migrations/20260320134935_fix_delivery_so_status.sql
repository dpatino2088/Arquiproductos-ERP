CREATE OR REPLACE FUNCTION public.complete_delivery_note(p_delivery_note_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $fn$
DECLARE
  v_dn          record;
  v_org_id      uuid;
  v_mo_id       uuid;
  v_so_id       uuid;
  v_checked     int;
  v_total       int;
  v_new_dn_status text;
  v_all_mol_delivered bool := false;
  v_all_mo_delivered  bool := false;
BEGIN
  SELECT * INTO v_dn
  FROM public."DeliveryNotes"
  WHERE id = p_delivery_note_id AND deleted = false;

  IF v_dn IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Delivery note not found');
  END IF;

  IF v_dn.status IN ('completed', 'partial') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Delivery already completed');
  END IF;

  v_org_id := v_dn.organization_id;
  v_mo_id  := v_dn.manufacturing_order_id;

  SELECT count(*) FILTER (WHERE checked = true),
         count(*)
  INTO v_checked, v_total
  FROM public."DeliveryNoteLines"
  WHERE delivery_note_id = p_delivery_note_id;

  IF v_checked = 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'No lines checked');
  END IF;

  v_new_dn_status := CASE WHEN v_checked = v_total THEN 'completed' ELSE 'partial' END;

  UPDATE public."DeliveryNotes"
  SET status = v_new_dn_status,
      completed_at = now(),
      updated_at = now()
  WHERE id = p_delivery_note_id;

  UPDATE public."DeliveryNoteLines"
  SET checked_at = COALESCE(checked_at, now())
  WHERE delivery_note_id = p_delivery_note_id AND checked = true AND checked_at IS NULL;

  UPDATE public."ManufacturingOrderLines" mol
  SET delivery_status = 'delivered', updated_at = now()
  FROM public."DeliveryNoteLines" dnl
  WHERE dnl.delivery_note_id = p_delivery_note_id
    AND dnl.checked = true
    AND dnl.mo_line_id = mol.id;

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

    SELECT sales_order_id INTO v_so_id
    FROM public."ManufacturingOrders" WHERE id = v_mo_id;

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
        SET status = 'Delivered', updated_at = now()
        WHERE id = v_so_id AND status <> 'Delivered';
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
$fn$;;
