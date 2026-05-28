-- Repair the preview wrapper so it calls compute_cut_breakdown_core with full args.
-- An out-of-band patch had pointed it to legacy compute_template_cut_breakdown(p_bom_template_id, p_org_id),
-- which ignores config_snapshot, panel_count, placement_section, qty_type=per_joint, etc.

CREATE OR REPLACE FUNCTION public.compute_template_cut_breakdown_preview(
  p_bom_template_id uuid,
  p_org_id uuid,
  p_config_snapshot jsonb DEFAULT '{}'::jsonb,
  p_width_mm numeric DEFAULT NULL,
  p_height_mm numeric DEFAULT NULL,
  p_panel_count integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_panel_count integer := COALESCE(p_panel_count, 1);
BEGIN
  IF p_config_snapshot IS NOT NULL
     AND jsonb_typeof(p_config_snapshot -> 'panels') = 'array'
     AND jsonb_array_length(p_config_snapshot -> 'panels') > 0 THEN
    v_panel_count := jsonb_array_length(p_config_snapshot -> 'panels');
  END IF;

  RETURN public.compute_cut_breakdown_core(
    p_org_id          => p_org_id,
    p_bom_template_id => p_bom_template_id,
    p_config_snapshot => COALESCE(p_config_snapshot, '{}'::jsonb),
    p_width_mm        => p_width_mm,
    p_height_mm       => p_height_mm,
    p_panel_count     => GREATEST(v_panel_count, 1)
  );
END;
$$;

COMMENT ON FUNCTION public.compute_template_cut_breakdown_preview(uuid, uuid, jsonb, numeric, numeric, integer)
IS 'Preview wrapper. Delegates to compute_cut_breakdown_core (placement_section + per_joint + N-1 aware).';
