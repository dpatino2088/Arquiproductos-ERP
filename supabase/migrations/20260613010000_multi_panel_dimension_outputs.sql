-- ============================================================================
-- Multi-panel per-panel tube/fabric/bottom_bar cuts
-- Enhances compute_system_dimensions() to output per-panel cut widths
-- Enhances compute_fabric_pricing_from_rule() to aggregate fabric per panel
-- Adds panel_index to BOMInstanceLines for manufacturing traceability
-- ============================================================================

BEGIN;

-- 0. Backfill: Ensure Roller/Dual/Triple rules use tube_width (by ProductType name)
UPDATE "public"."FabricRules" fr
SET fabric_width_source = 'tube_width',
    formula_code = 'ROLLER_DROPS',
    pricing_output_uom = 'm',
    tube_wrap_mm = CASE
      WHEN fr.tube_wrap_mm > 0 THEN fr.tube_wrap_mm
      ELSE 35
    END,
    bottom_wrap_mm = CASE
      WHEN fr.bottom_wrap_mm > 0 THEN fr.bottom_wrap_mm
      WHEN lower(pt.name) LIKE '%roller%' OR lower(pt.name) LIKE '%zip%' THEN 50
      ELSE 0
    END,
    safety_margin_mm = CASE
      WHEN fr.safety_margin_mm > 0 THEN fr.safety_margin_mm
      ELSE 20
    END,
    panel_multiplier = CASE
      WHEN lower(pt.name) LIKE '%triple%' THEN 3
      WHEN lower(pt.name) LIKE '%dual%' THEN 2
      ELSE 1
    END
FROM "public"."ProductTypes" pt
WHERE pt.id = fr.product_type_id
  AND fr.fabric_width_source != 'tube_width'
  AND (
    lower(pt.name) LIKE '%roller%'
    OR lower(pt.name) LIKE '%dual%'
    OR lower(pt.name) LIKE '%triple%'
    OR lower(pt.name) LIKE '%zip%'
  );

-- 1. Add panel_index to BOMInstanceLines
ALTER TABLE "public"."BOMInstanceLines"
  ADD COLUMN IF NOT EXISTS panel_index integer DEFAULT NULL;

COMMENT ON COLUMN "public"."BOMInstanceLines".panel_index IS
  'Panel number (1-based) for multi-panel products. NULL for single-panel.';

-- ============================================================================
-- 2. Enhanced compute_system_dimensions()
--    Separates endpoint vs joint deltas for per-panel calculations.
--    Output includes tube_panel_cuts / bottom_bar_panel_cuts when multi-panel.
-- ============================================================================

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

  -- ── TUBE WIDTH ──
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

  -- ── BOTTOM BAR WIDTH ──
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

  -- ── TRACK WIDTH (drapery — no multi-panel split for track) ──
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
  'Computes tube/bottom_bar/track widths from BOM deltas. For multi-panel products, '
  'outputs per-panel cuts (tube_panel_cuts, bottom_bar_panel_cuts) with position-based '
  'deductions: endpoint deltas split equally to outer panels, joint deltas split between '
  'adjacent panels. Verification: SUM(panel cuts) = total width.';


-- ============================================================================
-- 3. Enhanced compute_fabric_pricing_from_rule()
--    When tube_panel_cuts exist, iterates per panel for ROLLER_DROPS formula.
--    Each panel is treated as an independent fabric piece with its own drops.
--    Adds panel_detail output column for auditability.
-- ============================================================================

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

    -- ── Resolve fabric cut height (same for all panels) ──
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

    -- ── Multi-panel ROLLER_DROPS: iterate per panel ──
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
      -- ── Single-panel or non-ROLLER_DROPS: original logic ──
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
$function$;

COMMENT ON FUNCTION public.compute_fabric_pricing_from_rule IS
  'Fabric consumption with FabricRule. For multi-panel ROLLER_DROPS, iterates '
  'per panel from tube_panel_cuts and aggregates. Returns panel_detail jsonb '
  'with per-panel breakdown for auditability.';


-- ============================================================================
-- 4. Update build_bom_preview_snapshot — add panel_detail to fabric_calc
-- ============================================================================

CREATE OR REPLACE FUNCTION public.build_bom_preview_snapshot(
  p_org_id uuid,
  p_configured_product_id uuid,
  p_bom_template_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_cs RECORD;
  v_config jsonb;
  v_items jsonb := '[]'::jsonb;
  v_totals jsonb;
  v_comp RECORD;
  v_child RECORD;
  v_item_info RECORD;
  v_msrp_info RECORD;
  v_roll_msrp_unit numeric := 0;
  v_roll_dealer_unit numeric := 0;
  v_roll_labor_unit numeric := 0;
  v_qty numeric;
  v_unit_price numeric;
  v_line_total numeric;
  v_width_mm numeric;
  v_height_mm numeric;
  v_width_m numeric;
  v_height_m numeric;
  v_area_m2 numeric;
  v_roll_item jsonb;
  v_children jsonb;
  v_selected boolean;
  v_roll_msrp_total numeric;
  v_bom_sum numeric;
  v_labor_amount numeric;
  v_labor_dealer numeric := 0;
  v_labor_cost numeric := 0;
  v_accessories_total numeric;
  v_total_msrp numeric;
  v_child_unit_price numeric;
  v_child_line_total numeric;
  v_roll_total_cost numeric := 0;
  v_roll_factor numeric := 0;
  v_roll_qty numeric := 0;
  v_roll_width_effective numeric;
  v_width_total_m numeric;
  v_roll_pricing_mode text;
  v_roll_measure_basis text;
  v_bom_total_cost_val numeric := 0;
  v_bom_cost_from_items numeric := 0;
  v_labor_pct numeric := 0;
  v_labor_dealer_pct numeric := 0;
  v_labor_msrp_pct numeric := 0;
  v_msrp_product_subtotal numeric := 0;
  v_base_cost numeric := 0;
  v_roll_uom text := 'm²';
  v_fabric_pricing_basis text := 'auto';
  v_cost_per_unit numeric := 0;
  v_panel_count integer := 1;
  v_dim_outputs jsonb := '{}'::jsonb;
  v_consumption RECORD;
  v_fabric_calc jsonb := NULL;
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  SELECT cs.labor_pct, cs.labor_dealer_pct, cs.labor_msrp_pct,
         cs.minimum_margin_pct, cs.default_msrp_pct, cs.fabric_pricing_basis
  INTO v_cs
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_org_id AND COALESCE(cs.is_active, true)
  ORDER BY cs.created_at DESC LIMIT 1;

  v_fabric_pricing_basis := COALESCE(v_cs.fabric_pricing_basis, 'auto');
  v_labor_pct := COALESCE(v_cs.labor_pct, 0);
  v_labor_dealer_pct := COALESCE(v_cs.labor_dealer_pct, v_cs.minimum_margin_pct, 0.35);
  v_labor_msrp_pct   := COALESCE(v_cs.labor_msrp_pct, v_cs.labor_pct, 0.05);

  v_config := COALESCE(v_cp.config_snapshot, '{}'::jsonb);

  v_width_mm := COALESCE(
    (v_config->'measurements'->>'width_total_mm')::numeric,
    v_cp.width_mm, 0
  );
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_width_m := v_width_mm / 1000.0;
  v_height_m := v_height_mm / 1000.0;
  v_area_m2 := v_width_m * v_height_m;
  v_width_total_m := v_width_m;

  v_panel_count := GREATEST(
    COALESCE((v_config->'measurements'->>'panel_count')::integer, 0),
    COALESCE(jsonb_array_length(v_config->'measurements'->'panels'), 0),
    COALESCE(jsonb_array_length(v_config->'panels'), 0),
    1
  );

  v_dim_outputs := public.compute_system_dimensions(p_configured_product_id);

  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT r.msrp, r.dealer_price, r.labor_msrp INTO v_roll_msrp_unit, v_roll_dealer_unit, v_roll_labor_unit
    FROM public.get_roll_pricing(p_org_id, v_cp.roll_catalog_item_id) r;

    SELECT ci.sku, ci.name, ci.unit_of_measure,
           ci.roll_pricing_mode, ci.measure_basis,
           COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_catalog
    INTO v_item_info
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id AND ci.organization_id = p_org_id
    LIMIT 1;

    v_roll_width_effective := COALESCE(v_cp.roll_width, (v_item_info.roll_width_catalog)::numeric, 0);

    BEGIN
      SELECT * INTO v_consumption
      FROM public.compute_fabric_pricing_from_rule(
        p_org_id, v_cp.product_type_id, NULL,
        v_height_m, v_width_m, v_roll_width_effective,
        COALESCE(v_roll_msrp_unit, 0),
        v_dim_outputs
      ) LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v_consumption := NULL;
    END;

    IF v_consumption IS NOT NULL AND v_consumption.qty IS NOT NULL THEN
      v_roll_factor := v_consumption.qty / (1 + COALESCE(v_consumption.waste_pct, 0));
      v_roll_qty := v_consumption.qty;
      v_fabric_calc := jsonb_build_object(
        'source', 'FabricRule',
        'fabric_width_source', COALESCE(
          (SELECT fr.fabric_width_source FROM "FabricRules" fr
           WHERE fr.organization_id = p_org_id AND fr.product_type_id = v_cp.product_type_id
             AND fr.is_active = true LIMIT 1),
          'finished_width'
        ),
        'fabric_cut_width_mm', v_consumption.fabric_cut_width_mm,
        'fabric_cut_height_mm', v_consumption.fabric_cut_height_mm,
        'fabric_width_used_m', v_consumption.fabric_width_used_m,
        'waste_pct', v_consumption.waste_pct,
        'consumption_qty', v_consumption.qty,
        'consumption_uom', v_consumption.pricing_uom,
        'panel_detail', v_consumption.panel_detail
      );

      v_dim_outputs := v_dim_outputs || jsonb_build_object(
        'fabric_width_used_m', v_consumption.fabric_width_used_m,
        'fabric_cut_width_mm', v_consumption.fabric_cut_width_mm,
        'fabric_cut_height_mm', v_consumption.fabric_cut_height_mm
      );
    ELSE
      IF COALESCE(v_item_info.roll_pricing_mode, '') = 'per_unit' THEN
        v_roll_factor := 1;
      ELSIF COALESCE(v_item_info.roll_pricing_mode, '') = 'per_linear_meter'
         OR COALESCE(v_item_info.measure_basis, '') = 'linear' THEN
        v_roll_factor := v_height_m;
      ELSE
        IF v_roll_width_effective > 0 THEN
          v_roll_factor := v_roll_width_effective * v_height_m;
        ELSE
          v_roll_factor := v_width_total_m * v_height_m;
        END IF;
      END IF;

      v_roll_factor := v_roll_factor * v_panel_count;
      v_roll_qty := GREATEST(v_roll_factor, 0);
      v_fabric_calc := jsonb_build_object('source', 'legacy');
    END IF;

    v_qty := v_roll_qty;
    v_unit_price := COALESCE(v_roll_msrp_unit, 0);
    v_line_total := ROUND(v_qty * v_unit_price, 2);

    IF v_fabric_pricing_basis = 'linear' THEN
      v_roll_uom := 'm';
    ELSIF v_fabric_pricing_basis = 'sqm' THEN
      v_roll_uom := 'm²';
    ELSE
      v_roll_uom := public.derive_pricing_uom(
        COALESCE(v_item_info.measure_basis, 'area'),
        COALESCE(v_item_info.roll_pricing_mode, 'per_square_meter'),
        true
      );
      IF v_roll_uom = 'm2' THEN v_roll_uom := 'm²'; END IF;
    END IF;

    SELECT cim.total_cost INTO v_cost_per_unit
    FROM public."CatalogItemsMSRP" cim
    WHERE cim.catalog_item_id = v_cp.roll_catalog_item_id AND cim.organization_id = p_org_id
    ORDER BY cim.updated_at DESC NULLS LAST LIMIT 1;

    v_roll_total_cost := COALESCE(v_cost_per_unit, 0) * COALESCE(v_roll_qty, 0);

    v_roll_item := jsonb_build_object(
      'id', COALESCE(v_cp.roll_catalog_item_id::text, 'roll:' || COALESCE(v_cp.roll_sku, 'unknown')),
      'kind', 'roll', 'role', 'fabric', 'level', 0, 'selected', true,
      'catalog_item_id', v_cp.roll_catalog_item_id,
      'sku', v_cp.roll_sku,
      'name', COALESCE(v_cp.roll_variant_name, v_item_info.name, v_cp.roll_sku),
      'qty', ROUND(v_qty, 3), 'uom', v_roll_uom,
      'unit_price', v_unit_price, 'line_total', v_line_total,
      'children', '[]'::jsonb,
      'meta', jsonb_build_object(
        'collection_name', v_cp.roll_collection_name,
        'variant_name', v_cp.roll_variant_name,
        'roll_width', v_cp.roll_width,
        'roll_factor', v_roll_factor
      )
    );
    v_items := v_items || v_roll_item;
  ELSE
    v_roll_total_cost := 0;
  END IF;

  IF p_bom_template_id IS NOT NULL THEN
    FOR v_comp IN
      SELECT bc.id, bc.component_role, bc.component_item_id, bc.qty_type, bc.qty_value,
             bc.qty_delta_mm, bc.qty_spacing_mm, bc.qty_min, bc.uom,
             bc.parent_component_id, bc.sort_order
      FROM public."BOMComponents" bc
      WHERE bc.bom_template_id = p_bom_template_id
        AND bc.organization_id = p_org_id
        AND bc.deleted = false AND bc.archived = false
        AND bc.parent_component_id IS NULL
      ORDER BY bc.sort_order ASC
    LOOP
      v_selected := false;
      DECLARE
        v_role_lower text := lower(COALESCE(v_comp.component_role, ''));
        v_selected_id uuid;
        v_config2 jsonb := COALESCE(v_cp.config_snapshot, '{}'::jsonb);
      BEGIN
        CASE v_role_lower
          WHEN 'bottom_bar'     THEN v_selected_id := public.try_parse_uuid(v_config2->>'bottom_bar_item_id');
          WHEN 'headbox'        THEN v_selected_id := public.try_parse_uuid(v_config2->>'headbox_item_id');
          WHEN 'side_channel'   THEN v_selected_id := public.try_parse_uuid(v_config2->>'side_channel_item_id');
          WHEN 'bottom_channel' THEN v_selected_id := public.try_parse_uuid(v_config2->>'bottom_channel_item_id');
          WHEN 'motor'          THEN v_selected_id := public.try_parse_uuid(v_config2->>'motor_item_id');
          WHEN 'drive'          THEN v_selected_id := public.try_parse_uuid(v_config2->>'drive_item_id');
          WHEN 'tube'           THEN v_selected_id := public.try_parse_uuid(v_config2->>'tube_item_id');
          ELSE v_selected_id := NULL;
        END CASE;
        IF v_selected_id IS NOT NULL THEN
          v_comp.component_item_id := v_selected_id;
          v_selected := true;
        END IF;
      END;

      IF v_comp.component_item_id IS NULL THEN CONTINUE; END IF;

      SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
      FROM public."CatalogItems" ci
      WHERE ci.id = v_comp.component_item_id AND ci.organization_id = p_org_id LIMIT 1;

      SELECT cim.msrp, cim.total_cost INTO v_msrp_info
      FROM public."CatalogItemsMSRP" cim
      WHERE cim.catalog_item_id = v_comp.component_item_id AND cim.organization_id = p_org_id
      ORDER BY cim.updated_at DESC NULLS LAST LIMIT 1;

      v_qty := COALESCE(v_comp.qty_value, 1);
      CASE COALESCE(v_comp.qty_type, 'fixed')
        WHEN 'per_width', 'width' THEN v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_height', 'height' THEN v_qty := GREATEST(0, (v_height_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_m2', 'area' THEN v_qty := GREATEST(0, v_area_m2);
        WHEN 'per_fabric_width' THEN
          v_qty := COALESCE((v_dim_outputs->>'fabric_width_used_m')::numeric, v_width_m)
                 * COALESCE(v_comp.qty_value, 1);
        WHEN 'per_spacing' THEN
          DECLARE
            v_dim_mm_s numeric;
          BEGIN
            v_dim_mm_s := v_width_mm;
            IF v_comp.qty_spacing_mm IS NOT NULL AND v_comp.qty_spacing_mm > 0 THEN
              v_qty := CEIL(v_dim_mm_s / v_comp.qty_spacing_mm);
              IF v_comp.qty_min IS NOT NULL AND v_qty < v_comp.qty_min THEN
                v_qty := v_comp.qty_min;
              END IF;
            ELSE
              v_qty := COALESCE(v_comp.qty_value, 1);
            END IF;
          END;
        ELSE v_qty := COALESCE(v_comp.qty_value, 1);
      END CASE;

      v_unit_price := COALESCE(v_msrp_info.msrp, 0);
      v_line_total := ROUND(v_qty * v_unit_price, 2);
      v_bom_cost_from_items := v_bom_cost_from_items + (v_qty * COALESCE(v_msrp_info.total_cost, 0));

      DECLARE
        v_parent_sku text := v_item_info.sku;
        v_parent_name text := v_item_info.name;
        v_parent_uom text := v_item_info.unit_of_measure;
      BEGIN

      v_children := '[]'::jsonb;
      FOR v_child IN
        SELECT bc.id, bc.component_role, bc.component_item_id, bc.qty_type, bc.qty_value,
               bc.qty_delta_mm, bc.qty_spacing_mm, bc.qty_min, bc.uom
        FROM public."BOMComponents" bc
        WHERE bc.parent_component_id = v_comp.id
          AND bc.organization_id = p_org_id AND bc.deleted = false AND bc.archived = false
        ORDER BY bc.sort_order ASC
      LOOP
        IF v_child.component_item_id IS NULL THEN CONTINUE; END IF;

        SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
        FROM public."CatalogItems" ci
        WHERE ci.id = v_child.component_item_id AND ci.organization_id = p_org_id LIMIT 1;

        SELECT cim.msrp, cim.total_cost INTO v_msrp_info
        FROM public."CatalogItemsMSRP" cim
        WHERE cim.catalog_item_id = v_child.component_item_id AND cim.organization_id = p_org_id
        ORDER BY cim.updated_at DESC NULLS LAST LIMIT 1;

        DECLARE
          v_child_qty numeric;
          v_child_line_total numeric;
        BEGIN
          v_child_qty := COALESCE(v_child.qty_value, 1);
          CASE COALESCE(v_child.qty_type, 'fixed')
            WHEN 'per_width', 'width' THEN v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
            WHEN 'per_height', 'height' THEN v_child_qty := GREATEST(0, (v_height_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0);
            WHEN 'per_m2', 'area' THEN v_child_qty := GREATEST(0, v_area_m2);
            WHEN 'per_fabric_width' THEN
              v_child_qty := COALESCE((v_dim_outputs->>'fabric_width_used_m')::numeric, v_width_m)
                           * COALESCE(v_child.qty_value, 1);
            WHEN 'per_spacing' THEN
              DECLARE
                v_cdim numeric;
              BEGIN
                v_cdim := v_width_mm;
                IF v_child.qty_spacing_mm IS NOT NULL AND v_child.qty_spacing_mm > 0 THEN
                  v_child_qty := CEIL(v_cdim / v_child.qty_spacing_mm);
                  IF v_child.qty_min IS NOT NULL AND v_child_qty < v_child.qty_min THEN
                    v_child_qty := v_child.qty_min;
                  END IF;
                ELSE
                  v_child_qty := COALESCE(v_child.qty_value, 1);
                END IF;
              END;
            ELSE v_child_qty := COALESCE(v_child.qty_value, 1);
          END CASE;
          v_child_unit_price := COALESCE(v_msrp_info.msrp, 0);
          v_child_line_total := ROUND(v_child_qty * v_child_unit_price, 2);
          v_bom_cost_from_items := v_bom_cost_from_items + (v_child_qty * COALESCE(v_msrp_info.total_cost, 0));
          v_children := v_children || jsonb_build_object(
            'id', v_child.id::text, 'kind', 'child', 'role', COALESCE(v_child.component_role, 'child'),
            'level', 1, 'selected', false, 'catalog_item_id', v_child.component_item_id,
            'sku', v_item_info.sku, 'name', v_item_info.name,
            'qty', ROUND(v_child_qty, 3),
            'uom', COALESCE(v_child.uom, v_item_info.unit_of_measure, 'ea'),
            'unit_price', v_child_unit_price, 'line_total', v_child_line_total,
            'children', '[]'::jsonb, 'meta', '{}'::jsonb
          );
        END;
      END LOOP;

      v_items := v_items || jsonb_build_object(
        'id', v_comp.id::text, 'kind', 'parent', 'role', COALESCE(v_comp.component_role, 'component'),
        'level', 0, 'selected', v_selected, 'catalog_item_id', v_comp.component_item_id,
        'sku', v_parent_sku, 'name', v_parent_name,
        'qty', ROUND(v_qty, 3),
        'uom', COALESCE(v_comp.uom, v_parent_uom, 'ea'),
        'unit_price', v_unit_price, 'line_total', v_line_total,
        'children', v_children, 'meta', '{}'::jsonb
      );
      END;
    END LOOP;
  END IF;

  SELECT * INTO v_cp FROM public."ConfiguredProducts" WHERE id = p_configured_product_id AND organization_id = p_org_id;

  SELECT COALESCE(SUM((item->>'line_total')::numeric), 0) INTO v_roll_msrp_total
  FROM jsonb_array_elements(v_items) AS item WHERE item->>'kind' = 'roll';
  IF v_roll_msrp_total = 0 THEN v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0); END IF;

  SELECT COALESCE(SUM(
    (item->>'line_total')::numeric +
    COALESCE((SELECT SUM((c->>'line_total')::numeric) FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c), 0)
  ), 0) INTO v_bom_sum
  FROM jsonb_array_elements(v_items) AS item WHERE item->>'kind' = 'parent';
  IF v_bom_sum = 0 THEN v_bom_sum := COALESCE(v_cp.bom_total, 0); END IF;

  v_accessories_total := COALESCE(v_cp.accessories_total, 0);
  v_msrp_product_subtotal := v_roll_msrp_total + v_bom_sum + v_accessories_total;

  v_bom_total_cost_val := CASE
    WHEN v_bom_cost_from_items > 0 THEN ROUND(v_bom_cost_from_items, 4)
    ELSE COALESCE(v_cp.bom_total_cost, 0)
  END;
  v_base_cost := v_roll_total_cost + v_bom_total_cost_val + COALESCE(v_cp.accessories_total_cost, 0);
  v_labor_cost := ROUND(v_base_cost * CASE WHEN v_labor_pct <= 1 THEN v_labor_pct ELSE (v_labor_pct / 100.0) END, 4);

  v_labor_amount := ROUND(
    v_msrp_product_subtotal
    * CASE WHEN v_labor_msrp_pct <= 1 THEN v_labor_msrp_pct ELSE (v_labor_msrp_pct / 100.0) END,
    4
  );
  v_labor_dealer := ROUND(v_labor_cost / GREATEST(0.01, 1 - (CASE WHEN v_labor_dealer_pct <= 1 THEN v_labor_dealer_pct ELSE (v_labor_dealer_pct / 100.0) END)), 4);

  v_total_msrp := v_msrp_product_subtotal + v_labor_amount;

  v_totals := jsonb_build_object(
    'roll_qty', v_roll_qty,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_sum,
    'accessories_total', v_accessories_total,
    'labor_pct', CASE WHEN v_labor_pct <= 1 THEN v_labor_pct * 100 ELSE v_labor_pct END,
    'labor_dealer_pct', CASE WHEN v_labor_dealer_pct <= 1 THEN v_labor_dealer_pct * 100 ELSE v_labor_dealer_pct END,
    'labor_msrp_pct', CASE WHEN v_labor_msrp_pct <= 1 THEN v_labor_msrp_pct * 100 ELSE v_labor_msrp_pct END,
    'labor_amount', v_labor_amount,
    'labor_msrp_total', v_labor_amount,
    'labor_cost', v_labor_cost,
    'labor_dealer_total', v_labor_dealer,
    'roll_total_cost', v_roll_total_cost,
    'bom_total_cost', v_bom_total_cost_val,
    'accessories_total_cost', COALESCE(v_cp.accessories_total_cost, 0),
    'total_cost', v_base_cost + v_labor_cost,
    'msrp_product_subtotal', v_msrp_product_subtotal,
    'unit_dealer_price', 0,
    'dealer_price_total', 0,
    'fabric_calc', COALESCE(v_fabric_calc, '{"source":"none"}'::jsonb)
  );

  UPDATE "ConfiguredProducts"
  SET dimension_outputs = v_dim_outputs
  WHERE id = p_configured_product_id AND organization_id = p_org_id;

  RETURN jsonb_build_object('version', '1', 'product_type_id', v_cp.product_type_id, 'bom_template_id', p_bom_template_id,
    'price_basis', 'msrp', 'currency', 'USD', 'totals', v_totals, 'items', v_items);
END;
$$;

COMMENT ON FUNCTION public.build_bom_preview_snapshot(uuid, uuid, uuid) IS
'BOM preview with consumption engine. Includes panel_detail in fabric_calc for multi-panel auditability.';


CREATE OR REPLACE FUNCTION public.generate_bom_for_manufacturing_order(p_manufacturing_order_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_mo RECORD;
    v_mo_line RECORD;
    v_sol RECORD;
    v_bi_id uuid;
    v_bt_id uuid;
    v_bc RECORD;
    v_child RECORD;
    v_ci RECORD;
    v_fc integer := 0;
    v_qty numeric;
    v_uom text;
    v_ucx numeric(12,4) := 0;
    v_tcx numeric(12,4) := 0;
    v_um numeric(12,4) := 0;
    v_tm numeric(12,4) := 0;
    v_btc numeric(12,4) := 0;
    v_cs RECORD;
    v_sp numeric(8,4) := 0;
    v_ip numeric(8,4) := 0;
    v_mm numeric(8,4) := 35.0;
    v_md numeric(8,4) := 65.0;
    v_lp numeric(8,4) := 0;
    v_cl integer := 0;
    v_err text[] := ARRAY[]::text[];
    v_warn text[] := ARRAY[]::text[];
    v_tbi integer := 0;
    v_tbl integer := 0;
    v_mlp integer := 0;
    v_mlb integer := 0;
    v_mla integer := 0;
    v_cml integer := 0;
    v_bib integer := 0;
    v_bia integer := 0;
    v_blb integer := 0;
    v_bla integer := 0;
    v_cfm boolean := false;
    v_cut_length numeric;
    v_cut_height numeric;
    v_dim_mm numeric;
    v_parent_cut_length numeric;
    v_parent_cut_height numeric;
    v_dim_outputs jsonb;
    v_fabric_width_used_m numeric;
    v_panel_count_dim integer;
    v_panel_cuts_key text;
    v_panel_cuts jsonb;
    v_pc jsonb;
    v_panel_cut_mm numeric;
    v_panel_idx integer;
BEGIN
    SELECT * INTO v_mo FROM public."ManufacturingOrders" WHERE id = p_manufacturing_order_id;
    IF v_mo.id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'errors', ARRAY['MO not found'], 'warnings', ARRAY[]::text[]);
    END IF;
    IF v_mo.deleted = true THEN
        RETURN jsonb_build_object('ok', false, 'errors', ARRAY['MO is deleted'], 'warnings', ARRAY[]::text[]);
    END IF;
    IF v_mo.sales_order_id IS NULL THEN
        v_warn := v_warn || 'MO has no sales_order_id';
    END IF;

    SELECT COUNT(*) INTO v_mlb FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

    SELECT COUNT(*) INTO v_bib FROM public."BOMInstances"
    WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

    SELECT COUNT(*) INTO v_blb FROM public."BOMInstanceLines" bil
    JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id
    WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.deleted = false AND bil.deleted = false;

    IF v_mlb = 0 AND v_mo.sales_order_id IS NOT NULL THEN
        INSERT INTO public."ManufacturingOrderLines"(manufacturing_order_id, sales_order_line_id, organization_id, status)
        SELECT p_manufacturing_order_id, sol.id, COALESCE(v_mo.organization_id, sol.organization_id), 'planned'
        FROM public."SaleOrderLines" sol
        WHERE sol.sales_order_id = v_mo.sales_order_id AND COALESCE(sol.deleted, false) = false
          AND NOT EXISTS (
            SELECT 1 FROM public."ManufacturingOrderLines" m2
            WHERE m2.manufacturing_order_id = p_manufacturing_order_id AND m2.sales_order_line_id = sol.id
          );
        GET DIAGNOSTICS v_cml = ROW_COUNT;
    END IF;

    SELECT COUNT(*) INTO v_mla FROM public."ManufacturingOrderLines"
    WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

    IF v_mla = 0 THEN
        RETURN jsonb_build_object(
            'ok', true, 'mo_lines_before', v_mlb, 'mo_lines_after', v_mla,
            'mo_lines_created', v_cml, 'bom_instances_before', v_bib,
            'bom_instances_after', v_bib, 'bom_instances_created', 0,
            'bom_instance_lines_before', v_blb, 'bom_instance_lines_after', v_blb,
            'bom_instance_lines_created', 0, 'warnings', v_warn, 'errors', v_err
        );
    END IF;

    SELECT shipping_pct, import_tax_pct, minimum_margin_pct, default_msrp_pct, labor_pct
    INTO v_cs FROM "CostSettings"
    WHERE organization_id = v_mo.organization_id AND is_active = true LIMIT 1;

    IF FOUND THEN
        v_sp := COALESCE(v_cs.shipping_pct, 0);
        v_ip := COALESCE(v_cs.import_tax_pct, 0);
        v_mm := COALESCE(v_cs.minimum_margin_pct, 35.0);
        v_lp := COALESCE(v_cs.labor_pct, 0);
        v_md := COALESCE(v_cs.default_msrp_pct, 65.0);
    END IF;

    FOR v_mo_line IN
        SELECT mol.sales_order_line_id FROM public."ManufacturingOrderLines" mol
        WHERE mol.manufacturing_order_id = p_manufacturing_order_id AND mol.deleted = false
        ORDER BY mol.created_at ASC
    LOOP
        v_mlp := v_mlp + 1;
        v_bi_id := NULL;
        v_bt_id := NULL;
        v_fc := 0;
        v_btc := 0;
        v_cl := 0;
        v_dim_outputs := '{}'::jsonb;
        v_fabric_width_used_m := 0;

        SELECT sol.id, sol.product_type, sol.collection_name, sol.variant_name,
               sol.width_m, sol.height_m, sol.area, sol.hardware_color, sol.quote_line_id
        INTO v_sol
        FROM "SaleOrderLines" sol
        WHERE sol.id = v_mo_line.sales_order_line_id AND sol.deleted = false;

        IF NOT FOUND THEN
            v_warn := v_warn || format('SaleOrderLine %s not found', v_mo_line.sales_order_line_id);
            CONTINUE;
        END IF;

        IF v_sol.product_type IS NULL OR TRIM(v_sol.product_type) = '' THEN
            v_warn := v_warn || format('SaleOrderLine %s has NULL product_type', v_sol.id);
            CONTINUE;
        END IF;

        SELECT bt.id INTO v_bt_id FROM "BOMTemplates" bt
        INNER JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
        WHERE pt.code = v_sol.product_type AND bt.is_active = true AND bt.deleted = false
        ORDER BY bt.created_at DESC LIMIT 1;

        IF NOT FOUND THEN
            v_warn := v_warn || format('No BOMTemplate for: %s', v_sol.product_type);
            CONTINUE;
        END IF;

        BEGIN
          SELECT cp.dimension_outputs INTO v_dim_outputs
          FROM "QuoteLines" ql
          JOIN "ConfiguredProducts" cp ON cp.id = ql.configured_product_id
          WHERE ql.id = v_sol.quote_line_id AND cp.deleted = false
          LIMIT 1;
        EXCEPTION WHEN OTHERS THEN
          v_dim_outputs := '{}'::jsonb;
        END;

        IF v_dim_outputs IS NULL THEN v_dim_outputs := '{}'::jsonb; END IF;
        v_fabric_width_used_m := COALESCE((v_dim_outputs->>'fabric_width_used_m')::numeric, 0);
        v_panel_count_dim := COALESCE((v_dim_outputs->>'panel_count')::integer, 1);

        UPDATE "BOMInstanceLines" bil SET deleted = true, updated_at = now()
        WHERE bil.bom_instance_id IN (
            SELECT bi.id FROM "BOMInstances" bi
            WHERE bi.manufacturing_order_id = p_manufacturing_order_id
              AND bi.sales_order_line_id = v_sol.id AND bi.deleted = false
        );

        UPDATE "BOMInstances" bi SET deleted = true, updated_at = now()
        WHERE bi.manufacturing_order_id = p_manufacturing_order_id
          AND bi.sales_order_line_id = v_sol.id AND bi.deleted = false;

        INSERT INTO "BOMInstances" (
            organization_id, manufacturing_order_id, sales_order_line_id,
            quote_line_id, bom_template_id, deleted, created_at, updated_at
        ) VALUES (
            v_mo.organization_id, p_manufacturing_order_id, v_sol.id,
            v_sol.quote_line_id, v_bt_id, false, now(), now()
        ) RETURNING id INTO v_bi_id;

        IF v_bi_id IS NULL THEN CONTINUE; END IF;
        v_tbi := v_tbi + 1;

        FOR v_bc IN
            SELECT bc.id, bc.component_role, bc.component_item_id,
                   bc.qty_type, bc.qty_value, bc.uom,
                   bc.qty_spacing_mm, bc.qty_min, bc.cut_delta_mm,
                   bc.depends_on_role
            FROM "BOMComponents" bc
            WHERE bc.bom_template_id = v_bt_id
              AND bc.deleted = false
              AND bc.component_item_id IS NOT NULL
              AND bc.parent_component_id IS NULL
            ORDER BY bc.sort_order, bc.created_at
        LOOP
            IF v_bc.component_role = 'fabric' THEN
                v_fc := v_fc + 1;
                IF v_fc > 1 THEN CONTINUE; END IF;
                SELECT ci.id, ci.sku, ci.name, ci.description, ci.cost_exw
                INTO v_ci FROM "CatalogItems" ci
                INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                WHERE ci.id = v_bc.component_item_id
                  AND ci.organization_id = v_mo.organization_id
                  AND ci.is_active = true AND ic.code = 'FABRIC'
                  AND ci.collection_name = v_sol.collection_name
                  AND ((v_sol.variant_name IS NULL AND ci.variant_name IS NULL) OR ci.variant_name = v_sol.variant_name);
                IF NOT FOUND THEN
                    v_warn := v_warn || format('Fabric mismatch %s', v_bc.component_item_id);
                    CONTINUE;
                END IF;
            ELSE
                SELECT ci.id, ci.sku, ci.name, ci.description, ci.cost_exw
                INTO v_ci FROM "CatalogItems" ci
                WHERE ci.id = v_bc.component_item_id
                  AND ci.organization_id = v_mo.organization_id
                  AND ci.is_active = true;
                IF NOT FOUND THEN
                    v_warn := v_warn || format('CatalogItem %s not found', v_bc.component_item_id);
                    CONTINUE;
                END IF;
            END IF;

            IF v_bc.qty_type = 'per_width' THEN
                IF v_sol.width_m IS NULL THEN CONTINUE; END IF;
                v_qty := v_sol.width_m * COALESCE(v_bc.qty_value, 1);
            ELSIF v_bc.qty_type = 'per_height' THEN
                IF v_sol.height_m IS NULL THEN CONTINUE; END IF;
                v_qty := v_sol.height_m * COALESCE(v_bc.qty_value, 1);
            ELSIF v_bc.qty_type = 'per_area' THEN
                IF v_sol.width_m IS NULL OR v_sol.height_m IS NULL THEN CONTINUE; END IF;
                v_qty := v_sol.width_m * v_sol.height_m * COALESCE(v_bc.qty_value, 1);
            ELSIF v_bc.qty_type = 'per_fabric_width' THEN
                v_qty := COALESCE(v_fabric_width_used_m, COALESCE(v_sol.width_m, 0))
                       * COALESCE(v_bc.qty_value, 1);
            ELSIF v_bc.qty_type = 'per_spacing' THEN
                v_dim_mm := COALESCE(v_sol.width_m, 0) * 1000.0;
                IF v_bc.depends_on_role IS NOT NULL AND v_bc.depends_on_role = 'height' THEN
                    v_dim_mm := COALESCE(v_sol.height_m, 0) * 1000.0;
                END IF;
                IF v_dim_mm <= 0 THEN CONTINUE; END IF;
                v_qty := CEIL(v_dim_mm / COALESCE(v_bc.qty_spacing_mm, 500));
                IF v_bc.qty_min IS NOT NULL AND v_qty < v_bc.qty_min THEN
                    v_qty := v_bc.qty_min;
                END IF;
            ELSIF v_bc.qty_type = 'fixed' THEN
                v_qty := COALESCE(v_bc.qty_value, 1);
            ELSE
                CONTINUE;
            END IF;

            IF v_qty IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;

            v_uom := CASE
                WHEN UPPER(TRIM(v_bc.uom)) IN ('PCS','PIECE','PIECES','SET','SETS','EA','EACH') THEN 'ea'
                WHEN v_bc.component_role = 'fabric' THEN 'm2'
                WHEN v_bc.component_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile','chain','tape')
                     OR UPPER(TRIM(v_bc.uom)) IN ('FT','FEET','FOOT','MTS','M','METER','METERS') THEN 'm'
                WHEN UPPER(TRIM(v_bc.uom)) IN ('M2','SQM','SQ_M') THEN 'm2'
                ELSE NULL
            END;
            IF v_uom IS NULL THEN CONTINUE; END IF;

            v_cfm := false;
            SELECT cim.total_cost INTO v_ucx FROM "CatalogItemsMSRP" cim
            WHERE cim.catalog_item_id = v_ci.id AND cim.organization_id = v_mo.organization_id
              AND cim.total_cost IS NOT NULL LIMIT 1;
            IF FOUND AND v_ucx IS NOT NULL THEN
                v_cfm := true;
            ELSE
                v_ucx := COALESCE(CAST(v_ci.cost_exw AS numeric(12,4)), 0);
            END IF;

            -- ── Per-panel logic for tube/bottom_bar ──
            v_panel_cuts_key := v_bc.component_role || '_panel_cuts';
            v_panel_cuts := v_dim_outputs->v_panel_cuts_key;

            IF v_panel_cuts IS NOT NULL
               AND jsonb_typeof(v_panel_cuts) = 'array'
               AND jsonb_array_length(v_panel_cuts) > 1
               AND v_bc.component_role IN ('tube', 'bottom_bar')
            THEN
                FOR v_pc IN SELECT value FROM jsonb_array_elements(v_panel_cuts) AS value LOOP
                    v_panel_idx := (v_pc->>'index')::integer;
                    v_panel_cut_mm := COALESCE((v_pc->>( v_bc.component_role || '_width_mm'))::numeric, 0);

                    v_cut_length := v_panel_cut_mm;
                    v_cut_height := NULL;
                    v_qty := v_panel_cut_mm / 1000.0;

                    v_tcx := v_ucx * v_qty;
                    IF v_ucx > 0 THEN
                        DECLARE vc numeric(12,4); vm numeric(12,4);
                        BEGIN
                            IF v_cfm THEN vc := v_ucx; ELSE vc := v_ucx * (1 + (v_sp / 100.0) + (v_ip / 100.0)); END IF;
                            vm := vc / (1 - (v_mm / 100.0));
                            v_um := vm / (1 - (v_md / 100.0));
                            v_tm := v_um * v_qty;
                        END;
                    ELSE
                        v_um := 0; v_tm := 0;
                    END IF;
                    v_btc := v_btc + v_tcx;

                    INSERT INTO "BOMInstanceLines" (
                        organization_id, bom_instance_id, resolved_part_id,
                        part_role, qty, uom,
                        unit_cost_exw, total_cost_exw, unit_msrp, total_msrp,
                        cut_length_mm, cut_height_mm, panel_index,
                        deleted, created_at, updated_at
                    ) VALUES (
                        v_mo.organization_id, v_bi_id, v_ci.id,
                        v_bc.component_role, v_qty, v_uom,
                        COALESCE(v_ucx, 0)::numeric(12,4), COALESCE(v_tcx, 0)::numeric(12,4),
                        COALESCE(v_um, 0)::numeric(12,4), COALESCE(v_tm, 0)::numeric(12,4),
                        v_cut_length, v_cut_height, v_panel_idx,
                        false, now(), now()
                    );
                    v_cl := v_cl + 1;
                    v_tbl := v_tbl + 1;
                END LOOP;

                v_parent_cut_length := NULL;
                v_parent_cut_height := NULL;

            ELSE
                -- Single panel or non-tube/bottom_bar: original logic
                v_tcx := v_ucx * v_qty;
                IF v_ucx > 0 THEN
                    DECLARE vc numeric(12,4); vm numeric(12,4);
                    BEGIN
                        IF v_cfm THEN vc := v_ucx; ELSE vc := v_ucx * (1 + (v_sp / 100.0) + (v_ip / 100.0)); END IF;
                        vm := vc / (1 - (v_mm / 100.0));
                        v_um := vm / (1 - (v_md / 100.0));
                        v_tm := v_um * v_qty;
                    END;
                ELSE
                    v_um := 0; v_tm := 0;
                END IF;
                v_btc := v_btc + v_tcx;

                v_cut_length := CASE
                    WHEN v_bc.qty_type = 'per_width'
                         OR v_bc.component_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile')
                    THEN COALESCE(v_sol.width_m, 0) * 1000.0 + COALESCE(v_bc.cut_delta_mm, 0)
                    ELSE NULL
                END;
                v_cut_height := CASE
                    WHEN v_bc.qty_type = 'per_height'
                         OR v_bc.component_role IN ('side_channel','side_channel_left','side_channel_right')
                    THEN COALESCE(v_sol.height_m, 0) * 1000.0 + COALESCE(v_bc.cut_delta_mm, 0)
                    ELSE NULL
                END;

                v_parent_cut_length := v_cut_length;
                v_parent_cut_height := v_cut_height;

                INSERT INTO "BOMInstanceLines" (
                    organization_id, bom_instance_id, resolved_part_id,
                    part_role, qty, uom,
                    unit_cost_exw, total_cost_exw, unit_msrp, total_msrp,
                    cut_length_mm, cut_height_mm,
                    deleted, created_at, updated_at
                ) VALUES (
                    v_mo.organization_id, v_bi_id, v_ci.id,
                    v_bc.component_role, v_qty, v_uom,
                    COALESCE(v_ucx, 0)::numeric(12,4), COALESCE(v_tcx, 0)::numeric(12,4),
                    COALESCE(v_um, 0)::numeric(12,4), COALESCE(v_tm, 0)::numeric(12,4),
                    v_cut_length, v_cut_height,
                    false, now(), now()
                );
                v_cl := v_cl + 1;
                v_tbl := v_tbl + 1;
            END IF;

            FOR v_child IN
                SELECT cc.id, cc.component_role, cc.component_item_id,
                       cc.qty_type, cc.qty_value, cc.uom,
                       cc.qty_spacing_mm, cc.qty_min, cc.cut_delta_mm,
                       cc.depends_on_role
                FROM "BOMComponents" cc
                WHERE cc.parent_component_id = v_bc.id
                  AND cc.deleted = false
                  AND cc.component_item_id IS NOT NULL
                ORDER BY cc.sort_order, cc.created_at
            LOOP
                SELECT ci.id, ci.sku, ci.name, ci.description, ci.cost_exw
                INTO v_ci FROM "CatalogItems" ci
                WHERE ci.id = v_child.component_item_id
                  AND ci.organization_id = v_mo.organization_id
                  AND ci.is_active = true;
                IF NOT FOUND THEN
                    v_warn := v_warn || format('Child CatalogItem %s not found (parent comp %s)', v_child.component_item_id, v_bc.id);
                    CONTINUE;
                END IF;

                IF v_child.qty_type = 'per_width' THEN
                    IF v_sol.width_m IS NULL THEN CONTINUE; END IF;
                    v_qty := v_sol.width_m * COALESCE(v_child.qty_value, 1);
                ELSIF v_child.qty_type = 'per_height' THEN
                    IF v_sol.height_m IS NULL THEN CONTINUE; END IF;
                    v_qty := v_sol.height_m * COALESCE(v_child.qty_value, 1);
                ELSIF v_child.qty_type = 'per_area' THEN
                    IF v_sol.width_m IS NULL OR v_sol.height_m IS NULL THEN CONTINUE; END IF;
                    v_qty := v_sol.width_m * v_sol.height_m * COALESCE(v_child.qty_value, 1);
                ELSIF v_child.qty_type = 'per_fabric_width' THEN
                    v_qty := COALESCE(v_fabric_width_used_m, COALESCE(v_sol.width_m, 0))
                           * COALESCE(v_child.qty_value, 1);
                ELSIF v_child.qty_type = 'per_spacing' THEN
                    v_dim_mm := COALESCE(v_parent_cut_length, COALESCE(v_sol.width_m, 0) * 1000.0);
                    IF v_child.depends_on_role IS NOT NULL AND v_child.depends_on_role = 'height' THEN
                        v_dim_mm := COALESCE(v_parent_cut_height, COALESCE(v_sol.height_m, 0) * 1000.0);
                    END IF;
                    IF v_dim_mm IS NULL OR v_dim_mm <= 0 THEN CONTINUE; END IF;
                    v_qty := CEIL(v_dim_mm / COALESCE(v_child.qty_spacing_mm, 500));
                    IF v_child.qty_min IS NOT NULL AND v_qty < v_child.qty_min THEN
                        v_qty := v_child.qty_min;
                    END IF;
                ELSIF v_child.qty_type = 'fixed' THEN
                    v_qty := COALESCE(v_child.qty_value, 1);
                ELSE
                    CONTINUE;
                END IF;

                IF v_qty IS NULL OR v_qty <= 0 THEN CONTINUE; END IF;

                v_uom := CASE
                    WHEN UPPER(TRIM(v_child.uom)) IN ('PCS','PIECE','PIECES','SET','SETS','EA','EACH') THEN 'ea'
                    WHEN v_child.component_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile','chain','tape')
                         OR UPPER(TRIM(v_child.uom)) IN ('FT','FEET','FOOT','MTS','M','METER','METERS') THEN 'm'
                    WHEN UPPER(TRIM(v_child.uom)) IN ('M2','SQM','SQ_M') THEN 'm2'
                    ELSE NULL
                END;
                IF v_uom IS NULL THEN CONTINUE; END IF;

                v_cfm := false;
                SELECT cim.total_cost INTO v_ucx FROM "CatalogItemsMSRP" cim
                WHERE cim.catalog_item_id = v_ci.id AND cim.organization_id = v_mo.organization_id
                  AND cim.total_cost IS NOT NULL LIMIT 1;
                IF FOUND AND v_ucx IS NOT NULL THEN
                    v_cfm := true;
                ELSE
                    v_ucx := COALESCE(CAST(v_ci.cost_exw AS numeric(12,4)), 0);
                END IF;
                v_tcx := v_ucx * v_qty;
                IF v_ucx > 0 THEN
                    DECLARE vc numeric(12,4); vm numeric(12,4);
                    BEGIN
                        IF v_cfm THEN vc := v_ucx; ELSE vc := v_ucx * (1 + (v_sp / 100.0) + (v_ip / 100.0)); END IF;
                        vm := vc / (1 - (v_mm / 100.0));
                        v_um := vm / (1 - (v_md / 100.0));
                        v_tm := v_um * v_qty;
                    END;
                ELSE
                    v_um := 0;
                    v_tm := 0;
                END IF;

                v_btc := v_btc + v_tcx;

                v_cut_length := CASE
                    WHEN v_child.qty_type = 'per_width'
                         OR v_child.component_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile')
                    THEN COALESCE(v_sol.width_m, 0) * 1000.0 + COALESCE(v_child.cut_delta_mm, 0)
                    ELSE NULL
                END;
                v_cut_height := CASE
                    WHEN v_child.qty_type = 'per_height'
                         OR v_child.component_role IN ('side_channel','side_channel_left','side_channel_right','brush')
                    THEN COALESCE(v_sol.height_m, 0) * 1000.0 + COALESCE(v_child.cut_delta_mm, 0)
                    ELSE NULL
                END;

                INSERT INTO "BOMInstanceLines" (
                    organization_id, bom_instance_id, resolved_part_id,
                    part_role, qty, uom,
                    unit_cost_exw, total_cost_exw, unit_msrp, total_msrp,
                    cut_length_mm, cut_height_mm,
                    deleted, created_at, updated_at
                ) VALUES (
                    v_mo.organization_id, v_bi_id, v_ci.id,
                    v_child.component_role, v_qty, v_uom,
                    COALESCE(v_ucx, 0)::numeric(12,4), COALESCE(v_tcx, 0)::numeric(12,4),
                    COALESCE(v_um, 0)::numeric(12,4), COALESCE(v_tm, 0)::numeric(12,4),
                    v_cut_length, v_cut_height,
                    false, now(), now()
                );
                v_cl := v_cl + 1;
                v_tbl := v_tbl + 1;
            END LOOP;

        END LOOP;
    END LOOP;

    SELECT COUNT(*) INTO v_bia FROM public."BOMInstances"
    WHERE manufacturing_order_id = p_manufacturing_order_id AND deleted = false;

    SELECT COUNT(*) INTO v_bla FROM public."BOMInstanceLines" bil
    JOIN public."BOMInstances" bi ON bi.id = bil.bom_instance_id
    WHERE bi.manufacturing_order_id = p_manufacturing_order_id AND bi.deleted = false AND bil.deleted = false;

    RETURN jsonb_build_object(
        'ok', array_length(v_err, 1) IS NULL OR array_length(v_err, 1) = 0,
        'manufacturing_order_id', p_manufacturing_order_id,
        'mo_lines_before', v_mlb,
        'mo_lines_after', v_mla,
        'mo_lines_created', v_cml,
        'mo_lines_processed', v_mlp,
        'bom_instances_before', v_bib,
        'bom_instances_after', v_bia,
        'bom_instances_created', v_bia - v_bib,
        'bom_instance_lines_before', v_blb,
        'bom_instance_lines_after', v_bla,
        'bom_instance_lines_created', v_bla - v_blb,
        'warnings', COALESCE(v_warn, ARRAY[]::text[]),
        'errors', COALESCE(v_err, ARRAY[]::text[])
    );
END;
$function$;

COMMENT ON FUNCTION public.generate_bom_for_manufacturing_order(uuid) IS
  'Generates BOMInstances and BOMInstanceLines for a ManufacturingOrder. '
  'For multi-panel products, creates per-panel BOMInstanceLines for tube/bottom_bar '
  'with correct cut dimensions and panel_index for work order traceability.';


-- ============================================================================
-- Helper functions for panel cut lookups
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_panel_cut_mm(
  p_dimension_outputs jsonb,
  p_role text,
  p_panel_index integer
) RETURNS numeric
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  v_cuts_key text;
  v_width_key text;
  v_cuts jsonb;
  v_panel jsonb;
BEGIN
  IF p_dimension_outputs IS NULL THEN RETURN NULL; END IF;

  v_cuts_key := p_role || '_panel_cuts';
  v_width_key := p_role || '_width_mm';

  v_cuts := p_dimension_outputs->v_cuts_key;
  IF v_cuts IS NULL OR jsonb_typeof(v_cuts) != 'array' THEN
    RETURN NULL;
  END IF;

  FOR v_panel IN SELECT value FROM jsonb_array_elements(v_cuts) AS value LOOP
    IF (v_panel->>'index')::integer = p_panel_index THEN
      RETURN (v_panel->>v_width_key)::numeric;
    END IF;
  END LOOP;

  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.get_panel_cut_mm IS
  'Returns the cut width (mm) for a specific panel index and role '
  '(tube, bottom_bar) from dimension_outputs. Returns NULL if no '
  'panel cuts exist or panel not found.';

-- Helper: get panel count from dimension_outputs
CREATE OR REPLACE FUNCTION public.get_dimension_panel_count(
  p_dimension_outputs jsonb
) RETURNS integer
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
  IF p_dimension_outputs IS NULL THEN RETURN 1; END IF;
  RETURN COALESCE((p_dimension_outputs->>'panel_count')::integer, 1);
END;
$$;


NOTIFY pgrst, 'reload schema';

COMMIT;
