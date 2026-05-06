-- ============================================================================
-- Labor Engine v2: STRICT mode, no fallback, expanded seed values
--
-- Goals:
--   1) Remove the silent fallback to CostSettings.labor_pct. If no LaborRule
--      matches a configured product, mark it as labor_unresolved = true and
--      block commit / sync to QuoteLines until a matching rule is created.
--   2) Re-seed v2 rules with rate_per_drop and rate_per_panel populated so
--      multi-panel / multi-drop products are priced correctly out of the box.
--   3) Expose a coverage helper so the UI can list combinations missing rules.
--
-- Pricing-protect: this migration does NOT change cost/dealer/msrp formulas.
-- It only changes the SOURCE of labor_cost (must come from a LaborRule) and
-- adds an unresolved-state gate.
-- ============================================================================

SET search_path = public;

-- ---------------------------------------------------------------------------
-- 1) Schema: labor_unresolved flag on ConfiguredProducts
-- ---------------------------------------------------------------------------
ALTER TABLE public."ConfiguredProducts"
  ADD COLUMN IF NOT EXISTS labor_unresolved boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS configured_products_labor_unresolved_idx
  ON public."ConfiguredProducts"(organization_id, labor_unresolved)
  WHERE labor_unresolved = true;

COMMENT ON COLUMN public."ConfiguredProducts".labor_unresolved IS
  'TRUE when no active LaborRule matched this product. Pricing is incomplete and the line cannot be committed to a Quote until a matching rule exists.';

-- ---------------------------------------------------------------------------
-- 2) Resolver: drop the silent fallback. Return NULL labor_cost when no
--    rule matches and surface the reason in labor_meta.
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
    -- Strict mode: NO fallback. Return NULL labor_cost and surface context.
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
        'operating_type', v_operating
      )
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
      -- Unknown calc_mode: still treat as unresolved instead of guessing.
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
      'pct_materials', COALESCE(v_rule.pct_materials, 0),
      'min_charge', COALESCE(v_rule.min_charge, 0),
      'max_charge', v_rule.max_charge
    )
  );
  RETURN NEXT;
END;
$function$;

COMMENT ON FUNCTION public.resolve_labor_cost_from_rules(
  uuid, uuid, numeric, numeric, numeric, integer, integer, text, boolean, numeric, numeric
) IS 'STRICT: returns NULL labor_cost when no LaborRule matches. No fallback. Caller must mark the product as labor_unresolved.';

-- ---------------------------------------------------------------------------
-- 3) calculate_configured_product_totals: stop using labor_pct as fallback.
--    If labor_cost is NULL → set labor_unresolved=true and zero pricing.
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
    0
  ) r;

  IF v_labor_cost_resolved IS NULL THEN
    -- STRICT: no fallback. Mark unresolved, zero pricing, block downstream commit.
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
-- 4) Block commit & sync RPCs when labor is unresolved.
--    We add a guard at the very top of each RPC. The bodies are otherwise
--    untouched, so we use a thin wrapper trigger via PERFORM check.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assert_labor_resolved(p_configured_product_id uuid)
RETURNS void
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
  v_unresolved boolean;
  v_meta jsonb;
  v_pt text;
  v_w numeric;
  v_h numeric;
  v_motor boolean;
BEGIN
  SELECT
    cp.labor_unresolved,
    cp.labor_calc_meta,
    pt.code,
    cp.width_mm,
    cp.height_mm,
    public.try_parse_uuid(cp.config_snapshot->>'motor_item_id') IS NOT NULL
  INTO v_unresolved, v_meta, v_pt, v_w, v_h, v_motor
  FROM public."ConfiguredProducts" cp
  LEFT JOIN public."ProductTypes" pt ON pt.id = cp.product_type_id
  WHERE cp.id = p_configured_product_id;

  IF v_unresolved IS TRUE THEN
    RAISE EXCEPTION 'Labor cost is unresolved for this configuration. Create a matching LaborRule in Settings → Cost Engine → Labor Rules. Context: product_type=%, width_mm=%, height_mm=%, motor=%',
      COALESCE(v_pt, 'unknown'),
      COALESCE(v_w::text, 'NULL'),
      COALESCE(v_h::text, 'NULL'),
      COALESCE(v_motor::text, 'unknown')
      USING ERRCODE = 'P0001',
            HINT = 'Open Cost Engine and add a rule that matches this product. The fallback to Defaults Labor % has been disabled.';
  END IF;
END;
$function$;

-- We patch the two RPCs that write pricing to call assert_labor_resolved
-- right after PERFORM calculate_configured_product_totals(...).
--
-- We rebuild the function bodies by using CREATE OR REPLACE with the same
-- signatures as today, inserting the assertion. Since the bodies are large
-- and we only need to add one line, we use a generic patch approach: a
-- BEFORE INSERT trigger on QuoteLines and a BEFORE UPDATE on QuoteLines for
-- pricing snapshot columns will enforce the gate even if RPCs evolve.
CREATE OR REPLACE FUNCTION public.tg_quote_lines_block_unresolved_labor()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_unresolved boolean;
BEGIN
  IF NEW.configured_product_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT cp.labor_unresolved
  INTO v_unresolved
  FROM public."ConfiguredProducts" cp
  WHERE cp.id = NEW.configured_product_id;

  IF v_unresolved IS TRUE THEN
    PERFORM public.assert_labor_resolved(NEW.configured_product_id);
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_quote_lines_block_unresolved_labor ON public."QuoteLines";
CREATE TRIGGER trg_quote_lines_block_unresolved_labor
  BEFORE INSERT OR UPDATE ON public."QuoteLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_quote_lines_block_unresolved_labor();

COMMENT ON TRIGGER trg_quote_lines_block_unresolved_labor ON public."QuoteLines" IS
  'Hard guard: refuse to insert/update a QuoteLine whose ConfiguredProduct has labor_unresolved=true.';

-- ---------------------------------------------------------------------------
-- 5) Coverage helper: list ConfiguredProducts with no matching LaborRule.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.labor_rules_coverage_gaps(
  p_org_id uuid,
  p_days integer DEFAULT 90
)
RETURNS TABLE(
  product_type_id uuid,
  product_type_code text,
  product_type_name text,
  has_motor boolean,
  width_min_mm numeric,
  width_max_mm numeric,
  height_min_mm numeric,
  height_max_mm numeric,
  sample_count integer,
  example_configured_product_id uuid
)
LANGUAGE sql
STABLE
AS $function$
  SELECT
    cp.product_type_id,
    pt.code,
    pt.name,
    public.try_parse_uuid(cp.config_snapshot->>'motor_item_id') IS NOT NULL AS has_motor,
    MIN(cp.width_mm) AS width_min_mm,
    MAX(cp.width_mm) AS width_max_mm,
    MIN(cp.height_mm) AS height_min_mm,
    MAX(cp.height_mm) AS height_max_mm,
    COUNT(*)::integer AS sample_count,
    (ARRAY_AGG(cp.id ORDER BY cp.created_at DESC))[1] AS example_configured_product_id
  FROM public."ConfiguredProducts" cp
  LEFT JOIN public."ProductTypes" pt ON pt.id = cp.product_type_id
  WHERE cp.organization_id = p_org_id
    AND cp.deleted = false
    AND cp.created_at >= now() - (p_days || ' days')::interval
    AND cp.labor_unresolved = true
  GROUP BY
    cp.product_type_id,
    pt.code,
    pt.name,
    (public.try_parse_uuid(cp.config_snapshot->>'motor_item_id') IS NOT NULL)
  ORDER BY sample_count DESC;
$function$;

COMMENT ON FUNCTION public.labor_rules_coverage_gaps(uuid, integer) IS
  'Returns combinations of recently-created ConfiguredProducts that have no matching LaborRule, so admins know which rules to create.';

-- ---------------------------------------------------------------------------
-- 6) Re-seed v2 rules with rate_per_drop and rate_per_panel populated.
--    Deactivate v1 baseline rules so v2 takes over without conflicts.
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
    -- Deactivate v1 baseline rules (only if untouched display_name match).
    UPDATE public."LaborRules"
    SET is_active = false, updated_at = now()
    WHERE organization_id = v_org_id
      AND display_name IN (
        'Labor Roller v1 (base + area)',
        'Labor Drapery v1 (base + area)',
        'Labor Dual Shade v1 Manual (base + area)',
        'Labor Dual Shade v1 Motor (base + area + motor addon)'
      )
      AND is_active = true;

    -- Roller v2: base + area + per-panel + per-drop.
    INSERT INTO public."LaborRules" (
      organization_id, product_type_id, display_name, priority, is_active,
      calc_mode, fixed_amount, rate_per_m2, rate_per_drop, rate_per_panel,
      min_charge, round_to_increment
    )
    SELECT
      v_org_id, v_pt_roller, 'Labor Roller v2 (area + panels + drops)', 100, true,
      'composite', 5.00, 2.00, 1.50, 2.00,
      8.00, 0.01
    WHERE v_pt_roller IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public."LaborRules" lr
        WHERE lr.organization_id = v_org_id
          AND lr.product_type_id = v_pt_roller
          AND lr.display_name = 'Labor Roller v2 (area + panels + drops)'
      );

    -- Drapery v2.
    INSERT INTO public."LaborRules" (
      organization_id, product_type_id, display_name, priority, is_active,
      calc_mode, fixed_amount, rate_per_m2, rate_per_panel,
      min_charge, round_to_increment
    )
    SELECT
      v_org_id, v_pt_drapery, 'Labor Drapery v2 (area + panels)', 100, true,
      'composite', 3.00, 0.80, 1.50,
      6.00, 0.01
    WHERE v_pt_drapery IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public."LaborRules" lr
        WHERE lr.organization_id = v_org_id
          AND lr.product_type_id = v_pt_drapery
          AND lr.display_name = 'Labor Drapery v2 (area + panels)'
      );

    -- Dual Shade Manual v2.
    INSERT INTO public."LaborRules" (
      organization_id, product_type_id, display_name, priority, is_active,
      motor_required, calc_mode,
      fixed_amount, rate_per_m2, rate_per_drop, rate_per_panel,
      min_charge, round_to_increment
    )
    SELECT
      v_org_id, v_pt_dual, 'Labor Dual Shade v2 Manual (area + panels + drops)', 110, true,
      false, 'composite',
      8.00, 1.20, 1.50, 2.00,
      12.00, 0.01
    WHERE v_pt_dual IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public."LaborRules" lr
        WHERE lr.organization_id = v_org_id
          AND lr.product_type_id = v_pt_dual
          AND lr.display_name = 'Labor Dual Shade v2 Manual (area + panels + drops)'
      );

    -- Dual Shade Motor v2.
    INSERT INTO public."LaborRules" (
      organization_id, product_type_id, display_name, priority, is_active,
      motor_required, calc_mode,
      fixed_amount, rate_per_m2, rate_per_drop, rate_per_panel, rate_motor_addon,
      min_charge, round_to_increment
    )
    SELECT
      v_org_id, v_pt_dual, 'Labor Dual Shade v2 Motor (area + panels + drops + motor)', 120, true,
      true, 'composite',
      8.00, 1.20, 1.50, 2.00, 4.50,
      14.00, 0.01
    WHERE v_pt_dual IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM public."LaborRules" lr
        WHERE lr.organization_id = v_org_id
          AND lr.product_type_id = v_pt_dual
          AND lr.display_name = 'Labor Dual Shade v2 Motor (area + panels + drops + motor)'
      );
  END LOOP;
END
$seed$;

-- ---------------------------------------------------------------------------
-- 7) Recompute existing live ConfiguredProducts so the new strict mode is
--    applied immediately (active, non-deleted, with bom_template_id).
-- ---------------------------------------------------------------------------
DO $recompute$
DECLARE
  r RECORD;
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
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Recompute failed for ConfiguredProduct %: %', r.id, SQLERRM;
    END;
  END LOOP;
END
$recompute$;

NOTIFY pgrst, 'reload schema';
