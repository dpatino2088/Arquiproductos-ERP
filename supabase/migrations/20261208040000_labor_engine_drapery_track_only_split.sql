BEGIN;

-- Split drapery labor rules by track_only=true/false so rail-only products
-- do not inherit fabric confection charges.
ALTER TABLE public."LaborRules"
  ADD COLUMN IF NOT EXISTS track_only_required boolean;

COMMENT ON COLUMN public."LaborRules".track_only_required IS
  'When set, rule only matches configurations where config_snapshot.track_only equals this value. NULL means no track-only filter.';

DROP FUNCTION IF EXISTS public.resolve_labor_cost_from_rules(
  uuid, uuid, numeric, numeric, numeric, integer, integer, text, boolean, numeric, numeric, boolean
);

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
  p_bottom_bar_wrapped  boolean DEFAULT false,
  p_track_only          boolean DEFAULT NULL
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
  v_track_only boolean := p_track_only;

  v_height_m numeric;
  v_width_m numeric;

  v_base_raw numeric := 0;
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
    AND (
      lr.track_only_required IS NULL
      OR (v_track_only IS NOT NULL AND lr.track_only_required = v_track_only)
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
        'bottom_bar_wrapped', v_wrapped,
        'track_only', v_track_only
      )
    );
    RETURN NEXT;
    RETURN;
  END IF;

  v_height_m := v_height_mm / 1000.0;
  v_width_m := v_width_mm / 1000.0;

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

  IF COALESCE(v_rule.size_escalation_pct, 0) > 0 THEN
    v_size_factor := 1 + (v_rule.size_escalation_pct *
                          GREATEST(0, v_width_m - COALESCE(v_rule.size_reference_width_m, 1.0)));
  ELSE
    v_size_factor := 1;
  END IF;
  v_base_escalated := ROUND(v_base_raw * v_size_factor, 4);

  IF v_hs_length > 0 AND COALESCE(v_rule.heatseal_rate_per_m, 0) > 0 THEN
    v_hs_cost := ROUND(v_rule.heatseal_rate_per_m * v_hs_length, 4);
  END IF;

  IF v_wrapped AND COALESCE(v_rule.bottom_bar_wrap_rate_per_m, 0) > 0 THEN
    v_wrap_cost := ROUND(v_rule.bottom_bar_wrap_rate_per_m * v_width_m, 4);
  END IF;

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
      'bottom_bar_wrapped', v_wrapped,
      'track_only', v_track_only
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
  uuid, uuid, numeric, numeric, numeric, integer, integer, text, boolean, numeric, numeric, boolean, boolean
) IS 'STRICT v4: supports track_only-aware LaborRules and keeps heatseal/bottom-bar-wrap/confection contributors.';

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
  v_track_only boolean := false;
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
  v_track_only := COALESCE((v_cp.config_snapshot->>'track_only')::boolean, false);

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
    v_bb_wrapped,
    v_track_only
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

DO $$
DECLARE
  v_org_id uuid;
  v_pt_drapery uuid;
BEGIN
  SELECT id INTO v_pt_drapery
  FROM public."ProductTypes"
  WHERE code = 'drapery'
  LIMIT 1;

  IF v_pt_drapery IS NULL THEN
    RETURN;
  END IF;

  FOR v_org_id IN
    SELECT DISTINCT organization_id
    FROM public."CostSettings"
    WHERE COALESCE(is_active, true) = true
  LOOP
    -- Existing drapery rules become "with fabric" by default.
    UPDATE public."LaborRules"
    SET
      track_only_required = false,
      updated_at = now()
    WHERE organization_id = v_org_id
      AND product_type_id = v_pt_drapery
      AND COALESCE(is_active, true) = true
      AND track_only_required IS NULL;

    -- Track-only motorized: base 12 + 2/m width (+ existing size escalation).
    UPDATE public."LaborRules"
    SET
      product_type_id = v_pt_drapery,
      priority = 160,
      is_active = true,
      calc_mode = 'composite',
      fixed_amount = 12.00,
      rate_per_m2 = 0,
      rate_per_drop = 0,
      rate_per_panel = 0,
      rate_per_height_m = 0,
      rate_per_width_m = 2.00,
      rate_motor_addon = 0,
      pct_materials = 0,
      min_charge = 12.00,
      max_charge = NULL,
      operating_type = 'motor',
      motor_required = true,
      track_only_required = true,
      size_escalation_pct = 0.05,
      size_reference_width_m = 1.0,
      heatseal_rate_per_m = 0,
      bottom_bar_wrap_rate_per_m = 0,
      confection_base = 0,
      confection_rate_per_m2 = 0,
      confection_size_escalation_pct = 0,
      confection_size_reference_width_m = 1.0,
      round_to_increment = 0.01,
      updated_at = now()
    WHERE organization_id = v_org_id
      AND display_name = 'Labor Drapery Track-Only Motor v1';

    IF NOT FOUND THEN
      INSERT INTO public."LaborRules" (
        organization_id, product_type_id, display_name, priority, is_active,
        calc_mode, fixed_amount, rate_per_m2, rate_per_drop, rate_per_panel,
        rate_per_height_m, rate_per_width_m, rate_motor_addon, pct_materials,
        min_charge, max_charge, operating_type, motor_required, track_only_required,
        size_escalation_pct, size_reference_width_m,
        heatseal_rate_per_m, bottom_bar_wrap_rate_per_m,
        confection_base, confection_rate_per_m2,
        confection_size_escalation_pct, confection_size_reference_width_m,
        round_to_increment
      )
      VALUES (
        v_org_id, v_pt_drapery, 'Labor Drapery Track-Only Motor v1', 160, true,
        'composite', 12.00, 0, 0, 0,
        0, 2.00, 0, 0,
        12.00, NULL, 'motor', true, true,
        0.05, 1.0,
        0, 0,
        0, 0,
        0, 1.0,
        0.01
      );
    END IF;

    -- Track-only manual: base 5 + 1/m width (+ existing size escalation).
    UPDATE public."LaborRules"
    SET
      product_type_id = v_pt_drapery,
      priority = 150,
      is_active = true,
      calc_mode = 'composite',
      fixed_amount = 5.00,
      rate_per_m2 = 0,
      rate_per_drop = 0,
      rate_per_panel = 0,
      rate_per_height_m = 0,
      rate_per_width_m = 1.00,
      rate_motor_addon = 0,
      pct_materials = 0,
      min_charge = 5.00,
      max_charge = NULL,
      operating_type = 'manual',
      motor_required = false,
      track_only_required = true,
      size_escalation_pct = 0.05,
      size_reference_width_m = 1.0,
      heatseal_rate_per_m = 0,
      bottom_bar_wrap_rate_per_m = 0,
      confection_base = 0,
      confection_rate_per_m2 = 0,
      confection_size_escalation_pct = 0,
      confection_size_reference_width_m = 1.0,
      round_to_increment = 0.01,
      updated_at = now()
    WHERE organization_id = v_org_id
      AND display_name = 'Labor Drapery Track-Only Manual v1';

    IF NOT FOUND THEN
      INSERT INTO public."LaborRules" (
        organization_id, product_type_id, display_name, priority, is_active,
        calc_mode, fixed_amount, rate_per_m2, rate_per_drop, rate_per_panel,
        rate_per_height_m, rate_per_width_m, rate_motor_addon, pct_materials,
        min_charge, max_charge, operating_type, motor_required, track_only_required,
        size_escalation_pct, size_reference_width_m,
        heatseal_rate_per_m, bottom_bar_wrap_rate_per_m,
        confection_base, confection_rate_per_m2,
        confection_size_escalation_pct, confection_size_reference_width_m,
        round_to_increment
      )
      VALUES (
        v_org_id, v_pt_drapery, 'Labor Drapery Track-Only Manual v1', 150, true,
        'composite', 5.00, 0, 0, 0,
        0, 1.00, 0, 0,
        5.00, NULL, 'manual', false, true,
        0.05, 1.0,
        0, 0,
        0, 0,
        0, 1.0,
        0.01
      );
    END IF;
  END LOOP;
END
$$;

COMMIT;
