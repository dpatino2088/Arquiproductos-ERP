
DROP FUNCTION IF EXISTS public.update_bom_template_sort_orders(uuid, jsonb);

CREATE OR REPLACE FUNCTION public.update_bom_template_sort_orders(
  p_organization_id uuid,
  p_updates jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_update jsonb;
  v_updated_count integer := 0;
BEGIN
  IF p_organization_id IS NULL THEN
    RAISE EXCEPTION 'organization_id is required';
  END IF;

  IF p_updates IS NULL OR jsonb_array_length(p_updates) = 0 THEN
    RETURN jsonb_build_object('success', true, 'updated_count', 0);
  END IF;

  FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    UPDATE public."BOMTemplates"
    SET sort_order = (v_update->>'sort_order')::integer, updated_at = now()
    WHERE id = (v_update->>'id')::uuid
      AND organization_id = p_organization_id;

    IF FOUND THEN
      v_updated_count := v_updated_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'updated_count', v_updated_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_bom_template_sort_orders(uuid, jsonb) TO authenticated;
;
