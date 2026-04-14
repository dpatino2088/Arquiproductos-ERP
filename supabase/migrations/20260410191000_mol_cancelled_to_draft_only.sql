-- Allow rollback only from cancelled to draft at MOL level
SET search_path = public;

CREATE OR REPLACE FUNCTION public.advance_mo_line_status(p_line_id uuid, p_new_status text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
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
    "cancelled":       ["draft"],
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

GRANT EXECUTE ON FUNCTION public.advance_mo_line_status(uuid, text) TO authenticated;
