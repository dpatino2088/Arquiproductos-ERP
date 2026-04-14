-- Align MO material readiness with line allocation-based readiness
-- so list/dashboard and line details use the same source of truth.
SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_mo_material_readiness(p_mo_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_total_lines int := 0;
  v_short_lines int := 0;
BEGIN
  SELECT count(*),
         count(*) FILTER (WHERE r.has_shortage)
    INTO v_total_lines, v_short_lines
  FROM public.get_mo_line_material_readiness(p_mo_id) r;

  IF v_total_lines = 0 THEN
    RETURN jsonb_build_object(
      'ok', true,
      'status', 'incomplete',
      'has_shortage', true,
      'reason', 'no_line_readiness'
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'status', CASE WHEN v_short_lines > 0 THEN 'incomplete' ELSE 'complete' END,
    'has_shortage', (v_short_lines > 0),
    'lines_total', v_total_lines,
    'lines_short', v_short_lines
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_mo_material_readiness_batch(p_mo_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_mo_id    uuid;
  v_result   jsonb;
  v_results  jsonb := '[]'::jsonb;
BEGIN
  IF p_mo_ids IS NULL OR array_length(p_mo_ids, 1) IS NULL THEN
    RETURN v_results;
  END IF;

  FOREACH v_mo_id IN ARRAY p_mo_ids
  LOOP
    v_result := public.get_mo_material_readiness(v_mo_id);
    v_results := v_results || jsonb_build_array(
      jsonb_build_object(
        'mo_id', v_mo_id,
        'status', v_result->>'status',
        'has_shortage', COALESCE((v_result->>'has_shortage')::boolean, true)
      )
    );
  END LOOP;

  RETURN v_results;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_mo_material_readiness(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_mo_material_readiness_batch(uuid[]) TO authenticated;
