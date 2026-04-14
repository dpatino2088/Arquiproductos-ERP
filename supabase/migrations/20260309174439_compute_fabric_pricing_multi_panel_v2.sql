CREATE OR REPLACE FUNCTION public.compute_fabric_pricing_from_rule(
  p_org_id uuid,
  p_product_type_id uuid,
  p_style_code text,
  p_height_m numeric,
  p_width_m numeric,
  p_roll_width_m numeric,
  p_msrp_per_m numeric,
  p_dimension_outputs jsonb DEFAULT NULL
)
RETURNS TABLE(
  qty numeric,
  pricing_uom text,
  unit_price numeric,
  area_base_m2 numeric,
  drops numeric,
  waste_pct numeric,
  fabric_cut_width_mm numeric,
  fabric_cut_height_mm numeric,
  fabric_width_used_m numeric,
  panel_detail jsonb
)
LANGUAGE plpgsql STABLE
AS $function$
DECLARE
    v_r RECORD;
    v_heff numeric;
    v_weff numeric;
    v_area numeric;
    v_drops numeric;
    v_qty numeric;
    v_uom text;
    v_unit_price numeric;
    v_cut_height numeric;
    v_cut_width numeric;
    v_fabric_width_needed numeric;
    v_panels_count numeric;
    v_dim_outputs jsonb;
    v_fw_source_mm numeric;
    v_has_panel_cuts boolean := false;
    v_panel_cuts jsonb;
    v_pc jsonb;
    v_panel_tube_mm numeric;
    v_panel_weff numeric;
    v_panel_area numeric;
    v_panel_drops numeric;
    v_panel_detail_arr jsonb := '[]'::jsonb;
    v_total_area numeric := 0;
    v_total_drops numeric := 0;
    v_total_weff numeric := 0;
BEGIN
    qty := NULL; pricing_uom := NULL; unit_price := NULL;
    area_base_m2 := NULL; drops := NULL; waste_pct := NULL;
    fabric_cut_width_mm := NULL; fabric_cut_height_mm := NULL;
    fabric_width_used_m := NULL; panel_detail := NULL;

    SELECT * INTO v_r FROM public.select_fabric_rule(p_org_id, p_product_type_id, p_style_code) LIMIT 1;
    IF NOT FOUND THEN RETURN; END IF;

    v_dim_outputs := COALESCE(p_dimension_outputs, '{}'::jsonb);
    waste_pct := COALESCE(v_r.waste_pct, 0);

    v_has_panel_cuts := (v_dim_outputs ? 'tube_panel_cuts')
                        AND COALESCE(v_r.fabric_width_source, 'finished_width') = 'tube_width';

    IF COALESCE(v_r.panel_multiplier, 1) > 0 AND (
         COALESCE(v_r.tube_wrap_mm, 0) > 0 OR
         COALESCE(v_r.bottom_wrap_mm, 0) > 0 OR
         COALESCE(v_r.safety_margin_mm, 0) > 0 OR
         COALESCE(v_r.panel_multiplier, 1) != 1
       ) THEN
      v_heff := (COALESCE(p_height_m, 0) * COALESCE(v_r.panel_multiplier, 1))
              + (COALESCE(v_r.tube_wrap_mm, 0) / 1000.0)
              + (COALESCE(v_r.bottom_wrap_mm, 0) / 1000.0)
              + (COALESCE(v_r.safety_margin_mm, 0) / 1000.0);
    ELSE
      v_heff := COALESCE(p_height_m, 0) * COALESCE(v_r.height_multiplier, 1) + COALESCE(v_r.extra_height_m, 0);
    END IF;

    fabric_cut_height_mm := ROUND(v_heff * 1000.0, 1);

    IF v_has_panel_cuts AND COALESCE(v_r.formula_code, '') = 'ROLLER_DROPS' THEN
      v_panel_cuts := v_dim_outputs->'tube_panel_cuts';

      FOR v_pc IN SELECT value FROM jsonb_array_elements(v_panel_cuts) AS value LOOP
        v_panel_tube_mm := COALESCE((v_pc->>'tube_width_mm')::numeric, 0);
        v_panel_weff := v_panel_tube_mm / 1000.0;

        IF p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN
          v_panel_area := v_heff * v_panel_weff;
          v_panel_drops := NULL;
        ELSE
          v_panel_drops := CEIL(v_panel_weff / p_roll_width_m);
          v_panel_area := v_heff * v_panel_drops * p_roll_width_m;
        END IF;

        v_total_area := v_total_area + v_panel_area;
        v_total_drops := v_total_drops + COALESCE(v_panel_drops, 1);
        v_total_weff := v_total_weff + v_panel_weff;

        v_panel_detail_arr := v_panel_detail_arr || jsonb_build_object(
          'index', (v_pc->>'index')::integer,
          'position', v_pc->>'position',
          'tube_width_mm', v_panel_tube_mm,
          'fabric_cut_width_mm', ROUND(v_panel_tube_mm, 1),
          'drops', v_panel_drops,
          'area_m2', ROUND(v_panel_area, 4)
        );
      END LOOP;

      v_area := v_total_area;
      v_drops := v_total_drops;
      v_weff := v_total_weff;
      v_fw_source_mm := v_total_weff * 1000.0;
      fabric_cut_width_mm := NULL;
      fabric_width_used_m := ROUND(v_total_weff, 4);
      panel_detail := v_panel_detail_arr;

    ELSE
      CASE COALESCE(v_r.fabric_width_source, 'finished_width')
        WHEN 'tube_width' THEN
          v_fw_source_mm := COALESCE(
            (v_dim_outputs->>'tube_width_mm')::numeric,
            COALESCE(p_width_m, 0) * 1000.0
          );
          v_weff := v_fw_source_mm / 1000.0;
        WHEN 'bottom_bar_width' THEN
          v_fw_source_mm := COALESCE(
            (v_dim_outputs->>'bottom_bar_width_mm')::numeric,
            COALESCE(p_width_m, 0) * 1000.0
          );
          v_weff := v_fw_source_mm / 1000.0;
        WHEN 'track_width' THEN
          v_fw_source_mm := COALESCE(
            (v_dim_outputs->>'track_width_mm')::numeric,
            COALESCE(p_width_m, 0) * 1000.0
          );
          v_weff := v_fw_source_mm / 1000.0;
        WHEN 'finished_width_x_fullness' THEN
          v_weff := COALESCE(p_width_m, 0) * COALESCE(v_r.fullness_factor, 1);
          v_fw_source_mm := v_weff * 1000.0;
        ELSE
          v_weff := COALESCE(p_width_m, 0) * COALESCE(v_r.width_multiplier, 1) + COALESCE(v_r.extra_width_m, 0);
          v_fw_source_mm := v_weff * 1000.0;
      END CASE;

      fabric_cut_width_mm := ROUND(v_fw_source_mm, 1);
      fabric_width_used_m := ROUND(v_weff, 4);

      IF COALESCE(v_r.formula_code, '') = 'ROLLER_DROPS' THEN
          IF p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN
              v_area := v_heff * v_weff;
              v_drops := NULL;
          ELSE
              v_drops := CEIL(v_weff / p_roll_width_m);
              v_area := v_heff * v_drops * p_roll_width_m;
          END IF;
      ELSIF COALESCE(v_r.formula_code, '') = 'AREA_BASED' THEN
          v_area := v_heff * (v_weff * COALESCE(v_r.fullness_factor, 1));
          v_drops := NULL;
      ELSIF COALESCE(v_r.formula_code, '') = 'DRAPERY_PANELS' THEN
          v_cut_height := COALESCE(p_height_m, 0)
                        + COALESCE(v_r.top_hem_cm, 0) / 100.0
                        + COALESCE(v_r.bottom_hem_cm, 0) / 100.0;
          v_fabric_width_needed := v_weff;
          IF p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN
              v_panels_count := 1;
          ELSE
              v_panels_count := CEIL(v_fabric_width_needed / p_roll_width_m);
          END IF;
          v_drops := v_panels_count;
          v_area := v_panels_count * v_cut_height * COALESCE(p_roll_width_m, v_fabric_width_needed);
          fabric_cut_height_mm := ROUND(v_cut_height * 1000.0, 1);
      ELSE
          v_area := v_heff * v_weff;
          v_drops := NULL;
      END IF;
    END IF;

    area_base_m2 := v_area;

    IF COALESCE(v_r.pricing_output_uom, 'm2') = 'm' THEN
        IF p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN
            v_qty := v_area;
            v_uom := 'm2';
            v_unit_price := p_msrp_per_m;
        ELSE
            v_qty := v_area / p_roll_width_m;
            v_uom := 'm';
            v_unit_price := COALESCE(p_msrp_per_m, 0);
        END IF;
    ELSE
        v_qty := v_area;
        v_uom := 'm2';
        v_unit_price := CASE WHEN p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN COALESCE(p_msrp_per_m, 0)
                             ELSE COALESCE(p_msrp_per_m, 0) / p_roll_width_m END;
    END IF;

    v_qty := v_qty * (1 + waste_pct);
    v_qty := public.round_up_to_increment(v_qty, COALESCE(v_r.round_to_increment, 0));
    IF v_r.min_qty IS NOT NULL AND v_r.min_qty > 0 AND v_qty < v_r.min_qty THEN
        v_qty := v_r.min_qty;
    END IF;

    qty := v_qty;
    pricing_uom := v_uom;
    unit_price := v_unit_price;
    drops := v_drops;
    RETURN NEXT;
END;
$function$;;
