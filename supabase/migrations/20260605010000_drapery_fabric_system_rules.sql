-- =============================================================================
-- Drapery Configuration Engine — Phase 1 & 2
-- Extend FabricRules, create SystemRules, add DRAPERY_PANELS formula,
-- seed initial rules, and create compute_drapery_consumption() function.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1A. Extend FabricRules with confection-specific columns
-- ---------------------------------------------------------------------------
ALTER TABLE "public"."FabricRules"
  ADD COLUMN IF NOT EXISTS "top_hem_cm"         numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "bottom_hem_cm"      numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "side_hem_cm"        numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "fabric_orientation" text    NOT NULL DEFAULT 'vertical';

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'fabric_rules_orientation_check'
  ) THEN
    ALTER TABLE "public"."FabricRules"
      ADD CONSTRAINT fabric_rules_orientation_check
      CHECK (fabric_orientation IN ('vertical', 'railroaded'));
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 1B. Create SystemRules table (key-value, generic)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "public"."SystemRules" (
  "id"              uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  "organization_id" uuid NOT NULL,
  "product_type_id" uuid NOT NULL REFERENCES "public"."ProductTypes"("id"),
  "style_code"      text,
  "rule_key"        text NOT NULL,
  "rule_value"      numeric NOT NULL,
  "catalog_item_id" uuid,
  "is_active"       boolean DEFAULT true NOT NULL,
  "created_at"      timestamptz DEFAULT now(),
  "updated_at"      timestamptz DEFAULT now()
);

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE indexname = 'system_rules_org_product_style_key_uniq'
  ) THEN
    CREATE UNIQUE INDEX system_rules_org_product_style_key_uniq
      ON "public"."SystemRules" (organization_id, product_type_id, COALESCE(style_code, ''), rule_key);
  END IF;
END $$;

ALTER TABLE "public"."SystemRules" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "SystemRules: org members can read" ON "public"."SystemRules";
CREATE POLICY "SystemRules: org members can read"
  ON "public"."SystemRules" FOR SELECT
  USING (is_org_user_member_strict(organization_id) OR is_portal_user_in_org(organization_id));

DROP POLICY IF EXISTS "SystemRules: org members can manage" ON "public"."SystemRules";
CREATE POLICY "SystemRules: org members can manage"
  ON "public"."SystemRules" FOR ALL
  USING (is_org_user_member_strict(organization_id))
  WITH CHECK (is_org_user_member_strict(organization_id));

-- ---------------------------------------------------------------------------
-- 1B2. Extend formula_code check constraint to include DRAPERY_PANELS
-- ---------------------------------------------------------------------------
ALTER TABLE "public"."FabricRules" DROP CONSTRAINT IF EXISTS "FabricRules_formula_code_check";
ALTER TABLE "public"."FabricRules"
  ADD CONSTRAINT "FabricRules_formula_code_check"
  CHECK (formula_code = ANY (ARRAY['ROLLER_DROPS'::text, 'AREA_BASED'::text, 'DRAPERY_PANELS'::text]));

-- ---------------------------------------------------------------------------
-- 1C. Update compute_fabric_pricing_from_rule() — add DRAPERY_PANELS branch
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_fabric_pricing_from_rule(
  p_org_id uuid,
  p_product_type_id uuid,
  p_style_code text,
  p_height_m numeric,
  p_width_m numeric,
  p_roll_width_m numeric,
  p_msrp_per_m numeric
)
RETURNS TABLE(
  qty numeric,
  pricing_uom text,
  unit_price numeric,
  area_base_m2 numeric,
  drops numeric,
  waste_pct numeric
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
    v_fabric_width_needed numeric;
    v_panels numeric;
BEGIN
    qty := NULL;
    pricing_uom := NULL;
    unit_price := NULL;
    area_base_m2 := NULL;
    drops := NULL;
    waste_pct := NULL;

    SELECT * INTO v_r FROM public.select_fabric_rule(p_org_id, p_product_type_id, p_style_code) LIMIT 1;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    waste_pct := COALESCE(v_r.waste_pct, 0);

    v_heff := COALESCE(p_height_m, 0) * COALESCE(v_r.height_multiplier, 1) + COALESCE(v_r.extra_height_m, 0);
    v_weff := COALESCE(p_width_m, 0) * COALESCE(v_r.width_multiplier, 1) + COALESCE(v_r.extra_width_m, 0);

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
        v_fabric_width_needed := COALESCE(p_width_m, 0) * COALESCE(v_r.fullness_factor, 1);

        IF p_roll_width_m IS NULL OR p_roll_width_m <= 0 THEN
            v_panels := 1;
        ELSE
            v_panels := CEIL(v_fabric_width_needed / p_roll_width_m);
        END IF;

        v_drops := v_panels;
        v_area := v_panels * v_cut_height * COALESCE(p_roll_width_m, v_fabric_width_needed);

    ELSE
        v_area := v_heff * v_weff;
        v_drops := NULL;
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
$function$;

-- ---------------------------------------------------------------------------
-- 1D. Seed initial FabricRules for the 3 drapery models
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_org_id  uuid;
  v_pt_id   uuid;
BEGIN
  SELECT DISTINCT organization_id INTO v_org_id FROM "public"."FabricRules" LIMIT 1;
  IF v_org_id IS NULL THEN
    SELECT id INTO v_org_id FROM "public"."Organizations" LIMIT 1;
  END IF;

  SELECT id INTO v_pt_id FROM "public"."ProductTypes"
    WHERE code ILIKE 'drapery' OR name ILIKE 'Drapery'
    LIMIT 1;

  IF v_pt_id IS NULL OR v_org_id IS NULL THEN
    RAISE NOTICE 'Skipping seed: product type or org not found';
    RETURN;
  END IF;

  -- Wave 2.3
  INSERT INTO "public"."FabricRules" (
    organization_id, product_type_id, style_code, formula_code,
    fullness_factor, top_hem_cm, bottom_hem_cm, side_hem_cm,
    waste_pct, pricing_output_uom, fabric_orientation
  ) VALUES (
    v_org_id, v_pt_id, 'wave_2.3', 'DRAPERY_PANELS',
    2.3, 5, 15, 3,
    0.10, 'm', 'vertical'
  ) ON CONFLICT DO NOTHING;

  -- Wave 2.8
  INSERT INTO "public"."FabricRules" (
    organization_id, product_type_id, style_code, formula_code,
    fullness_factor, top_hem_cm, bottom_hem_cm, side_hem_cm,
    waste_pct, pricing_output_uom, fabric_orientation
  ) VALUES (
    v_org_id, v_pt_id, 'wave_2.8', 'DRAPERY_PANELS',
    2.8, 5, 15, 3,
    0.10, 'm', 'vertical'
  ) ON CONFLICT DO NOTHING;

  -- Pinch Pleat
  INSERT INTO "public"."FabricRules" (
    organization_id, product_type_id, style_code, formula_code,
    fullness_factor, top_hem_cm, bottom_hem_cm, side_hem_cm,
    waste_pct, pricing_output_uom, fabric_orientation
  ) VALUES (
    v_org_id, v_pt_id, 'pinch_pleat', 'DRAPERY_PANELS',
    3.0, 5, 15, 3,
    0.10, 'm', 'vertical'
  ) ON CONFLICT DO NOTHING;

  -- SystemRules seeds
  -- Wave 2.3 — carrier spacing
  INSERT INTO "public"."SystemRules" (
    organization_id, product_type_id, style_code, rule_key, rule_value
  ) VALUES (v_org_id, v_pt_id, 'wave_2.3', 'carrier_spacing_cm', 4.8)
  ON CONFLICT DO NOTHING;

  -- Wave 2.3 — bracket spacing
  INSERT INTO "public"."SystemRules" (
    organization_id, product_type_id, style_code, rule_key, rule_value
  ) VALUES (v_org_id, v_pt_id, 'wave_2.3', 'bracket_spacing_cm', 60)
  ON CONFLICT DO NOTHING;

  -- Wave 2.8 — carrier spacing
  INSERT INTO "public"."SystemRules" (
    organization_id, product_type_id, style_code, rule_key, rule_value
  ) VALUES (v_org_id, v_pt_id, 'wave_2.8', 'carrier_spacing_cm', 6.0)
  ON CONFLICT DO NOTHING;

  -- Wave 2.8 — bracket spacing
  INSERT INTO "public"."SystemRules" (
    organization_id, product_type_id, style_code, rule_key, rule_value
  ) VALUES (v_org_id, v_pt_id, 'wave_2.8', 'bracket_spacing_cm', 60)
  ON CONFLICT DO NOTHING;

  -- Pinch Pleat — bracket spacing (no carriers for pinch pleat)
  INSERT INTO "public"."SystemRules" (
    organization_id, product_type_id, style_code, rule_key, rule_value
  ) VALUES (v_org_id, v_pt_id, 'pinch_pleat', 'bracket_spacing_cm', 60)
  ON CONFLICT DO NOTHING;

END $$;

-- ---------------------------------------------------------------------------
-- Phase 2: compute_drapery_consumption() DB function
-- Returns full material breakdown for a configured drapery product
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.compute_drapery_consumption(
  p_org_id         uuid,
  p_product_type_id uuid,
  p_style_code     text,
  p_width_cm       numeric,
  p_height_cm      numeric,
  p_roll_width_cm  numeric
)
RETURNS TABLE(
  item_type     text,
  qty           numeric,
  uom           text,
  panels        integer,
  cut_height_cm numeric,
  details       jsonb
)
LANGUAGE plpgsql STABLE
AS $func$
DECLARE
  v_fr RECORD;
  v_fullness        numeric;
  v_top_hem         numeric;
  v_bottom_hem      numeric;
  v_waste           numeric;
  v_cut_height      numeric;
  v_fabric_width    numeric;
  v_panels          integer;
  v_fabric_total    numeric;
  v_fabric_w_waste  numeric;
  v_carrier_spacing numeric;
  v_bracket_spacing numeric;
  v_carriers        integer;
  v_brackets        integer;
BEGIN
  -- 1. Read FabricRules
  SELECT fr.*
    INTO v_fr
    FROM "public"."FabricRules" fr
   WHERE fr.organization_id  = p_org_id
     AND fr.product_type_id  = p_product_type_id
     AND fr.style_code        = p_style_code
     AND fr.is_active         = true
   LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No FabricRule found for org=%, product_type=%, style=%',
      p_org_id, p_product_type_id, p_style_code;
  END IF;

  v_fullness   := COALESCE(v_fr.fullness_factor, 1);
  v_top_hem    := COALESCE(v_fr.top_hem_cm, 0);
  v_bottom_hem := COALESCE(v_fr.bottom_hem_cm, 0);
  v_waste      := COALESCE(v_fr.waste_pct, 0);

  -- 2. Fabric calculations
  v_cut_height    := p_height_cm + v_top_hem + v_bottom_hem;
  v_fabric_width  := p_width_cm * v_fullness;

  IF p_roll_width_cm IS NULL OR p_roll_width_cm <= 0 THEN
    v_panels := 1;
  ELSE
    v_panels := CEIL(v_fabric_width / p_roll_width_cm);
  END IF;

  v_fabric_total   := v_panels * v_cut_height;
  v_fabric_w_waste := v_fabric_total * (1 + v_waste);

  -- Return FABRIC row (qty in meters)
  item_type     := 'fabric';
  qty           := ROUND(v_fabric_w_waste / 100.0, 3);  -- cm → m
  uom           := 'm';
  panels        := v_panels;
  cut_height_cm := v_cut_height;
  details       := jsonb_build_object(
    'fullness_factor', v_fullness,
    'fabric_width_needed_cm', v_fabric_width,
    'fabric_total_cm', v_fabric_total,
    'fabric_total_with_waste_cm', v_fabric_w_waste,
    'top_hem_cm', v_top_hem,
    'bottom_hem_cm', v_bottom_hem,
    'waste_pct', v_waste
  );
  RETURN NEXT;

  -- Return TRACK row (qty in meters = width in m)
  item_type     := 'track';
  qty           := ROUND(p_width_cm / 100.0, 3);  -- cm → m
  uom           := 'm';
  panels        := NULL;
  cut_height_cm := NULL;
  details       := NULL;
  RETURN NEXT;

  -- 3. Read SystemRules for carrier_spacing
  SELECT sr.rule_value INTO v_carrier_spacing
    FROM "public"."SystemRules" sr
   WHERE sr.organization_id  = p_org_id
     AND sr.product_type_id  = p_product_type_id
     AND sr.style_code        = p_style_code
     AND sr.rule_key          = 'carrier_spacing_cm'
     AND sr.is_active         = true
   LIMIT 1;

  IF v_carrier_spacing IS NOT NULL AND v_carrier_spacing > 0 THEN
    v_carriers := CEIL(p_width_cm / v_carrier_spacing);

    item_type     := 'carrier';
    qty           := v_carriers;
    uom           := 'ea';
    panels        := NULL;
    cut_height_cm := NULL;
    details       := jsonb_build_object('spacing_cm', v_carrier_spacing);
    RETURN NEXT;
  END IF;

  -- 4. Read SystemRules for bracket_spacing
  SELECT sr.rule_value INTO v_bracket_spacing
    FROM "public"."SystemRules" sr
   WHERE sr.organization_id  = p_org_id
     AND sr.product_type_id  = p_product_type_id
     AND sr.style_code        = p_style_code
     AND sr.rule_key          = 'bracket_spacing_cm'
     AND sr.is_active         = true
   LIMIT 1;

  IF v_bracket_spacing IS NOT NULL AND v_bracket_spacing > 0 THEN
    v_brackets := CEIL(p_width_cm / v_bracket_spacing);
    IF v_brackets < 2 THEN v_brackets := 2; END IF;

    item_type     := 'bracket';
    qty           := v_brackets;
    uom           := 'ea';
    panels        := NULL;
    cut_height_cm := NULL;
    details       := jsonb_build_object('spacing_cm', v_bracket_spacing);
    RETURN NEXT;
  END IF;

  RETURN;
END;
$func$;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
