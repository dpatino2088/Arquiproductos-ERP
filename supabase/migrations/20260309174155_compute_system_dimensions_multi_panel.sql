CREATE OR REPLACE FUNCTION public.compute_system_dimensions(
  p_configured_product_id uuid
) RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  v_cp RECORD;
  v_width_mm numeric;
  v_height_mm numeric;
  v_result jsonb := '{}'::jsonb;
  v_config jsonb;
  v_panels jsonb;
  v_panel_count integer;
  v_endpoint_delta numeric;
  v_joint_delta numeric;
  v_endpoint_share numeric;
  v_joint_share numeric;
  v_panel_width numeric;
  v_panel_cut numeric;
  v_panel_cuts jsonb;
  v_total_cut numeric;
  v_i integer;
  v_position text;
  v_delta_sum numeric;
BEGIN
  SELECT cp.*, bt.id AS bt_id
  INTO v_cp
  FROM "ConfiguredProducts" cp
  LEFT JOIN "BOMTemplates" bt ON bt.id = cp.bom_template_id
  WHERE cp.id = p_configured_product_id AND cp.deleted = false;

  IF NOT FOUND OR v_cp.bt_id IS NULL THEN
    RETURN v_result;
  END IF;

  v_width_mm := COALESCE(v_cp.width_mm, 0);
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_config := COALESCE(v_cp.config_snapshot, '{}'::jsonb);

  v_panels := COALESCE(
    v_config->'measurements'->'panels',
    v_config->'panels'
  );
  v_panel_count := CASE
    WHEN v_panels IS NOT NULL
         AND jsonb_typeof(v_panels) = 'array'
         AND jsonb_array_length(v_panels) > 1
    THEN jsonb_array_length(v_panels)
    ELSE 1
  END;

  SELECT COALESCE(SUM(COALESCE(bc.cut_delta_mm, 0)), 0)
  INTO v_endpoint_delta
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false AND bc.affects_role = 'tube'
    AND bc.cut_delta_mm IS NOT NULL AND bc.cut_delta_mm != 0
    AND COALESCE(bc.qty_type::text, 'fixed') != 'per_joint';

  SELECT COALESCE(SUM(COALESCE(bc.cut_delta_mm, 0)), 0)
  INTO v_joint_delta
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false AND bc.affects_role = 'tube'
    AND bc.cut_delta_mm IS NOT NULL AND bc.cut_delta_mm != 0
    AND bc.qty_type::text = 'per_joint';

  IF v_panel_count > 1 THEN
    v_endpoint_share := v_endpoint_delta / 2.0;
    v_joint_share := v_joint_delta / 2.0;
    v_panel_cuts := '[]'::jsonb;
    v_total_cut := 0;

    FOR v_i IN 0..(v_panel_count - 1) LOOP
      v_panel_width := COALESCE((v_panels->v_i->>'width_mm')::numeric, 0);

      IF v_i = 0 THEN
        v_position := 'left';
        v_panel_cut := GREATEST(0, v_panel_width + v_endpoint_share + v_joint_share);
      ELSIF v_i = v_panel_count - 1 THEN
        v_position := 'right';
        v_panel_cut := GREATEST(0, v_panel_width + v_endpoint_share + v_joint_share);
      ELSE
        v_position := 'center';
        v_panel_cut := GREATEST(0, v_panel_width + v_joint_delta);
      END IF;

      v_total_cut := v_total_cut + v_panel_cut;
      v_panel_cuts := v_panel_cuts || jsonb_build_object(
        'index', v_i + 1,
        'position', v_position,
        'panel_width_mm', v_panel_width,
        'tube_width_mm', ROUND(v_panel_cut, 1)
      );
    END LOOP;

    v_result := v_result || jsonb_build_object(
      'tube_width_mm', ROUND(v_total_cut, 1),
      'tube_panel_cuts', v_panel_cuts,
      'panel_count', v_panel_count,
      'tube_endpoint_delta_mm', v_endpoint_delta,
      'tube_joint_delta_mm', v_joint_delta
    );
  ELSE
    v_delta_sum := v_endpoint_delta + v_joint_delta;
    v_result := v_result || jsonb_build_object(
      'tube_width_mm', GREATEST(0, v_width_mm + v_delta_sum)
    );
  END IF;

  SELECT COALESCE(SUM(COALESCE(bc.cut_delta_mm, 0)), 0)
  INTO v_endpoint_delta
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false AND bc.affects_role = 'bottom_bar'
    AND bc.cut_delta_mm IS NOT NULL AND bc.cut_delta_mm != 0
    AND COALESCE(bc.qty_type::text, 'fixed') != 'per_joint';

  SELECT COALESCE(SUM(COALESCE(bc.cut_delta_mm, 0)), 0)
  INTO v_joint_delta
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false AND bc.affects_role = 'bottom_bar'
    AND bc.cut_delta_mm IS NOT NULL AND bc.cut_delta_mm != 0
    AND bc.qty_type::text = 'per_joint';

  IF v_panel_count > 1 THEN
    v_endpoint_share := v_endpoint_delta / 2.0;
    v_joint_share := v_joint_delta / 2.0;
    v_panel_cuts := '[]'::jsonb;
    v_total_cut := 0;

    FOR v_i IN 0..(v_panel_count - 1) LOOP
      v_panel_width := COALESCE((v_panels->v_i->>'width_mm')::numeric, 0);

      IF v_i = 0 THEN
        v_panel_cut := GREATEST(0, v_panel_width + v_endpoint_share + v_joint_share);
      ELSIF v_i = v_panel_count - 1 THEN
        v_panel_cut := GREATEST(0, v_panel_width + v_endpoint_share + v_joint_share);
      ELSE
        v_panel_cut := GREATEST(0, v_panel_width + v_joint_delta);
      END IF;

      v_total_cut := v_total_cut + v_panel_cut;
      v_panel_cuts := v_panel_cuts || jsonb_build_object(
        'index', v_i + 1,
        'bottom_bar_width_mm', ROUND(v_panel_cut, 1)
      );
    END LOOP;

    v_result := v_result || jsonb_build_object(
      'bottom_bar_width_mm', ROUND(v_total_cut, 1),
      'bottom_bar_panel_cuts', v_panel_cuts
    );
  ELSE
    v_delta_sum := v_endpoint_delta + v_joint_delta;
    v_result := v_result || jsonb_build_object(
      'bottom_bar_width_mm', GREATEST(0, v_width_mm + v_delta_sum)
    );
  END IF;

  SELECT COALESCE(SUM(COALESCE(bc.cut_delta_mm, 0)), 0)
  INTO v_delta_sum
  FROM "BOMComponents" bc
  WHERE bc.bom_template_id = v_cp.bt_id
    AND bc.deleted = false AND bc.affects_role = 'track'
    AND bc.cut_delta_mm IS NOT NULL AND bc.cut_delta_mm != 0;

  v_result := v_result || jsonb_build_object(
    'track_width_mm', GREATEST(0, v_width_mm + v_delta_sum)
  );

  v_result := v_result || jsonb_build_object(
    'finished_width_mm', v_width_mm,
    'finished_height_mm', v_height_mm
  );

  RETURN v_result;
END;
$$;

COMMENT ON FUNCTION public.compute_system_dimensions(uuid) IS
  'Computes tube/bottom_bar/track widths from BOM deltas with per-panel support.';;
