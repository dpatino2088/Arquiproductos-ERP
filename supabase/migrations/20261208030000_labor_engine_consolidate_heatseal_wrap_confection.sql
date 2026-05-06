-- ============================================================================
-- Labor Engine v3: consolidate heatseal, bottom-bar wrap, and confection
-- into LaborRules. Add size escalation (% per meter of width over reference).
--
-- Why this migration exists
-- -------------------------
-- Today the surcharges live in FabricRules and (for confection) are silently
-- not applied at all in the live build_bom_preview_snapshot:
--   * FabricRules.heatseal_price_per_m  → calculated in compute_fabric_pricing_from_rule
--                                         BUT the resulting heatseal_cost is only stored
--                                         in fabric_calc JSON; never summed into roll_msrp_total
--                                         or roll_total_cost. Decorative.
--   * FabricRules.bottom_bar_wrap_pct   → same: stored in fabric_calc, not summed. Decorative.
--   * FabricRules.confection_pct        → an old version of build_bom_preview_snapshot
--                                         multiplied roll_total_cost by (1+pct) but a later
--                                         migration (alternative_headbox) replaced the function
--                                         and dropped the line. Today: silent zero.
--
-- This migration moves all three to LaborRules so:
--   1) Pricing is centralized (one source of truth)
--   2) Strict mode applies (no silent miss)
--   3) Different fabrics / styles get correct treatment via the same rule resolver
--   4) Size escalation can be configured per product type
--
-- Pricing-protect: this migration does NOT change cost / dealer / msrp formulas.
-- It changes the SOURCES of labor_cost so heatseal/wrap/confection now add to it.
-- All other math (total_cost = materials + labor; dealer = total / (1-margin); etc.)
-- remains identical.
-- ============================================================================

SET search_path = public;

-- ---------------------------------------------------------------------------
-- 1) Schema: add columns to LaborRules
-- ---------------------------------------------------------------------------
ALTER TABLE public."LaborRules"
  ADD COLUMN IF NOT EXISTS size_escalation_pct                 numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS size_reference_width_m              numeric NOT NULL DEFAULT 1.0,
  ADD COLUMN IF NOT EXISTS heatseal_rate_per_m                 numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bottom_bar_wrap_rate_per_m          numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS confection_base                     numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS confection_rate_per_m2              numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS confection_size_escalation_pct      numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS confection_size_reference_width_m   numeric NOT NULL DEFAULT 1.0;

COMMENT ON COLUMN public."LaborRules".size_escalation_pct IS
  'Percent of base composite labor added per meter of width above size_reference_width_m. e.g. 0.05 with reference 1.0m: a 2.5m product pays +7.5% over the base composite.';
COMMENT ON COLUMN public."LaborRules".size_reference_width_m IS
  'Width baseline (in meters) below which no size escalation is applied.';
COMMENT ON COLUMN public."LaborRules".heatseal_rate_per_m IS
  'USD per linear meter of heat-seal length. Triggered when fabric needs rotation AND the FabricRule has a non-none heatseal_direction. Length is computed from drops × effective fabric width.';
COMMENT ON COLUMN public."LaborRules".bottom_bar_wrap_rate_per_m IS
  'USD per meter of shade width charged when the user marks "Bottom Bar Wrapped" in the configurator.';
COMMENT ON COLUMN public."LaborRules".confection_base IS
  'Fixed base charge for third-party fabric processing (drapery confection, etc.). Activates only if any confection_* field is non-zero.';
COMMENT ON COLUMN public."LaborRules".confection_rate_per_m2 IS
  'USD per m² of fabric area for third-party fabric processing.';
COMMENT ON COLUMN public."LaborRules".confection_size_escalation_pct IS
  'Percent of confection subtotal added per meter of width above confection_size_reference_width_m.';
COMMENT ON COLUMN public."LaborRules".confection_size_reference_width_m IS
  'Width baseline (in meters) below which no confection size escalation is applied.';

-- ---------------------------------------------------------------------------
-- 2) Resolver: accept new context (length/wrap/width_m) and add new contributors.
--    Output labor_cost = escalated_composite + heatseal + wrap + confection.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.resolve_labor_cost_from_rules(uuid, uuid, numeric, numeric, numeric, integer, integer, text, boolean, numeric, numeric);

CREATE OR REPLACE FUNCTION public.resolve_labor_cost_from_rules(
  p_org_id              uuid,
  p_product_type_id     uuid,
  p_width_mm            numeric,
  p_height_mm           numeric,
  p_area_m2             numeric,
  p_panel_count         integer,
  p_drops               integer,
  p_operating_type      text,
  p_has_motor           boolean,
  p_materials_cost      numeric,
  p_heatseal_length_m   numeric DEFAULT 0,
  p_bottom_bar_wrapped  boolean DEFAULT false
)
RETURNS TABLE(
  labor_cost          numeric,
  labor_pct_effective numeric,
  labor_rule_id       uuid,
  labor_meta          jsonb
)
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  v_rule public."LaborRules"%ROWTYPE;
  v_width_mm numeric := COALESCE(p_width_mm, 0);
  v_height_mm numeric := COALESCE(p_height_mm, 0);
  v_area_m2 numeric := COALESCE(p_area_m2, 0);
  v_panel_count integer := GREATEST(COALESCE(p_panel_count, 1), 1);
  v_drops integer := GREATEST(COALESCE(p_drops, 1), 1);
  v_has_motor boolean := COALESCE(p_has_motor, false);
  v_operating text := NULLIF(lower(trim(COALESCE(p_operating_type, ''))), '');
  v_materials numeric := GREATEST(COALESCE(p_materials_cost, 0), 0);
  v_hs_length numeric := GREATEST(COALESCE(p_heatseal_length_m, 0), 0);
  v_wrapped boolean := COALESCE(p_bottom_bar_wrapped, false);

  v_height_m numeric;
  v_width_m numeric;

  v_base_raw numeric := 0;       -- composite/per_x base before size escalation
  v_size_factor numeric := 1;
  v_base_escalated numeric := 0;

  v_hs_cost numeric := 0;
  v_wrap_cost numeric := 0;
  v_conf_subtotal numeric := 0;
  v_conf_factor numeric := 1;
  v_conf_cost numeric := 0;

  v_raw numeric := 0;
  v_rounded numeric := 0;
BEGIN
  SELECT lr.*
  INTO v_rule
  FROM public."LaborRules" lr
  WHERE lr.organization_id = p_org_id
    AND COALESCE(lr.is_active, true) = true
    AND (lr.product_type_id IS NULL OR lr.product_type_id = p_product_type_id)
    AND (lr.width_min_mm IS NULL OR v_width_mm >= lr.width_min_mm)
    AND (lr.width_max_mm IS NULL OR v_width_mm <= lr.width_max_mm)
    AND (lr.height_min_mm IS NULL OR v_height_mm >= lr.height_min_mm)
    AND (lr.height_max_mm IS NULL OR v_height_mm <= lr.height_max_mm)
    AND (lr.area_min_m2 IS NULL OR v_area_m2 >= lr.area_min_m2)
    AND (lr.area_max_m2 IS NULL OR v_area_m2 <= lr.area_max_m2)
    AND (lr.panel_count_min IS NULL OR v_panel_count >= lr.panel_count_min)
    AND (lr.panel_count_max IS NULL OR v_panel_count <= lr.panel_count_max)
    AND (lr.drops_min IS NULL OR v_drops >= lr.drops_min)
    AND (lr.drops_max IS NULL OR v_drops <= lr.drops_max)
    AND (
      lr.operating_type IS NULL
      OR lower(trim(lr.operating_type)) = COALESCE(v_operating, '')
    )
    AND (
      lr.motor_required IS NULL
      OR lr.motor_required = v_has_motor
    )
  ORDER BY lr.priority DESC, lr.created_at ASC
  LIMIT 1;

  IF NOT FOUND THEN
    labor_cost := NULL;
    labor_pct_effective := NULL;
    labor_rule_id := NULL;
    labor_meta := jsonb_build_object(
      'source', 'unresolved',
      'reason', 'No active LaborRule matches this configuration',
      'context', jsonb_build_object(
        'organization_id', p_org_id,
        'product_type_id', p_product_type_id,
        'width_mm', v_width_mm,
        'height_mm', v_height_mm,
        'area_m2', v_area_m2,
        'panel_count', v_panel_count,
        'drops', v_drops,
        'has_motor', v_has_motor,
        'operating_type', v_operating,
        'heatseal_length_m', v_hs_length,
        'bottom_bar_wrapped', v_wrapped
      )
    );
    RETURN NEXT;
    RETURN;
  END IF;

  v_height_m := v_height_mm / 1000.0;
  v_width_m := v_width_mm / 1000.0;

  -- --------------------------------------------------------------
  -- A) Base composite labor (install / assembly / motor add-on).
  --    Same logic as v2: pct_materials | fixed | per_m2 | per_drop
  --    | per_panel | per_height_m | per_width_m | composite.
  -- --------------------------------------------------------------
  CASE v_rule.calc_mode
    WHEN 'pct_materials' THEN
      v_base_raw := v_materials * COALESCE(v_rule.pct_materials, 0);
    WHEN 'fixed' THEN
      v_base_raw := COALESCE(v_rule.fixed_amount, 0);
    WHEN 'per_m2' THEN
      v_base_raw := COALESCE(v_rule.rate_per_m2, 0) * v_area_m2;
    WHEN 'per_drop' THEN
      v_base_raw := COALESCE(v_rule.rate_per_drop, 0) * v_drops;
    WHEN 'per_panel' THEN
      v_base_raw := COALESCE(v_rule.rate_per_panel, 0) * v_panel_count;
    WHEN 'per_height_m' THEN
      v_base_raw := COALESCE(v_rule.rate_per_height_m, 0) * v_height_m;
    WHEN 'per_width_m' THEN
      v_base_raw := COALESCE(v_rule.rate_per_width_m, 0) * v_width_m;
    WHEN 'composite' THEN
      v_base_raw := COALESCE(v_rule.fixed_amount, 0)
                  + (COALESCE(v_rule.rate_per_m2, 0) * v_area_m2)
                  + (COALESCE(v_rule.rate_per_drop, 0) * v_drops)
                  + (COALESCE(v_rule.rate_per_panel, 0) * v_panel_count)
                  + (COALESCE(v_rule.rate_per_height_m, 0) * v_height_m)
                  + (COALESCE(v_rule.rate_per_width_m, 0) * v_width_m)
                  + (CASE WHEN v_has_motor THEN COALESCE(v_rule.rate_motor_addon, 0) ELSE 0 END);
    ELSE
      labor_cost := NULL;
      labor_pct_effective := NULL;
      labor_rule_id := v_rule.id;
      labor_meta := jsonb_build_object(
        'source', 'unresolved',
        'reason', 'Rule has unknown calc_mode: ' || COALESCE(v_rule.calc_mode, 'NULL'),
        'rule_id', v_rule.id
      );
      RETURN NEXT;
      RETURN;
  END CASE;

  -- B) Size escalation on the base composite only.
  --    multiplier = 1 + size_escalation_pct × max(0, width_m - reference)
  IF COALESCE(v_rule.size_escalation_pct, 0) > 0 THEN
    v_size_factor := 1 + (v_rule.size_escalation_pct *
                          GREATEST(0, v_width_m - COALESCE(v_rule.size_reference_width_m, 1.0)));
  ELSE
    v_size_factor := 1;
  END IF;
  v_base_escalated := ROUND(v_base_raw * v_size_factor, 4);

  -- C) Heat-seal contribution (linear per meter of seam length).
  IF v_hs_length > 0 AND COALESCE(v_rule.heatseal_rate_per_m, 0) > 0 THEN
    v_hs_cost := ROUND(v_rule.heatseal_rate_per_m * v_hs_length, 4);
  END IF;

  -- D) Bottom bar wrap (linear per meter of shade width).
  IF v_wrapped AND COALESCE(v_rule.bottom_bar_wrap_rate_per_m, 0) > 0 THEN
    v_wrap_cost := ROUND(v_rule.bottom_bar_wrap_rate_per_m * v_width_m, 4);
  END IF;

  -- E) Confection (third-party fabric processing) with its own escalation.
  IF COALESCE(v_rule.confection_base, 0) > 0
     OR COALESCE(v_rule.confection_rate_per_m2, 0) > 0 THEN
    v_conf_subtotal := COALESCE(v_rule.confection_base, 0)
                     + (COALESCE(v_rule.confection_rate_per_m2, 0) * v_area_m2);
    IF COALESCE(v_rule.confection_size_escalation_pct, 0) > 0 THEN
      v_conf_factor := 1 + (v_rule.confection_size_escalation_pct *
                            GREATEST(0, v_width_m - COALESCE(v_rule.confection_size_reference_width_m, 1.0)));
    ELSE
      v_conf_factor := 1;
    END IF;
    v_conf_cost := ROUND(v_conf_subtotal * v_conf_factor, 4);
  END IF;

  -- F) Total raw, then min/max clamps and rounding.
  v_raw := v_base_escalated + v_hs_cost + v_wrap_cost + v_conf_cost;

  IF v_rule.min_charge IS NOT NULL THEN
    v_raw := GREATEST(v_raw, v_rule.min_charge);
  END IF;
  IF v_rule.max_charge IS NOT NULL THEN
    v_raw := LEAST(v_raw, v_rule.max_charge);
  END IF;

  IF COALESCE(v_rule.round_to_increment, 0) > 0 THEN
    v_rounded := public.round_up_to_increment(v_raw, v_rule.round_to_increment);
  ELSE
    v_rounded := ROUND(v_raw, 4);
  END IF;

  labor_cost := v_rounded;
  labor_pct_effective := CASE WHEN v_materials > 0 THEN v_rounded / v_materials ELSE 0 END;
  labor_rule_id := v_rule.id;
  labor_meta := jsonb_build_object(
    'source', 'labor_rule',
    'rule_id', v_rule.id,
    'display_name', v_rule.display_name,
    'calc_mode', v_rule.calc_mode,
    'priority', v_rule.priority,
    'raw_cost', ROUND(v_raw, 4),
    'rounded_cost', v_rounded,
    'materials_cost', v_materials,
    'context', jsonb_build_object(
      'width_mm', v_width_mm,
      'height_mm', v_height_mm,
      'area_m2', v_area_m2,
      'panel_count', v_panel_count,
      'drops', v_drops,
      'has_motor', v_has_motor,
      'operating_type', v_operating,
      'heatseal_length_m', v_hs_length,
      'bottom_bar_wrapped', v_wrapped
    ),
    'breakdown', jsonb_build_object(
      'base_raw', ROUND(v_base_raw, 4),
      'size_factor', v_size_factor,
      'base_escalated', v_base_escalated,
      'heatseal_cost', v_hs_cost,
      'bottom_bar_wrap_cost', v_wrap_cost,
      'confection_subtotal', ROUND(v_conf_subtotal, 4),
      'confection_factor', v_conf_factor,
      'confection_cost', v_conf_cost,
      'fixed_amount', COALESCE(v_rule.fixed_amount, 0),
      'rate_per_m2', COALESCE(v_rule.rate_per_m2, 0),
      'rate_per_drop', COALESCE(v_rule.rate_per_drop, 0),
      'rate_per_panel', COALESCE(v_rule.rate_per_panel, 0),
      'rate_per_height_m', COALESCE(v_rule.rate_per_height_m, 0),
      'rate_per_width_m', COALESCE(v_rule.rate_per_width_m, 0),
      'rate_motor_addon', COALESCE(v_rule.rate_motor_addon, 0),
      'pct_materials', COALESCE(v_rule.pct_materials, 0),
      'size_escalation_pct', COALESCE(v_rule.size_escalation_pct, 0),
      'size_reference_width_m', COALESCE(v_rule.size_reference_width_m, 1.0),
      'heatseal_rate_per_m', COALESCE(v_rule.heatseal_rate_per_m, 0),
      'bottom_bar_wrap_rate_per_m', COALESCE(v_rule.bottom_bar_wrap_rate_per_m, 0),
      'confection_base', COALESCE(v_rule.confection_base, 0),
      'confection_rate_per_m2', COALESCE(v_rule.confection_rate_per_m2, 0),
      'confection_size_escalation_pct', COALESCE(v_rule.confection_size_escalation_pct, 0),
      'confection_size_reference_width_m', COALESCE(v_rule.confection_size_reference_width_m, 1.0),
      'min_charge', COALESCE(v_rule.min_charge, 0),
      'max_charge', v_rule.max_charge
    )
  );
  RETURN NEXT;
END;
$function$;

COMMENT ON FUNCTION public.resolve_labor_cost_from_rules(
  uuid, uuid, numeric, numeric, numeric, integer, integer, text, boolean, numeric, numeric, boolean
) IS 'STRICT v3: returns NULL labor_cost when no LaborRule matches. Adds heatseal, bottom-bar wrap, and confection contributions plus size escalation on the base composite.';

-- ---------------------------------------------------------------------------
-- 3) compute_fabric_pricing_from_rule: keep computing heatseal_seams properly
--    by reading allow_rotation from FabricRule (instead of the NULL passed today).
--    Zero out the legacy heatseal_cost / bottom_bar_wrap_cost outputs since
--    LaborRules now own these costs (avoids any UI double-count).
--    The function's TABLE signature is preserved (no DROP needed).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_fabric_pricing_from_rule(
  p_org_id uuid,
  p_product_type_id uuid,
  p_style_code text,
  p_height_m numeric,
  p_width_m numeric,
  p_roll_width_m numeric,
  p_msrp_per_m numeric,
  p_dimension_outputs jsonb DEFAULT NULL,
  p_can_rotate boolean DEFAULT false,
  p_is_weldable boolean DEFAULT false,
  p_bottom_bar_wrapped boolean DEFAULT false
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
  panel_detail jsonb,
  is_rotated boolean,
  heatseal_seams integer,
  heatseal_cost numeric,
  bottom_bar_wrap_cost numeric
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
    v_rotated boolean := false;
    v_hs_seams integer := 0;
    v_can_rotate_eff boolean;
    v_is_weldable_eff boolean;
BEGIN
    qty := NULL; pricing_uom := NULL; unit_price := NULL;
    area_base_m2 := NULL; drops := NULL; waste_pct := NULL;
    fabric_cut_width_mm := NULL; fabric_cut_height_mm := NULL;
    fabric_width_used_m := NULL; panel_detail := NULL;
    is_rotated := false; heatseal_seams := 0;
    -- Legacy outputs are now permanently zero. The labor engine owns these costs.
    heatseal_cost := 0; bottom_bar_wrap_cost := 0;

    SELECT * INTO v_r FROM public.select_fabric_rule(p_org_id, p_product_type_id, p_style_code) LIMIT 1;
    IF NOT FOUND THEN RETURN; END IF;

    v_dim_outputs := COALESCE(p_dimension_outputs, '{}'::jsonb);
    waste_pct := COALESCE(v_r.waste_pct, 0);

    -- Effective rotation/weldability come from the FabricRule when caller passes NULL.
    -- This makes heatseal_seams reliable for downstream labor pricing.
    v_can_rotate_eff := COALESCE(p_can_rotate, COALESCE(v_r.allow_rotation, false));
    v_is_weldable_eff := COALESCE(p_is_weldable, COALESCE(v_r.heatseal_direction, 'none') <> 'none');

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

      IF COALESCE(v_r.formula_code, '') = 'ROLLER_DROPS'
         AND p_roll_width_m IS NOT NULL AND p_roll_width_m > 0
      THEN
          IF v_weff > p_roll_width_m AND v_can_rotate_eff THEN
              v_rotated := true;
              v_drops := CEIL(v_heff / p_roll_width_m);
              v_area := v_drops * v_weff * p_roll_width_m;

              IF v_heff > p_roll_width_m AND v_is_weldable_eff THEN
                  v_hs_seams := v_drops::integer - 1;
              END IF;
          ELSE
              v_drops := CEIL(v_weff / p_roll_width_m);
              v_area := v_heff * v_drops * p_roll_width_m;
          END IF;

      ELSIF COALESCE(v_r.formula_code, '') = 'ROLLER_DROPS' THEN
          v_area := v_heff * v_weff;
          v_drops := NULL;

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
    is_rotated := v_rotated;
    heatseal_seams := v_hs_seams;
    -- heatseal_cost / bottom_bar_wrap_cost intentionally remain 0 (legacy/decorative).
    -- Real charges are added in resolve_labor_cost_from_rules.
    RETURN NEXT;
END;
$function$;

COMMENT ON FUNCTION public.compute_fabric_pricing_from_rule IS
  'Fabric consumption engine. Computes drops/area/cut sizes and the heatseal_seams count when rotation is required and the FabricRule is weldable. heatseal_cost and bottom_bar_wrap_cost are returned as 0 (deprecated outputs); the corresponding charges now live in LaborRules and are computed inside resolve_labor_cost_from_rules.';

-- ---------------------------------------------------------------------------
-- 4) calculate_configured_product_totals: derive heatseal_length_m and
--    bottom_bar_wrapped from existing snapshot data and pass to resolver.
--    Pricing math is unchanged.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_configured_product_totals(p_configured_product_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_cp RECORD;
  v_cs RECORD;
  v_snapshot jsonb;
  v_totals jsonb;
  v_qty numeric := 1;

  v_roll_msrp_total numeric := 0;
  v_bom_total numeric := 0;
  v_accessories_total numeric := 0;
  v_msrp_product_subtotal numeric := 0;
  v_unit_msrp_total numeric := 0;
  v_labor_msrp numeric := 0;

  v_roll_cost numeric := 0;
  v_bom_cost numeric := 0;
  v_accessories_cost numeric := 0;
  v_materials_cost numeric := 0;
  v_labor_cost_resolved numeric := NULL;
  v_labor_cost numeric := 0;
  v_total_cost numeric := 0;

  v_labor_pct numeric := 0;
  v_minimum_margin_pct numeric := 0.35;
  v_msrp_margin_pct numeric := 0.65;
  v_dealer_factor numeric := 0.65;
  v_msrp_factor numeric := 0.35;

  v_unit_dealer_price numeric := 0;
  v_dealer_price_total_unit numeric := 0;
  v_msrp_total numeric := 0;

  v_panel_count integer := 1;
  v_drops integer := 1;
  v_area_m2 numeric := 0;
  v_operating_type text;
  v_has_motor boolean := false;
  v_labor_rule_id uuid;
  v_labor_meta jsonb := NULL;
  v_labor_pct_effective numeric := NULL;
  v_unresolved boolean := false;

  v_hs_seams integer := 0;
  v_fab_width_used numeric := 0;
  v_hs_length numeric := 0;
  v_bb_wrapped boolean := false;
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_totals := COALESCE(v_snapshot->'totals', '{}'::jsonb);

  IF v_cp.bom_template_id IS NOT NULL THEN
    v_snapshot := public.build_bom_preview_snapshot(
      v_cp.organization_id, v_cp.id, v_cp.bom_template_id
    );
    v_totals := COALESCE(v_snapshot->'totals', '{}'::jsonb);
  END IF;

  SELECT
    cs.labor_pct,
    cs.minimum_margin_pct,
    cs.default_msrp_pct
  INTO v_cs
  FROM public."CostSettings" cs
  WHERE cs.organization_id = v_cp.organization_id
    AND COALESCE(cs.is_active, true)
  ORDER BY cs.created_at DESC
  LIMIT 1;

  v_qty := GREATEST(COALESCE(v_cp.quantity, 1), 1);

  v_roll_msrp_total := COALESCE((v_totals->>'roll_msrp_total')::numeric, v_cp.roll_msrp_total, 0);
  v_bom_total := COALESCE((v_totals->>'bom_total')::numeric, v_cp.bom_total, 0);
  v_accessories_total := COALESCE((v_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);

  v_roll_cost := COALESCE((v_totals->>'roll_total_cost')::numeric, v_cp.roll_total_cost, 0);
  v_bom_cost := COALESCE((v_totals->>'bom_total_cost')::numeric, v_cp.bom_total_cost, 0);
  v_accessories_cost := COALESCE((v_totals->>'accessories_total_cost')::numeric, v_cp.accessories_total_cost, 0);

  IF v_qty > 1 AND (v_roll_cost > 0 OR v_roll_msrp_total > 0) THEN
    IF (v_totals->>'legacy_qty_multiplied') = 'true' THEN
      v_roll_cost := v_roll_cost / v_qty;
      v_roll_msrp_total := v_roll_msrp_total / v_qty;
    END IF;
  END IF;

  v_msrp_product_subtotal := v_roll_msrp_total + v_bom_total + v_accessories_total;

  v_minimum_margin_pct := COALESCE(v_cs.minimum_margin_pct, (v_totals->>'minimum_margin_pct')::numeric, 0.35);
  IF v_minimum_margin_pct > 1 THEN
    v_minimum_margin_pct := v_minimum_margin_pct / 100.0;
  END IF;
  v_minimum_margin_pct := LEAST(GREATEST(v_minimum_margin_pct, 0), 0.99);

  v_msrp_margin_pct := COALESCE(v_cs.default_msrp_pct, (v_totals->>'msrp_margin_pct')::numeric, (v_totals->>'default_msrp_pct')::numeric, 0.65);
  IF v_msrp_margin_pct > 1 THEN
    v_msrp_margin_pct := v_msrp_margin_pct / 100.0;
  END IF;
  v_msrp_margin_pct := LEAST(GREATEST(v_msrp_margin_pct, 0), 0.99);

  v_dealer_factor := GREATEST(0.01, 1 - v_minimum_margin_pct);
  v_msrp_factor := GREATEST(0.01, 1 - v_msrp_margin_pct);

  v_materials_cost := ROUND(v_roll_cost + v_bom_cost + v_accessories_cost, 4);

  v_panel_count := COALESCE(
    NULLIF((v_totals->>'panel_count')::integer, 0),
    CASE
      WHEN jsonb_typeof(v_cp.config_snapshot->'measurements'->'panels') = 'array'
        THEN GREATEST(jsonb_array_length(v_cp.config_snapshot->'measurements'->'panels'), 1)
      WHEN jsonb_typeof(v_cp.config_snapshot->'panels') = 'array'
        THEN GREATEST(jsonb_array_length(v_cp.config_snapshot->'panels'), 1)
      ELSE 1
    END
  );

  v_drops := COALESCE(NULLIF((v_totals->'fabric_calc'->>'drops')::integer, 0), 1);
  v_area_m2 := GREATEST((COALESCE(v_cp.width_mm, 0) / 1000.0) * (COALESCE(v_cp.height_mm, 0) / 1000.0), 0);
  v_operating_type := COALESCE(
    v_cp.config_snapshot->>'operating_type',
    v_cp.config_snapshot->>'operation_type',
    v_cp.config_snapshot->>'drive_type'
  );
  v_has_motor := public.try_parse_uuid(v_cp.config_snapshot->>'motor_item_id') IS NOT NULL;

  -- New v3 inputs derived from existing snapshot data.
  v_hs_seams := COALESCE(NULLIF((v_totals->'fabric_calc'->>'heatseal_seams')::integer, 0), 0);
  v_fab_width_used := COALESCE((v_totals->'fabric_calc'->>'fabric_width_used_m')::numeric, 0);
  v_hs_length := GREATEST(0, v_hs_seams * v_fab_width_used);
  v_bb_wrapped := COALESCE((v_cp.config_snapshot->>'bottom_bar_wrapped')::boolean, false);

  SELECT
    r.labor_cost,
    r.labor_pct_effective,
    r.labor_rule_id,
    r.labor_meta
  INTO
    v_labor_cost_resolved,
    v_labor_pct_effective,
    v_labor_rule_id,
    v_labor_meta
  FROM public.resolve_labor_cost_from_rules(
    v_cp.organization_id,
    v_cp.product_type_id,
    COALESCE(v_cp.width_mm, 0),
    COALESCE(v_cp.height_mm, 0),
    v_area_m2,
    v_panel_count,
    v_drops,
    v_operating_type,
    v_has_motor,
    v_materials_cost,
    v_hs_length,
    v_bb_wrapped
  ) r;

  IF v_labor_cost_resolved IS NULL THEN
    v_unresolved := true;
    v_labor_cost := 0;
    v_labor_pct := 0;
    v_total_cost := 0;
    v_unit_dealer_price := 0;
    v_unit_msrp_total := 0;
    v_dealer_price_total_unit := 0;
    v_msrp_total := 0;
    v_labor_msrp := 0;
  ELSE
    v_unresolved := false;
    v_labor_cost := ROUND(v_labor_cost_resolved, 4);
    v_labor_pct := COALESCE(v_labor_pct_effective, CASE WHEN v_materials_cost > 0 THEN v_labor_cost / v_materials_cost ELSE 0 END);
    v_total_cost := ROUND(v_materials_cost + v_labor_cost, 4);
    v_unit_dealer_price := ROUND(v_total_cost / v_dealer_factor, 4);
    v_unit_msrp_total := ROUND(v_unit_dealer_price / v_msrp_factor, 4);
    v_dealer_price_total_unit := v_unit_dealer_price;
    v_msrp_total := ROUND(v_unit_msrp_total * v_qty, 4);
    v_labor_msrp := ROUND(GREATEST(0, v_unit_msrp_total - v_msrp_product_subtotal), 4);
  END IF;

  v_totals := jsonb_set(v_totals, '{unit_dealer_price}', to_jsonb(v_unit_dealer_price), true);
  v_totals := jsonb_set(v_totals, '{dealer_price_total}', to_jsonb(v_dealer_price_total_unit), true);
  v_totals := jsonb_set(v_totals, '{labor_pct}', to_jsonb(v_labor_pct), true);
  v_totals := jsonb_set(v_totals, '{labor_cost}', to_jsonb(v_labor_cost), true);
  v_totals := jsonb_set(
    v_totals,
    '{labor_rule_id}',
    COALESCE(to_jsonb(v_labor_rule_id), 'null'::jsonb),
    true
  );
  v_totals := jsonb_set(v_totals, '{labor_engine_source}', to_jsonb(COALESCE(v_labor_meta->>'source', 'unknown')), true);
  v_totals := jsonb_set(v_totals, '{labor_unresolved}', to_jsonb(v_unresolved), true);
  v_totals := jsonb_set(v_totals, '{labor_calc_meta}', COALESCE(v_labor_meta, 'null'::jsonb), true);
  v_snapshot := jsonb_set(COALESCE(v_snapshot, '{}'::jsonb), '{totals}', v_totals, true);

  UPDATE public."ConfiguredProducts"
  SET
    roll_msrp_total = v_roll_msrp_total,
    bom_total = v_bom_total,
    accessories_total = v_accessories_total,
    msrp_product_subtotal = v_msrp_product_subtotal,
    labor_amount = v_labor_msrp,
    labor_msrp = v_labor_msrp,
    total_msrp = v_unit_msrp_total,
    unit_msrp_total = v_unit_msrp_total,
    roll_total_cost = v_roll_cost,
    bom_total_cost = v_bom_cost,
    accessories_total_cost = v_accessories_cost,
    unit_product_cost = v_materials_cost,
    unit_labor_cost = v_labor_cost,
    total_cost = v_total_cost,
    labor_pct = v_labor_pct,
    labor_rule_id = v_labor_rule_id,
    labor_calc_meta = v_labor_meta,
    labor_unresolved = v_unresolved,
    bom_preview_snapshot = v_snapshot,
    updated_at = now()
  WHERE id = p_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id', p_configured_product_id,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_total,
    'accessories_total', v_accessories_total,
    'msrp_product_subtotal', v_msrp_product_subtotal,
    'labor_msrp', v_labor_msrp,
    'unit_msrp_total', v_unit_msrp_total,
    'total_msrp', v_unit_msrp_total,
    'msrp_total', v_msrp_total,
    'unit_dealer_price', v_unit_dealer_price,
    'dealer_price_total', v_dealer_price_total_unit,
    'roll_cost', v_roll_cost,
    'bom_cost', v_bom_cost,
    'materials_cost', v_materials_cost,
    'labor_cost', v_labor_cost,
    'total_cost', v_total_cost,
    'labor_pct', v_labor_pct,
    'labor_rule_id', v_labor_rule_id,
    'labor_meta', v_labor_meta,
    'labor_unresolved', v_unresolved,
    'minimum_margin_pct', v_minimum_margin_pct,
    'msrp_margin_pct', v_msrp_margin_pct
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5) Seeds: configure heatseal/wrap rates on Roller and Awning rules,
--    confection rates on Drapery rules. Other product types untouched.
--    User-approved values: heatseal=$10/m, bottom_bar_wrap=$5/m.
-- ---------------------------------------------------------------------------
DO $seed$
DECLARE
  v_org_id uuid;
  v_pt_roller uuid;
  v_pt_awning uuid;
  v_pt_drapery uuid;
BEGIN
  SELECT id INTO v_pt_roller FROM public."ProductTypes" WHERE code = 'roller' LIMIT 1;
  SELECT id INTO v_pt_awning FROM public."ProductTypes" WHERE code = 'awning' LIMIT 1;
  SELECT id INTO v_pt_drapery FROM public."ProductTypes" WHERE code = 'drapery' LIMIT 1;

  FOR v_org_id IN
    SELECT DISTINCT organization_id
    FROM public."CostSettings"
    WHERE COALESCE(is_active, true) = true
  LOOP
    -- Roller v2: enable heatseal $10/m and wrap $5/m. Confection stays 0.
    UPDATE public."LaborRules"
    SET
      heatseal_rate_per_m = 10.00,
      bottom_bar_wrap_rate_per_m = 5.00,
      updated_at = now()
    WHERE organization_id = v_org_id
      AND product_type_id = v_pt_roller
      AND is_active = true
      AND display_name = 'Labor Roller v2 (area + panels + drops)';

    -- Awning: create a rule if one does not exist, with heatseal/wrap enabled.
    IF v_pt_awning IS NOT NULL THEN
      INSERT INTO public."LaborRules" (
        organization_id, product_type_id, display_name, priority, is_active,
        calc_mode, fixed_amount, rate_per_m2, rate_per_drop, rate_per_panel,
        heatseal_rate_per_m, bottom_bar_wrap_rate_per_m,
        min_charge, round_to_increment
      )
      SELECT
        v_org_id, v_pt_awning, 'Labor Awning v2 (area + panels + drops)', 100, true,
        'composite', 6.00, 2.00, 1.50, 2.00,
        10.00, 5.00,
        8.00, 0.01
      WHERE NOT EXISTS (
        SELECT 1 FROM public."LaborRules" lr
        WHERE lr.organization_id = v_org_id
          AND lr.product_type_id = v_pt_awning
          AND lr.display_name = 'Labor Awning v2 (area + panels + drops)'
      );
    END IF;

    -- Drapery v2: confection seeds left at 0 so admin sets the actual third-party
    -- rate in the UI. Heatseal/wrap also stay at 0 (drapery uses confection instead).
    -- Document the intent so it's discoverable in Settings.
    UPDATE public."LaborRules"
    SET updated_at = now()
    WHERE organization_id = v_org_id
      AND product_type_id = v_pt_drapery
      AND is_active = true
      AND display_name = 'Labor Drapery v2 (area + panels)';
  END LOOP;
END
$seed$;

-- ---------------------------------------------------------------------------
-- 6) Recompute existing live ConfiguredProducts so heatseal labor (where
--    applicable) and the new fabric-calc effective rotation are picked up.
-- ---------------------------------------------------------------------------
DO $recompute$
DECLARE
  r RECORD;
  v_total integer := 0;
  v_failed integer := 0;
BEGIN
  FOR r IN
    SELECT id
    FROM public."ConfiguredProducts"
    WHERE deleted = false
      AND bom_template_id IS NOT NULL
      AND created_at >= now() - interval '180 days'
  LOOP
    BEGIN
      PERFORM public.calculate_configured_product_totals(r.id);
      v_total := v_total + 1;
    EXCEPTION
      WHEN OTHERS THEN
        v_failed := v_failed + 1;
        RAISE NOTICE 'Recompute failed for %: %', r.id, SQLERRM;
    END;
  END LOOP;
  RAISE NOTICE 'Recomputed % ConfiguredProducts (% failed) with new labor v3 engine.', v_total, v_failed;
END
$recompute$;

NOTIFY pgrst, 'reload schema';
