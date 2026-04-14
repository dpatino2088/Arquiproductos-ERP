
CREATE OR REPLACE FUNCTION public.transition_mo_status(
  p_mo_id uuid,
  p_new_status text,
  p_user_id uuid,
  p_user_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_mo record;
  v_valid boolean := false;
  v_old text;
BEGIN
  SELECT * INTO v_mo FROM "ManufacturingOrders" WHERE id = p_mo_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'MO not found'; END IF;
  v_old := v_mo.status::text;

  v_valid := (v_old = 'draft' AND p_new_status = 'planned')
          OR (v_old = 'planned' AND p_new_status = 'in_production')
          OR (v_old = 'in_production' AND p_new_status = 'quality_check')
          OR (v_old = 'quality_check' AND p_new_status = 'ready_for_pickup')
          OR (v_old = 'ready_for_pickup' AND p_new_status = 'delivered')
          OR (v_old IN ('draft','planned','in_production') AND p_new_status = 'cancelled');

  IF NOT v_valid THEN RAISE EXCEPTION 'Invalid transition: % -> %', v_old, p_new_status; END IF;

  UPDATE "ManufacturingOrders" SET
    status = p_new_status::manufacturing_order_status,
    released_at = CASE WHEN p_new_status = 'planned' THEN now() ELSE released_at END,
    production_started_at = CASE WHEN p_new_status = 'in_production' THEN now() ELSE production_started_at END,
    completed_at = CASE WHEN p_new_status IN ('quality_check','delivered') THEN now() ELSE completed_at END,
    delivered_at = CASE WHEN p_new_status = 'delivered' THEN now() ELSE delivered_at END,
    updated_at = now()
  WHERE id = p_mo_id;

  PERFORM _insert_timeline(v_mo.organization_id, 'manufacturing_order', p_mo_id, 'status_changed',
    'Status changed from ' || v_old || ' to ' || p_new_status, p_user_id, p_user_name,
    jsonb_build_object('from', v_old, 'to', p_new_status));

  RETURN jsonb_build_object('ok', true, 'from', v_old, 'to', p_new_status);
END;
$function$;
;
