-- Hotfix: avoid unassigned record access in transition_mo_status.
-- The previous version could reference v_gate fields in conditions where
-- the record was never assigned, causing:
-- "record v_gate is not assigned yet".

SET search_path = public;

CREATE OR REPLACE FUNCTION public.transition_mo_status(
  p_mo_id      uuid,
  p_new_status text,
  p_user_id    uuid,
  p_user_name  text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mo                  record;
  v_from                text;
  v_to                  text;
  v_allowed             text[];
  v_readiness           jsonb;
  v_has_shortage        boolean;
  v_gate                record;
  v_actor_name          text;
  v_use_delivery_override boolean := false;
  v_active_override_id  uuid := NULL;
BEGIN
  SELECT * INTO v_mo FROM "ManufacturingOrders" WHERE id = p_mo_id AND deleted = false;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  v_from := COALESCE(v_mo.status::text, 'draft');
  v_to   := lower(trim(p_new_status));
  v_actor_name := COALESCE(NULLIF(trim(p_user_name), ''), 'System');

  v_allowed := CASE v_from
    WHEN 'draft'            THEN ARRAY['confirmed', 'planned', 'procurement', 'materials_ready', 'in_production', 'cancelled']
    WHEN 'confirmed'        THEN ARRAY['procurement', 'materials_ready', 'planned', 'in_production', 'cancelled', 'draft']
    WHEN 'procurement'      THEN ARRAY['materials_ready', 'in_production', 'cancelled', 'confirmed']
    WHEN 'materials_ready'  THEN ARRAY['in_production', 'cancelled']
    WHEN 'planned'          THEN ARRAY['in_production', 'cancelled', 'draft']
    WHEN 'in_production'    THEN ARRAY['quality_check', 'cancelled']
    WHEN 'quality_check'    THEN ARRAY['ready_for_pickup']
    WHEN 'ready_for_pickup' THEN ARRAY['delivered']
    WHEN 'delivered'        THEN ARRAY['completed']
    WHEN 'completed'        THEN ARRAY[]::text[]
    WHEN 'cancelled'        THEN ARRAY['draft']
    ELSE ARRAY[]::text[]
  END;

  IF NOT (v_to = ANY(v_allowed)) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('Invalid transition: %s → %s. Allowed: %s', v_from, v_to, array_to_string(v_allowed, ', ')),
      'from', v_from,
      'to', v_to
    );
  END IF;

  IF v_to = 'in_production' THEN
    v_readiness := public.get_mo_material_readiness(p_mo_id);
    v_has_shortage := COALESCE((v_readiness->>'has_shortage')::boolean, false);
    IF v_has_shortage THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Materials incomplete. All materials must be on hand or on order before starting production.',
        'from', v_from,
        'to', v_to,
        'material_readiness', v_readiness
      );
    END IF;
  END IF;

  IF v_to = 'delivered' AND v_mo.sales_order_id IS NOT NULL THEN
    SELECT * INTO v_gate
    FROM public.get_sales_order_delivery_gate(v_mo.sales_order_id);

    IF NOT COALESCE(v_gate.delivery_allowed, false) THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', format('Delivery blocked: balance due is $%s. Financials must settle to 0.00 or issue override.', to_char(COALESCE(v_gate.balance_due, 0), 'FM999999990.00')),
        'from', v_from,
        'to', v_to,
        'balance_due', COALESCE(v_gate.balance_due, 0)
      );
    END IF;

    v_use_delivery_override := COALESCE(v_gate.payment_complete, false) = false
      AND v_gate.active_override_id IS NOT NULL;
    v_active_override_id := v_gate.active_override_id;
  END IF;

  UPDATE "ManufacturingOrders"
  SET status = v_to::manufacturing_order_status,
      updated_at = now(),
      production_started_at = CASE
        WHEN v_to = 'in_production' AND production_started_at IS NULL THEN now()
        ELSE production_started_at
      END,
      completed_at = CASE
        WHEN v_to IN ('delivered', 'completed') AND completed_at IS NULL THEN now()
        ELSE completed_at
      END,
      delivered_at = CASE
        WHEN v_to = 'delivered' AND delivered_at IS NULL THEN now()
        ELSE delivered_at
      END
  WHERE id = p_mo_id AND deleted = false;

  IF v_use_delivery_override AND v_active_override_id IS NOT NULL THEN
    UPDATE public."SalesOrderDeliveryOverrides"
    SET status = 'used',
        used_by = p_user_id,
        used_by_name = v_actor_name,
        used_source = 'mo_transition',
        used_at = now(),
        updated_at = now()
    WHERE id = v_active_override_id
      AND status = 'active'
      AND deleted = false;
  END IF;

  RETURN jsonb_build_object('ok', true, 'from', v_from, 'to', v_to);
END;
$$;

GRANT EXECUTE ON FUNCTION public.transition_mo_status(uuid, text, uuid, text) TO authenticated;;
