
CREATE OR REPLACE FUNCTION public.reset_bom_for_manufacturing_order(p_manufacturing_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_mo record;
  v_bom_ids uuid[];
  v_lines_deleted int := 0;
  v_instances_deleted int := 0;
BEGIN
  SELECT * INTO v_mo FROM "ManufacturingOrders" WHERE id = p_manufacturing_order_id AND deleted = false;
  IF NOT FOUND THEN RAISE EXCEPTION 'Manufacturing Order not found'; END IF;

  SELECT ARRAY_AGG(id) INTO v_bom_ids
  FROM "BOMInstances"
  WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

  IF v_bom_ids IS NULL OR array_length(v_bom_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'instances_deleted', 0, 'lines_deleted', 0);
  END IF;

  UPDATE "BOMInstanceLines"
  SET deleted = true, updated_at = now()
  WHERE bom_instance_id = ANY(v_bom_ids) AND deleted = false;
  GET DIAGNOSTICS v_lines_deleted = ROW_COUNT;

  UPDATE "BOMInstances"
  SET deleted = true, updated_at = now()
  WHERE id = ANY(v_bom_ids) AND deleted = false;
  GET DIAGNOSTICS v_instances_deleted = ROW_COUNT;

  RETURN jsonb_build_object('ok', true, 'instances_deleted', v_instances_deleted, 'lines_deleted', v_lines_deleted);
END;
$function$;
;
