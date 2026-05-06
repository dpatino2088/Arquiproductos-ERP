-- ============================================================================
-- Labor Engine v1: product-type rules by size/complexity
--
-- Goal:
--   Move labor cost from a single global percentage to a configurable rules
--   engine per product type, while preserving the existing pricing pipeline:
--   cost -> dealer -> msrp.
--
-- Scope:
--   1) Create public."LaborRules"
--   2) Add rule traceability fields to public."ConfiguredProducts"
--   3) Add labor calc traceability snapshot to public."QuoteLines"
--   4) Add resolver function: public.resolve_labor_cost_from_rules(...)
--   5) Integrate resolver into public.calculate_configured_product_totals(uuid)
--   6) Seed initial estimated rules for roller, drapery, dual_shade
--
-- Notes:
--   - If no active rule matches, fallback remains CostSettings.labor_pct.
--   - Pricing-protect formulas are not changed. Only labor source changes.
-- ============================================================================

SET search_path = public;

-- ---------------------------------------------------------------------------
-- 1) Data model
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public."LaborRules" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
  product_type_id uuid REFERENCES public."ProductTypes"(id) ON DELETE CASCADE,
  display_name text NOT NULL,
  priority integer NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,

  -- optional filters (all are AND)
  width_min_mm numeric,
  width_max_mm numeric,
  height_min_mm numeric,
  height_max_mm numeric,
  area_min_m2 numeric,
  area_max_m2 numeric,
  panel_count_min integer,
  panel_count_max integer,
  drops_min integer,
  drops_max integer,
  operating_type text,
  motor_required boolean,

  -- calculation
  calc_mode text NOT NULL DEFAULT 'pct_materials',
  pct_materials numeric,
  fixed_amount numeric,
  rate_per_m2 numeric,
  rate_per_drop numeric,
  rate_per_panel numeric,
  rate_per_height_m numeric,
  rate_per_width_m numeric,
  rate_motor_addon numeric,
  min_charge numeric,
  max_charge numeric,
  round_to_increment numeric NOT NULL DEFAULT 0.01,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT labor_rules_calc_mode_chk
    CHECK (calc_mode IN (
      'pct_materials',
      'fixed',
      'per_m2',
      'per_drop',
      'per_panel',
      'per_height_m',
      'per_width_m',
      'composite'
    )),
  CONSTRAINT labor_rules_priority_chk CHECK (priority >= 0),
  CONSTRAINT labor_rules_round_chk CHECK (round_to_increment >= 0),
  CONSTRAINT labor_rules_minmax_chk CHECK (max_charge IS NULL OR min_charge IS NULL OR max_charge >= min_charge)
);

CREATE INDEX IF NOT EXISTS labor_rules_org_active_idx
  ON public."LaborRules"(organization_id, is_active);

CREATE INDEX IF NOT EXISTS labor_rules_match_idx
  ON public."LaborRules"(organization_id, product_type_id, is_active, priority DESC, created_at ASC);

ALTER TABLE public."ConfiguredProducts"
  ADD COLUMN IF NOT EXISTS labor_rule_id uuid REFERENCES public."LaborRules"(id) ON DELETE SET NULL;

ALTER TABLE public."ConfiguredProducts"
  ADD COLUMN IF NOT EXISTS labor_calc_meta jsonb;

ALTER TABLE public."QuoteLines"
  ADD COLUMN IF NOT EXISTS labor_calc_meta_snapshot jsonb;

-- ---------------------------------------------------------------------------
-- 2) Resolver function
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_labor_cost_from_rules(
  p_org_id uuid,
  p_product_type_id uuid,
  p_width_mm numeric,
  p_height_mm numeric,
  p_area_m2 numeric,
  p_panel_count integer,
  p_drops integer,
  p_operating_type text,
  p_has_motor boolean,
  p_materials_cost numeric,
  p_default_labor_pct numeric
)
RETURNS TABLE(
  labor_cost numeric,
  labor_pct_effective numeric,
  labor_rule_id uuid,
  labor_meta jsonb
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
  v_default_pct numeric := GREATEST(COALESCE(p_default_labor_pct, 0), 0);
  v_materials numeric := GREATEST(COALESCE(p_materials_cost, 0), 0);

  v_height_m numeric;
  v_width_m numeric;
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
    v_rounded := ROUND(v_materials * v_default_pct, 4);
    labor_cost := v_rounded;
    labor_pct_effective := CASE WHEN v_materials > 0 THEN v_rounded / v_materials ELSE 0 END;
    labor_rule_id := NULL;
    labor_meta := jsonb_build_object(
      'source', 'fallback_cost_settings',
      'calc_mode', 'pct_materials',
      'pct_materials', v_default_pct,
      'materials_cost', v_materials
    );
    RETURN NEXT;
    RETURN;
  END IF;

  v_height_m := v_height_mm / 1000.0;
  v_width_m := v_width_mm / 1000.0;

  CASE v_rule.calc_mode
    WHEN 'pct_materials' THEN
      v_raw := v_materials * COALESCE(v_rule.pct_materials, 0);

    WHEN 'fixed' THEN
      v_raw := COALESCE(v_rule.fixed_amount, 0);

    WHEN 'per_m2' THEN
      v_raw := COALESCE(v_rule.rate_per_m2, 0) * v_area_m2;

    WHEN 'per_drop' THEN
      v_raw := COALESCE(v_rule.rate_per_drop, 0) * v_drops;

    WHEN 'per_panel' THEN
      v_raw := COALESCE(v_rule.rate_per_panel, 0) * v_panel_count;

    WHEN 'per_height_m' THEN
      v_raw := COALESCE(v_rule.rate_per_height_m, 0) * v_height_m;

    WHEN 'per_width_m' THEN
      v_raw := COALESCE(v_rule.rate_per_width_m, 0) * v_width_m;

    WHEN 'composite' THEN
      v_raw := COALESCE(v_rule.fixed_amount, 0)
             + (COALESCE(v_rule.rate_per_m2, 0) * v_area_m2)
             + (COALESCE(v_rule.rate_per_drop, 0) * v_drops)
             + (COALESCE(v_rule.rate_per_panel, 0) * v_panel_count)
             + (COALESCE(v_rule.rate_per_height_m, 0) * v_height_m)
             + (COALESCE(v_rule.rate_per_width_m, 0) * v_width_m)
             + (CASE WHEN v_has_motor THEN COALESCE(v_rule.rate_motor_addon, 0) ELSE 0 END);

    ELSE
      -- Defensive fallback for unexpected mode
      v_raw := v_materials * v_default_pct;
  END CASE;

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
      'operating_type', v_operating
    ),
    'breakdown', jsonb_build_object(
      'fixed_amount', COALESCE(v_rule.fixed_amount, 0),
      'rate_per_m2', COALESCE(v_rule.rate_per_m2, 0),
      'rate_per_drop', COALESCE(v_rule.rate_per_drop, 0),
      'rate_per_panel', COALESCE(v_rule.rate_per_panel, 0),
      'rate_per_height_m', COALESCE(v_rule.rate_per_height_m, 0),
      'rate_per_width_m', COALESCE(v_rule.rate_per_width_m, 0),
      'rate_motor_addon', COALESCE(v_rule.rate_motor_addon, 0),
      'pct_materials', COALESCE(v_rule.pct_materials, 0)
    )
  );
  RETURN NEXT;
END;
$function$;

COMMENT ON FUNCTION public.resolve_labor_cost_from_rules(
  uuid, uuid, numeric, numeric, numeric, integer, integer, text, boolean, numeric, numeric
) IS 'Resolves labor cost from active LaborRules; falls back to CostSettings labor_pct when no rule matches.';

-- ---------------------------------------------------------------------------
-- 3) Integrate into calculate_configured_product_totals
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

  -- Always rebuild snapshot when bom_template_id exists to ensure fresh cost data
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

  -- MSRP subtotals
  v_roll_msrp_total := COALESCE((v_totals->>'roll_msrp_total')::numeric, v_cp.roll_msrp_total, 0);
  v_bom_total := COALESCE((v_totals->>'bom_total')::numeric, v_cp.bom_total, 0);
  v_accessories_total := COALESCE((v_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);

  -- Cost subtotals
  v_roll_cost := COALESCE((v_totals->>'roll_total_cost')::numeric, v_cp.roll_total_cost, 0);
  v_bom_cost := COALESCE((v_totals->>'bom_total_cost')::numeric, v_cp.bom_total_cost, 0);
  v_accessories_cost := COALESCE((v_totals->>'accessories_total_cost')::numeric, v_cp.accessories_total_cost, 0);

  -- Defensive: legacy snapshot may have multiplied roll by qty
  IF v_qty > 1 AND (v_roll_cost > 0 OR v_roll_msrp_total > 0) THEN
    IF (v_totals->>'legacy_qty_multiplied') = 'true' THEN
      v_roll_cost := v_roll_cost / v_qty;
      v_roll_msrp_total := v_roll_msrp_total / v_qty;
    END IF;
  END IF;

  v_msrp_product_subtotal := v_roll_msrp_total + v_bom_total + v_accessories_total;

  -- Default/fallback labor %
  v_labor_pct := COALESCE(v_cs.labor_pct, v_cp.labor_pct, (v_totals->>'labor_pct')::numeric, 0);
  IF v_labor_pct > 1 THEN
    v_labor_pct := v_labor_pct / 100.0;
  END IF;
  v_labor_pct := GREATEST(0, v_labor_pct);

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

  -- Cost -> Dealer -> MSRP (all UNIT)
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

  SELECT
    r.labor_cost,
    r.labor_pct_effective,
    r.labor_rule_id,
    r.labor_meta
  INTO
    v_labor_cost,
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
    v_labor_pct
  ) r;

  v_labor_cost := ROUND(COALESCE(v_labor_cost, v_materials_cost * v_labor_pct), 4);

  IF v_labor_pct_effective IS NOT NULL THEN
    v_labor_pct := GREATEST(v_labor_pct_effective, 0);
  ELSIF v_materials_cost > 0 THEN
    v_labor_pct := v_labor_cost / v_materials_cost;
  END IF;

  v_total_cost := ROUND(v_materials_cost + v_labor_cost, 4);
  v_unit_dealer_price := ROUND(v_total_cost / v_dealer_factor, 4);
  v_unit_msrp_total := ROUND(v_unit_dealer_price / v_msrp_factor, 4);
  v_dealer_price_total_unit := v_unit_dealer_price;
  v_msrp_total := ROUND(v_unit_msrp_total * v_qty, 4);

  v_labor_msrp := ROUND(GREATEST(0, v_unit_msrp_total - v_msrp_product_subtotal), 4);

  -- Update snapshot totals
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
    'minimum_margin_pct', v_minimum_margin_pct,
    'msrp_margin_pct', v_msrp_margin_pct
  );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4) Seed initial estimated rules (based on current real data)
-- ---------------------------------------------------------------------------
DO $seed$
DECLARE
  v_org_id uuid;
  v_pt_roller uuid;
  v_pt_dual uuid;
  v_pt_drapery uuid;
BEGIN
  SELECT id INTO v_pt_roller FROM public."ProductTypes" WHERE code = 'roller' LIMIT 1;
  SELECT id INTO v_pt_dual FROM public."ProductTypes" WHERE code = 'dual_shade' LIMIT 1;
  SELECT id INTO v_pt_drapery FROM public."ProductTypes" WHERE code = 'drapery' LIMIT 1;

  FOR v_org_id IN
    SELECT DISTINCT organization_id
    FROM public."CostSettings"
    WHERE COALESCE(is_active, true) = true
  LOOP
    -- Roller Shade baseline:
    -- historical fit ~ 2.07 USD/m2 with near-zero intercept.
    INSERT INTO public."LaborRules" (
      organization_id, product_type_id, display_name, priority, is_active,
      calc_mode, fixed_amount, rate_per_m2, min_charge, round_to_increment
    )
    SELECT
      v_org_id, v_pt_roller, 'Labor Roller v1 (base + area)', 100, true,
      'composite', 2.00, 2.05, 5.00, 0.01
    WHERE v_pt_roller IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public."LaborRules" lr
        WHERE lr.organization_id = v_org_id
          AND lr.product_type_id = v_pt_roller
          AND lr.display_name = 'Labor Roller v1 (base + area)'
      );

    -- Drapery baseline:
    -- historical fit ~ 0.86 USD/m2, with low absolute labor values.
    INSERT INTO public."LaborRules" (
      organization_id, product_type_id, display_name, priority, is_active,
      calc_mode, fixed_amount, rate_per_m2, min_charge, round_to_increment
    )
    SELECT
      v_org_id, v_pt_drapery, 'Labor Drapery v1 (base + area)', 100, true,
      'composite', 1.00, 0.80, 3.00, 0.01
    WHERE v_pt_drapery IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public."LaborRules" lr
        WHERE lr.organization_id = v_org_id
          AND lr.product_type_id = v_pt_drapery
          AND lr.display_name = 'Labor Drapery v1 (base + area)'
      );

    -- Dual Shade (Coulisse manual baseline):
    INSERT INTO public."LaborRules" (
      organization_id, product_type_id, display_name, priority, is_active,
      motor_required, calc_mode, fixed_amount, rate_per_m2, min_charge, round_to_increment
    )
    SELECT
      v_org_id, v_pt_dual, 'Labor Dual Shade v1 Manual (base + area)', 110, true,
      false, 'composite', 4.00, 1.20, 8.00, 0.01
    WHERE v_pt_dual IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public."LaborRules" lr
        WHERE lr.organization_id = v_org_id
          AND lr.product_type_id = v_pt_dual
          AND lr.display_name = 'Labor Dual Shade v1 Manual (base + area)'
      );

    -- Dual Shade (Coulisse motorized baseline): manual + motor add-on.
    INSERT INTO public."LaborRules" (
      organization_id, product_type_id, display_name, priority, is_active,
      motor_required, calc_mode, fixed_amount, rate_per_m2, rate_motor_addon,
      min_charge, round_to_increment
    )
    SELECT
      v_org_id, v_pt_dual, 'Labor Dual Shade v1 Motor (base + area + motor addon)', 120, true,
      true, 'composite', 4.00, 1.20, 4.50, 10.00, 0.01
    WHERE v_pt_dual IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM public."LaborRules" lr
        WHERE lr.organization_id = v_org_id
          AND lr.product_type_id = v_pt_dual
          AND lr.display_name = 'Labor Dual Shade v1 Motor (base + area + motor addon)'
      );
  END LOOP;
END
$seed$;

