-- ============================================================================
-- Restore manufacturing timeline status events
-- - transition_mo_status should write ActivityTimeline entries
-- - advance_mo_line_status should write line progress entries on MO timeline
-- - trg_mol_status_derive_mo should write header status changes derived from lines
-- ============================================================================

SET search_path = public;

CREATE OR REPLACE FUNCTION public.transition_mo_status(
  p_mo_id uuid,
  p_new_status text,
  p_user_id uuid,
  p_user_name text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_mo record;
  v_from text;
  v_to text;
  v_allowed text[];
  v_readiness jsonb;
  v_has_shortage boolean;
  v_gate record;
  v_actor_name text;
  v_use_delivery_override boolean := false;
  v_active_override_id uuid := NULL;
  v_unallocated_count int;
BEGIN
  SELECT * INTO v_mo
  FROM "ManufacturingOrders"
  WHERE id = p_mo_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MO not found');
  END IF;

  v_from := COALESCE(v_mo.status::text, 'draft');
  v_to := lower(trim(p_new_status));
  v_actor_name := COALESCE(NULLIF(trim(p_user_name), ''), 'System');

  IF v_to = 'planned' THEN
    v_to := 'confirmed';
  END IF;

  v_allowed := CASE v_from
    WHEN 'draft' THEN ARRAY['confirmed', 'cancelled']
    WHEN 'confirmed' THEN ARRAY['procurement', 'materials_ready', 'cancelled', 'draft']
    WHEN 'procurement' THEN ARRAY['materials_ready', 'cancelled', 'confirmed']
    WHEN 'materials_ready' THEN ARRAY['in_production', 'cancelled']
    WHEN 'planned' THEN ARRAY['in_production', 'materials_ready', 'confirmed', 'cancelled']
    WHEN 'in_production' THEN ARRAY['quality_check', 'cancelled']
    WHEN 'quality_check' THEN ARRAY['ready_for_pickup']
    WHEN 'ready_for_pickup' THEN ARRAY['delivered']
    WHEN 'delivered' THEN ARRAY['completed']
    WHEN 'completed' THEN ARRAY[]::text[]
    WHEN 'cancelled' THEN ARRAY['draft']
    ELSE ARRAY[]::text[]
  END;

  IF NOT (v_to = ANY(v_allowed)) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('Invalid transition: %s -> %s. Allowed: %s', v_from, v_to, array_to_string(v_allowed, ', ')),
      'from', v_from,
      'to', v_to
    );
  END IF;

  IF v_to = 'materials_ready' THEN
    SELECT COUNT(*) INTO v_unallocated_count
    FROM manufacturing_order_material_demand md
    LEFT JOIN (
      SELECT catalog_item_id, SUM(allocated_qty) AS total_alloc
      FROM "InventoryAllocations"
      WHERE manufacturing_order_id = p_mo_id
        AND status = 'reserved'
      GROUP BY catalog_item_id
    ) a ON a.catalog_item_id = md.catalog_item_id
    WHERE md.manufacturing_order_id = p_mo_id
      AND COALESCE(a.total_alloc, 0) < md.required_qty - 0.0001;

    IF v_unallocated_count > 0 THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', format('%s material(s) not fully allocated. Allocate all materials before marking as Materials Ready.', v_unallocated_count),
        'from', v_from,
        'to', v_to,
        'unallocated_count', v_unallocated_count
      );
    END IF;
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
        'error', format('Delivery blocked: balance due is $%s.', to_char(COALESCE(v_gate.balance_due, 0), 'FM999999990.00')),
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
  WHERE id = p_mo_id
    AND deleted = false;

  INSERT INTO public."ActivityTimeline" (
    organization_id,
    entity_type,
    entity_id,
    action,
    description,
    user_id,
    user_name,
    metadata
  ) VALUES (
    v_mo.organization_id,
    'manufacturing_order',
    p_mo_id,
    'status_changed',
    format('MO status changed: %s -> %s', replace(v_from, '_', ' '), replace(v_to, '_', ' ')),
    p_user_id,
    v_actor_name,
    jsonb_build_object('from', v_from, 'to', v_to, 'source', 'transition_mo_status')
  );

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
$function$;

CREATE OR REPLACE FUNCTION public.advance_mo_line_status(
  p_line_id uuid,
  p_new_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_line RECORD;
  v_readiness RECORD;
  v_wo_result jsonb;
  v_allowed jsonb;
  v_actor_id uuid;
  v_actor_name text;
  v_valid_transitions jsonb := '{
    "draft":           ["reviewed", "cancelled"],
    "reviewed":        ["materials_ready", "confirmed", "cancelled"],
    "confirmed":       ["materials_ready", "cancelled"],
    "materials_ready": ["in_production", "cancelled"],
    "in_production":   ["completed", "cancelled"],
    "cancelled":       ["draft"],
    "completed":       []
  }'::jsonb;
BEGIN
  SELECT mol.*, mo.id AS mo_id, mo.organization_id
  INTO v_line
  FROM "ManufacturingOrderLines" mol
  JOIN "ManufacturingOrders" mo ON mo.id = mol.manufacturing_order_id
  WHERE mol.id = p_line_id
    AND mol.deleted = false
    AND mo.deleted = false;

  IF v_line IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Line not found');
  END IF;

  v_allowed := v_valid_transitions -> v_line.status;
  IF v_allowed IS NULL OR NOT v_allowed ? p_new_status THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', format('Cannot transition from %s to %s', v_line.status, p_new_status)
    );
  END IF;

  IF p_new_status = 'materials_ready' THEN
    SELECT r.readiness_status INTO v_readiness
    FROM public.get_mo_line_material_readiness(v_line.mo_id) r
    WHERE r.sales_order_line_id = v_line.sales_order_line_id
    LIMIT 1;

    IF v_readiness IS NULL OR v_readiness.readiness_status != 'ok' THEN
      RETURN jsonb_build_object(
        'ok', false,
        'error', 'Cannot mark material ready: materials are not fully allocated for this line'
      );
    END IF;
  END IF;

  v_actor_id := auth.uid();
  v_actor_name := COALESCE(
    (SELECT au.name FROM public."AppUsers" au WHERE au.auth_user_id = v_actor_id LIMIT 1),
    'System'
  );

  UPDATE "ManufacturingOrderLines"
  SET status = p_new_status,
      updated_at = now()
  WHERE id = p_line_id;

  INSERT INTO public."ActivityTimeline" (
    organization_id,
    entity_type,
    entity_id,
    action,
    description,
    user_id,
    user_name,
    metadata
  ) VALUES (
    v_line.organization_id,
    'manufacturing_order',
    v_line.mo_id,
    'line_status_changed',
    format('MO line status changed: %s -> %s', replace(v_line.status, '_', ' '), replace(p_new_status, '_', ' ')),
    v_actor_id,
    v_actor_name,
    jsonb_build_object(
      'line_id', p_line_id,
      'sales_order_line_id', v_line.sales_order_line_id,
      'from', v_line.status,
      'to', p_new_status,
      'source', 'advance_mo_line_status'
    )
  );

  IF p_new_status = 'in_production' AND v_line.sales_order_line_id IS NOT NULL THEN
    v_wo_result := public.generate_work_orders_for_line(
      v_line.mo_id,
      v_line.sales_order_line_id,
      false
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'status', p_new_status,
    'wo_generated', COALESCE(v_wo_result->>'ok' = 'true', false)
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_mol_status_derive_mo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_mo_id       uuid;
  v_org_id      uuid;
  v_all_count   int;
  v_completed   int;
  v_in_prod     int;
  v_confirmed   int;
  v_reviewed    int;
  v_cancelled   int;
  v_new_status  text;
  v_current     text;
BEGIN
  v_mo_id := COALESCE(NEW.manufacturing_order_id, OLD.manufacturing_order_id);

  SELECT status::text, organization_id INTO v_current, v_org_id
  FROM "ManufacturingOrders"
  WHERE id = v_mo_id
    AND deleted = false;

  IF v_current IS NULL THEN
    RETURN NEW;
  END IF;

  -- Never override post-production statuses set via transition_mo_status.
  IF v_current IN ('quality_check', 'ready_for_pickup', 'delivered') THEN
    RETURN NEW;
  END IF;

  SELECT
    count(*),
    count(*) FILTER (WHERE status = 'completed'),
    count(*) FILTER (WHERE status = 'in_production'),
    count(*) FILTER (WHERE status = 'confirmed'),
    count(*) FILTER (WHERE status = 'reviewed'),
    count(*) FILTER (WHERE status = 'cancelled')
  INTO v_all_count, v_completed, v_in_prod, v_confirmed, v_reviewed, v_cancelled
  FROM "ManufacturingOrderLines"
  WHERE manufacturing_order_id = v_mo_id
    AND deleted = false;

  IF v_all_count = 0 THEN
    RETURN NEW;
  END IF;

  IF v_cancelled = v_all_count THEN
    v_new_status := 'cancelled';
  ELSIF v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'completed';
  ELSIF v_in_prod > 0 THEN
    v_new_status := 'in_production';
  ELSIF v_confirmed + v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'materials_ready';
  ELSIF v_reviewed + v_confirmed + v_completed + v_cancelled = v_all_count THEN
    v_new_status := 'confirmed';
  ELSE
    v_new_status := 'draft';
  END IF;

  IF v_new_status IS DISTINCT FROM v_current THEN
    UPDATE "ManufacturingOrders"
    SET status = v_new_status::manufacturing_order_status,
        updated_at = now(),
        production_started_at = CASE
          WHEN v_new_status = 'in_production' AND production_started_at IS NULL THEN now()
          ELSE production_started_at
        END,
        completed_at = CASE
          WHEN v_new_status = 'completed' AND completed_at IS NULL THEN now()
          ELSE completed_at
        END
    WHERE id = v_mo_id
      AND deleted = false;

    INSERT INTO public."ActivityTimeline" (
      organization_id,
      entity_type,
      entity_id,
      action,
      description,
      user_id,
      user_name,
      metadata
    ) VALUES (
      v_org_id,
      'manufacturing_order',
      v_mo_id,
      'status_changed',
      format('MO status changed: %s -> %s', replace(v_current, '_', ' '), replace(v_new_status, '_', ' ')),
      auth.uid(),
      'System',
      jsonb_build_object('from', v_current, 'to', v_new_status, 'source', 'trg_mol_status_derive_mo')
    );
  END IF;

  RETURN NEW;
END;
$function$;
