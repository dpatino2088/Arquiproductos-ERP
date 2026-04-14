-- ============================================================================
-- Align MOL status flow: reviewed → materials_ready (direct, auto on allocate)
-- Move WO generation to materials_ready → in_production transition.
-- ============================================================================

SET search_path = public;

-- Ensure materials_ready is in the MOL status constraint
ALTER TABLE public."ManufacturingOrderLines"
  DROP CONSTRAINT IF EXISTS "ManufacturingOrderLines_status_check";

ALTER TABLE public."ManufacturingOrderLines"
  ADD CONSTRAINT "ManufacturingOrderLines_status_check"
  CHECK (status = ANY (ARRAY[
    'draft'::text,
    'reviewed'::text,
    'confirmed'::text,
    'materials_ready'::text,
    'in_production'::text,
    'completed'::text,
    'cancelled'::text
  ]));

CREATE OR REPLACE FUNCTION public.advance_mo_line_status(
  p_line_id uuid,
  p_new_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_line RECORD;
  v_readiness RECORD;
  v_wo_result jsonb;
  v_valid_transitions jsonb := '{
    "draft":           ["reviewed", "cancelled"],
    "reviewed":        ["materials_ready", "confirmed", "cancelled"],
    "confirmed":       ["materials_ready", "cancelled"],
    "materials_ready": ["in_production", "cancelled"],
    "in_production":   ["completed", "cancelled"],
    "completed":       []
  }'::jsonb;
  v_allowed jsonb;
BEGIN
  SELECT mol.*, mo.id AS mo_id
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

  -- Gate: materials_ready requires allocation-based readiness = ok
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

  UPDATE "ManufacturingOrderLines"
  SET status = p_new_status, updated_at = now()
  WHERE id = p_line_id;

  -- Generate Work Orders when line moves to in_production
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
$$;

GRANT EXECUTE ON FUNCTION public.advance_mo_line_status(uuid, text) TO authenticated;

-- Also update sync helper to promote reviewed lines (not just confirmed)
CREATE OR REPLACE FUNCTION public.sync_mo_material_ready_from_allocations(
  p_mo_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_changed_lines int := 0;
  v_open_lines int := 0;
  v_header_changed int := 0;
BEGIN
  WITH ready_lines AS (
    SELECT mol.id
    FROM "ManufacturingOrderLines" mol
    JOIN public.get_mo_line_material_readiness(p_mo_id) lr
      ON lr.sales_order_line_id = mol.sales_order_line_id
    WHERE mol.manufacturing_order_id = p_mo_id
      AND mol.deleted = false
      AND mol.status IN ('reviewed', 'confirmed')
      AND lr.readiness_status = 'ok'
  )
  UPDATE "ManufacturingOrderLines" mol
  SET status = 'materials_ready',
      updated_at = now()
  FROM ready_lines rl
  WHERE mol.id = rl.id;

  GET DIAGNOSTICS v_changed_lines = ROW_COUNT;

  SELECT count(*)
  INTO v_open_lines
  FROM "ManufacturingOrderLines"
  WHERE manufacturing_order_id = p_mo_id
    AND deleted = false
    AND status NOT IN ('materials_ready', 'in_production', 'completed', 'cancelled');

  IF COALESCE(v_open_lines, 0) = 0 THEN
    UPDATE "ManufacturingOrders"
    SET status = 'materials_ready'::manufacturing_order_status,
        updated_at = now()
    WHERE id = p_mo_id
      AND deleted = false
      AND status::text IN ('draft', 'confirmed', 'procurement');
    GET DIAGNOSTICS v_header_changed = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'line_updates', v_changed_lines,
    'mo_updated', v_header_changed > 0
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_mo_material_ready_from_allocations(uuid) TO authenticated;

-- Update enforce WO insert gate to allow materials_ready lines
CREATE OR REPLACE FUNCTION public.enforce_workorder_insert_on_confirmed_mo()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_status text;
  v_has_ready_lines boolean;
BEGIN
  SELECT mo.status::text
  INTO v_status
  FROM public."ManufacturingOrders" mo
  WHERE mo.id = NEW.manufacturing_order_id
    AND mo.deleted = false;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Manufacturing Order not found for Work Order task.';
  END IF;

  IF v_status IN ('materials_ready', 'planned', 'in_production') THEN
    RETURN NEW;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = NEW.manufacturing_order_id
      AND deleted = false
      AND status IN ('materials_ready', 'in_production', 'completed')
  ) INTO v_has_ready_lines;

  IF v_has_ready_lines THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Work Orders can only be generated when MO or its lines have materials ready (current MO status: %).', v_status;
END;
$$;
