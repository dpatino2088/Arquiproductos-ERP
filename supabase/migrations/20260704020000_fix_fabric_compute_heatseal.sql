BEGIN;

-- =============================================================================
-- Fix compute_fabric_pricing_from_rule:
--   1. Read allow_rotation and heatseal_direction from the FabricRule record
--      instead of relying solely on external parameters.
--   2. p_can_rotate / p_is_weldable become optional overrides (NULL = use rule).
--   3. Heatseal cost calculation respects direction:
--      - 'horizontal': seam crosses the width, seams = drops - 1
--      - 'vertical':   seam crosses the height, seams = panels - 1
--      - 'none':       no heatseal ever
--   4. Return heatseal_direction so callers can store it in the snapshot.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.compute_fabric_pricing_from_rule(
    p_org_id uuid,
    p_product_type_id uuid,
    p_style_code text,
    p_height_m numeric,
    p_width_m numeric,
    p_roll_width_m numeric,
    p_msrp_per_m numeric,
    p_dimension_outputs jsonb DEFAULT NULL::jsonb,
    p_can_rotate boolean DEFAULT NULL,
    p_is_weldable boolean DEFAULT NULL,
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
    bottom_bar_wrap_cost numeric,
    heatseal_dir text
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
    v_hs_cost numeric := 0;
    v_wrap_cost numeric := 0;
    v_fabric_total_price numeric := 0;
    v_can_rotate boolean;
    v_is_weldable boolean;
    v_hs_dir text;
BEGIN
    qty := NULL; pricing_uom := NULL; unit_price := NULL;
    area_base_m2 := NULL; drops := NULL; waste_pct := NULL;
    fabric_cut_width_mm := NULL; fabric_cut_height_mm := NULL;
    fabric_width_used_m := NULL; panel_detail := NULL;
    is_rotated := false; heatseal_seams := 0;
    heatseal_cost := 0; bottom_bar_wrap_cost := 0;
    heatseal_dir := 'none';

    SELECT * INTO v_r FROM public.select_fabric_rule(p_org_id, p_product_type_id, p_style_code) LIMIT 1;
    IF NOT FOUND THEN RETURN; END IF;

    -- Resolve rotation and weldability from rule, with parameter override
    v_hs_dir := COALESCE(v_r.heatseal_direction, 'none');
    v_can_rotate := COALESCE(p_can_rotate, v_r.allow_rotation, false);
    v_is_weldable := COALESCE(p_is_weldable, v_hs_dir != 'none', false);
    heatseal_dir := v_hs_dir;

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

      IF COALESCE(v_r.formula_code, '') = 'ROLLER_DROPS'
         AND p_roll_width_m IS NOT NULL AND p_roll_width_m > 0
      THEN
          IF v_weff > p_roll_width_m AND v_can_rotate THEN
              v_rotated := true;
              v_drops := CEIL(v_heff / p_roll_width_m);
              v_area := v_drops * v_weff * p_roll_width_m;

              -- Heatseal for horizontal direction (roller): seam across width
              IF v_hs_dir = 'horizontal' AND v_is_weldable AND v_drops > 1 THEN
                  v_hs_seams := v_drops::integer - 1;
                  v_hs_cost := v_hs_seams * v_weff * COALESCE(v_r.heatseal_price_per_m, 0);
              END IF;
          ELSE
              v_drops := CEIL(v_weff / p_roll_width_m);
              v_area := v_heff * v_drops * p_roll_width_m;

              -- Heatseal for horizontal direction when NOT rotated (seam across width)
              IF v_hs_dir = 'horizontal' AND v_is_weldable AND v_drops > 1 THEN
                  v_hs_seams := v_drops::integer - 1;
                  v_hs_cost := v_hs_seams * v_heff * COALESCE(v_r.heatseal_price_per_m, 0);
              END IF;
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

          -- Heatseal for vertical direction (drapery): seam across height
          IF v_hs_dir = 'vertical' AND v_is_weldable AND v_panels_count > 1 THEN
              v_hs_seams := v_panels_count::integer - 1;
              v_hs_cost := v_hs_seams * v_cut_height * COALESCE(v_r.heatseal_price_per_m, 0);
          END IF;

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

    v_fabric_total_price := v_qty * COALESCE(v_unit_price, 0);
    IF p_bottom_bar_wrapped AND COALESCE(v_r.bottom_bar_wrap_pct, 0) > 0 THEN
        v_wrap_cost := ROUND(v_fabric_total_price * v_r.bottom_bar_wrap_pct, 2);
    END IF;

    qty := v_qty;
    pricing_uom := v_uom;
    unit_price := v_unit_price;
    drops := v_drops;
    is_rotated := v_rotated;
    heatseal_seams := v_hs_seams;
    heatseal_cost := ROUND(v_hs_cost, 2);
    bottom_bar_wrap_cost := v_wrap_cost;
    RETURN NEXT;
END;
$function$;

-- =============================================================================
-- Fix build_bom_preview_snapshot: pass NULL for rotation/weldable (let rule decide),
-- pass actual bottom_bar_wrapped from config, store heatseal info in fabric_calc.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.build_bom_preview_snapshot(
    p_org_id uuid,
    p_configured_product_id uuid,
    p_bom_template_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $function$
DECLARE
  v_cp RECORD;
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
  v_parent_items jsonb := '[]'::jsonb;
  v_children jsonb;
  v_item_id text;
  v_selected boolean;
  v_roll_msrp_total numeric;
  v_bom_sum numeric;
  v_bom_cost_sum numeric := 0;
  v_labor_amount numeric;
  v_accessories_total numeric;
  v_total_msrp numeric;
  v_child_unit_price numeric;
  v_child_line_total numeric;
  v_roll_total_cost numeric;
  v_roll_factor numeric := 0;
  v_roll_qty numeric := 0;
  v_roll_width_effective numeric;
  v_width_total_m numeric;
  v_roll_pricing_mode text;
  v_roll_measure_basis text;
  v_roll_uom text := 'm²';
  v_comp_unit_cost numeric;
  v_comp_cost_total numeric;
  v_fabric_calc jsonb := NULL;
  v_consumption RECORD;
  v_style_code text;
  v_dim_outputs jsonb;
  v_cond_key text;
  v_cond_val text;
  v_config_val text;
  v_panel_count integer;
  v_panels jsonb;
  v_parent_sku text;
  v_parent_name text;
  v_parent_uom text;
  v_resolved_cuts jsonb := '{}'::jsonb;
  v_cascade RECORD;
  v_cascade_base numeric;
  v_cascade_subtract numeric;
  v_cascade_role text;
  v_topo_queue text[] := '{}';
  v_topo_all jsonb := '[]'::jsonb;
  v_topo_resolved text[] := '{}';
  v_topo_progress boolean;
  v_topo_item jsonb;
  v_bottom_bar_wrapped boolean;
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

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
  v_style_code := COALESCE(v_config->>'style_code', '');
  v_dim_outputs := COALESCE(v_cp.dimension_outputs, '{}'::jsonb);
  v_bottom_bar_wrapped := COALESCE((v_config->>'bottom_bar_wrapped')::boolean, false);

  v_panels := COALESCE(
    v_config->'measurements'->'panels',
    v_config->'panels'
  );
  v_panel_count := CASE
    WHEN v_panels IS NOT NULL
         AND jsonb_typeof(v_panels) = 'array'
         AND jsonb_array_length(v_panels) > 0
    THEN jsonb_array_length(v_panels)
    ELSE 1
  END;

  -- ===== ROLL pricing =====
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT r.msrp, r.dealer_price, r.labor_msrp
    INTO v_roll_msrp_unit, v_roll_dealer_unit, v_roll_labor_unit
    FROM public.get_roll_pricing(p_org_id, v_cp.roll_catalog_item_id) r;

    SELECT ci.sku, ci.name, ci.unit_of_measure,
           ci.roll_pricing_mode, ci.measure_basis,
           ci.roll_width_m AS roll_width_catalog
    INTO v_item_info
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;

    v_roll_width_effective := COALESCE(v_cp.roll_width, (v_item_info.roll_width_catalog)::numeric, 0);

    -- Pass NULL for p_can_rotate and p_is_weldable so the function
    -- reads allow_rotation and heatseal_direction from the FabricRule.
    SELECT * INTO v_consumption
    FROM public.compute_fabric_pricing_from_rule(
      p_org_id,
      v_cp.product_type_id,
      v_style_code,
      v_height_m,
      v_width_m,
      v_roll_width_effective,
      COALESCE(v_roll_msrp_unit, 0),
      v_dim_outputs,
      NULL,
      NULL,
      v_bottom_bar_wrapped
    );

    IF v_consumption.qty IS NOT NULL THEN
      v_roll_qty := v_consumption.qty;
      v_roll_factor := v_consumption.qty;
      v_roll_uom := COALESCE(v_consumption.pricing_uom, 'm');
      v_unit_price := COALESCE(v_consumption.unit_price, v_roll_msrp_unit, 0);

      v_fabric_calc := jsonb_build_object(
        'source', 'FabricRule',
        'fabric_width_source', 'computed',
        'fabric_cut_width_mm', v_consumption.fabric_cut_width_mm,
        'fabric_cut_height_mm', v_consumption.fabric_cut_height_mm,
        'fabric_width_used_m', v_consumption.fabric_width_used_m,
        'waste_pct', v_consumption.waste_pct,
        'consumption_qty', v_consumption.qty,
        'consumption_uom', v_consumption.pricing_uom,
        'drops', v_consumption.drops,
        'is_rotated', COALESCE(v_consumption.is_rotated, false),
        'area_base_m2', v_consumption.area_base_m2,
        'heatseal_direction', COALESCE(v_consumption.heatseal_dir, 'none'),
        'heatseal_seams', COALESCE(v_consumption.heatseal_seams, 0),
        'heatseal_cost', COALESCE(v_consumption.heatseal_cost, 0),
        'bottom_bar_wrap_cost', COALESCE(v_consumption.bottom_bar_wrap_cost, 0)
      );
    ELSE
      IF COALESCE(v_item_info.roll_pricing_mode, '') = 'per_unit' THEN
        v_roll_factor := 1;
        v_roll_uom := 'ea';
      ELSIF COALESCE(v_item_info.roll_pricing_mode, '') = 'per_linear_meter'
         OR COALESCE(v_item_info.measure_basis, '') = 'linear' THEN
        v_roll_factor := v_height_m;
        v_roll_uom := 'm';
      ELSE
        v_roll_factor := v_width_total_m * v_height_m;
        v_roll_uom := 'm²';
      END IF;
      v_roll_qty := GREATEST(v_roll_factor, 0) * COALESCE(v_cp.quantity, 1);
      v_unit_price := COALESCE(v_roll_msrp_unit, 0);
      v_fabric_calc := jsonb_build_object('source', 'legacy');
    END IF;

    v_qty := v_roll_qty;
    v_line_total := ROUND(v_qty * v_unit_price, 2);

    SELECT cim.total_cost INTO v_roll_total_cost
    FROM public."CatalogItemsMSRP" cim
    WHERE cim.catalog_item_id = v_cp.roll_catalog_item_id
      AND cim.organization_id = p_org_id
    ORDER BY cim.updated_at DESC NULLS LAST
    LIMIT 1;

    v_roll_item := jsonb_build_object(
      'id', COALESCE(v_cp.roll_catalog_item_id::text, 'roll:' || COALESCE(v_cp.roll_sku, 'unknown')),
      'kind', 'roll', 'role', 'fabric', 'level', 0, 'selected', true,
      'catalog_item_id', v_cp.roll_catalog_item_id,
      'sku', v_cp.roll_sku,
      'name', COALESCE(v_cp.roll_variant_name, v_item_info.name, v_cp.roll_sku),
      'qty', ROUND(v_qty, 3), 'uom', v_roll_uom,
      'unit_price', v_unit_price, 'line_total', v_line_total,
      'unit_cost', COALESCE(v_roll_total_cost, 0),
      'cost_total', ROUND(COALESCE(v_roll_total_cost, 0) * v_roll_qty, 4),
      'children', '[]'::jsonb,
      'meta', jsonb_build_object(
        'collection_name', v_cp.roll_collection_name,
        'variant_name', v_cp.roll_variant_name,
        'roll_width', v_cp.roll_width,
        'roll_width_m', v_roll_width_effective,
        'roll_factor', v_roll_factor
      )
    );
    v_items := v_items || v_roll_item;
  ELSE
    v_roll_total_cost := 0;
  END IF;

  -- ===== Cascade pre-pass: topological sort + resolve cut dimensions =====
  IF p_bom_template_id IS NOT NULL THEN
    v_topo_all := '[]'::jsonb;
    FOR v_cascade IN
      SELECT bc.id, bc.component_role, bc.depends_on_role,
             bc.cut_delta_mm AS tolerance_mm, bc.cut_axis
      FROM public."BOMComponents" bc
      LEFT JOIN public."CatalogItems" ci ON ci.id = bc.component_item_id AND ci.organization_id = p_org_id
      WHERE bc.bom_template_id = p_bom_template_id
        AND bc.organization_id = p_org_id
        AND bc.deleted = false AND bc.archived = false
        AND bc.parent_component_id IS NULL
        AND COALESCE(ci.measure_basis, '') IN ('linear', 'area')
    LOOP
      v_topo_all := v_topo_all || jsonb_build_object(
        'id',   v_cascade.id,
        'role', v_cascade.component_role,
        'dep',  v_cascade.depends_on_role,
        'tol',  COALESCE(v_cascade.tolerance_mm, 0),
        'axis', COALESCE(v_cascade.cut_axis, '')
      );
    END LOOP;

    v_topo_resolved := '{}';
    LOOP
      v_topo_progress := false;
      FOR v_topo_item IN SELECT * FROM jsonb_array_elements(v_topo_all)
      LOOP
        v_cascade_role := v_topo_item->>'role';
        IF v_cascade_role = ANY(v_topo_resolved) THEN CONTINUE; END IF;

        IF v_topo_item->>'dep' IS NOT NULL
           AND v_topo_item->>'dep' != ''
           AND NOT (v_topo_item->>'dep' = ANY(v_topo_resolved))
        THEN
          CONTINUE;
        END IF;

        IF v_topo_item->>'dep' IS NOT NULL
           AND v_topo_item->>'dep' != ''
           AND v_resolved_cuts ? (v_topo_item->>'dep')
        THEN
          v_cascade_base := (v_resolved_cuts->>(v_topo_item->>'dep'))::numeric;
        ELSE
          IF (v_topo_item->>'axis') = 'height'
             OR v_cascade_role IN ('side_channel','chain','belt','brush') THEN
            v_cascade_base := v_height_mm;
          ELSE
            v_cascade_base := v_width_mm;
          END IF;
        END IF;

        v_cascade_base := v_cascade_base + (v_topo_item->>'tol')::numeric;

        SELECT COALESCE(SUM(
          COALESCE(ci2.delta_x_mm, 0) * COALESCE(bc2.qty_value, 1)
        ), 0) INTO v_cascade_subtract
        FROM public."BOMComponents" bc2
        LEFT JOIN public."CatalogItems" ci2 ON ci2.id = bc2.component_item_id AND ci2.organization_id = p_org_id
        WHERE bc2.bom_template_id = p_bom_template_id
          AND bc2.organization_id = p_org_id
          AND bc2.deleted = false AND bc2.archived = false
          AND bc2.affects_role = v_cascade_role
          AND COALESCE(bc2.delta_mode, 'subtract') = 'subtract';

        DECLARE
          v_own_children_sub numeric := 0;
          v_parent_uuid uuid;
        BEGIN
          v_parent_uuid := public.try_parse_uuid(v_topo_item->>'id');
          IF v_parent_uuid IS NOT NULL THEN
            SELECT COALESCE(SUM(
              COALESCE(ci3.delta_x_mm, 0) * COALESCE(bc3.qty_value, 1)
            ), 0) INTO v_own_children_sub
            FROM public."BOMComponents" bc3
            LEFT JOIN public."CatalogItems" ci3 ON ci3.id = bc3.component_item_id AND ci3.organization_id = p_org_id
            WHERE bc3.parent_component_id = v_parent_uuid
              AND bc3.organization_id = p_org_id
              AND bc3.deleted = false AND bc3.archived = false
              AND COALESCE(bc3.delta_mode, 'subtract') = 'subtract';
          END IF;
          v_cascade_subtract := v_cascade_subtract + v_own_children_sub;
        END;

        v_cascade_base := GREATEST(0, v_cascade_base - v_cascade_subtract);
        v_resolved_cuts := v_resolved_cuts || jsonb_build_object(v_cascade_role, v_cascade_base);
        v_topo_resolved := array_append(v_topo_resolved, v_cascade_role);
        v_topo_progress := true;
      END LOOP;

      IF NOT v_topo_progress THEN EXIT; END IF;
    END LOOP;

    FOR v_topo_item IN SELECT * FROM jsonb_array_elements(v_topo_all)
    LOOP
      v_cascade_role := v_topo_item->>'role';
      IF NOT (v_cascade_role = ANY(v_topo_resolved)) THEN
        IF (v_topo_item->>'axis') = 'height'
           OR v_cascade_role IN ('side_channel','chain','belt','brush') THEN
          v_cascade_base := v_height_mm;
        ELSE
          v_cascade_base := v_width_mm;
        END IF;
        v_cascade_base := v_cascade_base + (v_topo_item->>'tol')::numeric;
        v_resolved_cuts := v_resolved_cuts || jsonb_build_object(v_cascade_role, v_cascade_base);
      END IF;
    END LOOP;
  END IF;

  -- ===== BOM components (with condition filtering, per_spacing, per_joint, per_panel) =====
  IF p_bom_template_id IS NOT NULL THEN
    FOR v_comp IN
      SELECT bc.id, bc.component_role, bc.component_item_id,
             bc.qty_type, bc.qty_value, bc.qty_delta_mm,
             bc.qty_spacing_mm, bc.qty_min,
             bc.uom, bc.parent_component_id, bc.sort_order,
             bc.per_panel, bc.condition_key, bc.condition_value,
             bc.is_required
      FROM public."BOMComponents" bc
      WHERE bc.bom_template_id = p_bom_template_id
        AND bc.organization_id = p_org_id
        AND bc.deleted = false AND bc.archived = false
        AND bc.parent_component_id IS NULL
      ORDER BY bc.sort_order ASC
    LOOP
      v_cond_key := NULLIF(TRIM(COALESCE(v_comp.condition_key, '')), '');
      IF v_cond_key IS NOT NULL THEN
        v_cond_val := COALESCE(v_comp.condition_value, '');
        IF v_cond_key = 'motor_item_id' THEN
          SELECT COALESCE(NULLIF(TRIM(ci.selection_code), ''), ci.sku, '') INTO v_config_val
          FROM public."CatalogItems" ci
          WHERE ci.id = public.try_parse_uuid(v_config->>'motor_item_id')
            AND ci.organization_id = p_org_id
          LIMIT 1;
          IF v_config_val IS NULL THEN v_config_val := ''; END IF;
        ELSE
          v_config_val := COALESCE(v_config->>v_cond_key, '');
        END IF;
        IF v_config_val != v_cond_val THEN
          CONTINUE;
        END IF;
      END IF;

      IF lower(COALESCE(v_comp.component_role, '')) LIKE 'intermediate%'
         AND v_panel_count <= 1 THEN
        CONTINUE;
      END IF;

      v_selected := false;
      DECLARE
        v_role_lower text := lower(COALESCE(v_comp.component_role, ''));
        v_selected_id uuid;
        v_config_inner jsonb := COALESCE(v_cp.config_snapshot, '{}'::jsonb);
      BEGIN
        CASE v_role_lower
          WHEN 'bottom_bar'     THEN v_selected_id := public.try_parse_uuid(v_config_inner->>'bottom_bar_item_id');
          WHEN 'headbox'        THEN v_selected_id := public.try_parse_uuid(v_config_inner->>'headbox_item_id');
          WHEN 'side_channel'   THEN v_selected_id := public.try_parse_uuid(v_config_inner->>'side_channel_item_id');
          WHEN 'bottom_channel' THEN v_selected_id := public.try_parse_uuid(v_config_inner->>'bottom_channel_item_id');
          WHEN 'motor'          THEN v_selected_id := public.try_parse_uuid(v_config_inner->>'motor_item_id');
          WHEN 'drive'          THEN v_selected_id := public.try_parse_uuid(v_config_inner->>'drive_item_id');
          WHEN 'tube'           THEN v_selected_id := public.try_parse_uuid(v_config_inner->>'tube_item_id');
          WHEN 'track'          THEN v_selected_id := public.try_parse_uuid(v_config_inner->>'track_item_id');
          ELSE v_selected_id := NULL;
        END CASE;
        IF v_selected_id IS NOT NULL THEN
          v_comp.component_item_id := v_selected_id;
          v_selected := true;
        END IF;

        IF NOT v_selected AND COALESCE(v_comp.is_required, true) = false
           AND v_role_lower IN ('side_channel','bottom_channel','headbox','bottom_bar','motor','drive','tube','track')
        THEN
          CONTINUE;
        END IF;
      END;

      IF v_comp.component_item_id IS NULL THEN CONTINUE; END IF;

      SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
      FROM public."CatalogItems" ci
      WHERE ci.id = v_comp.component_item_id AND ci.organization_id = p_org_id
      LIMIT 1;
      v_parent_sku := v_item_info.sku;
      v_parent_name := v_item_info.name;
      v_parent_uom := v_item_info.unit_of_measure;

      SELECT cim.msrp, cim.total_cost INTO v_msrp_info
      FROM public."CatalogItemsMSRP" cim
      WHERE cim.catalog_item_id = v_comp.component_item_id AND cim.organization_id = p_org_id
      ORDER BY cim.updated_at DESC NULLS LAST
      LIMIT 1;

      v_qty := COALESCE(v_comp.qty_value, 1);
      DECLARE
        v_eff_width numeric;
        v_eff_height numeric;
        v_comp_role_lc text := lower(COALESCE(v_comp.component_role, ''));
      BEGIN
        IF v_resolved_cuts ? v_comp_role_lc THEN
          v_eff_width := (v_resolved_cuts->>v_comp_role_lc)::numeric;
          v_eff_height := (v_resolved_cuts->>v_comp_role_lc)::numeric;
        ELSE
          v_eff_width := v_width_mm + COALESCE(v_comp.qty_delta_mm, 0);
          v_eff_height := v_height_mm + COALESCE(v_comp.qty_delta_mm, 0);
        END IF;
      CASE COALESCE(v_comp.qty_type, 'fixed')
        WHEN 'per_width', 'width' THEN
          v_qty := GREATEST(0, v_eff_width / 1000.0)
                   * COALESCE(v_comp.qty_value, 1);
        WHEN 'per_height', 'height' THEN
          v_qty := GREATEST(0, v_eff_height / 1000.0)
                   * COALESCE(v_comp.qty_value, 1);
        WHEN 'per_m2', 'area' THEN
          v_qty := GREATEST(0, v_area_m2)
                   * COALESCE(v_comp.qty_value, 1);
        WHEN 'per_spacing' THEN
          v_qty := CEIL(
            GREATEST(0, v_eff_width)
            / GREATEST(v_comp.qty_spacing_mm::numeric, 1)
          ) * COALESCE(v_comp.qty_value, 1);
          IF v_comp.qty_min IS NOT NULL AND v_qty < v_comp.qty_min THEN
            v_qty := v_comp.qty_min;
          END IF;
        WHEN 'per_joint' THEN
          v_qty := GREATEST(0, v_panel_count - 1) * COALESCE(v_comp.qty_value, 1);
        ELSE
          v_qty := COALESCE(v_comp.qty_value, 1);
      END CASE;
      END;

      IF COALESCE(v_comp.per_panel, false) AND v_panel_count > 1
         AND COALESCE(v_comp.qty_type, 'fixed') = 'fixed' THEN
        IF lower(COALESCE(v_comp.component_role,'')) LIKE 'intermediate%' THEN
          v_qty := v_qty * GREATEST(1, v_panel_count - 1);
        ELSE
          v_qty := v_qty * v_panel_count;
        END IF;
      END IF;

      v_unit_price := COALESCE(v_msrp_info.msrp, 0);
      v_line_total := ROUND(v_qty * v_unit_price, 2);
      v_comp_unit_cost := COALESCE(v_msrp_info.total_cost, 0);
      v_comp_cost_total := ROUND(v_qty * v_comp_unit_cost, 4);
      v_bom_cost_sum := v_bom_cost_sum + v_comp_cost_total;

      v_children := '[]'::jsonb;
      FOR v_child IN
        SELECT bc.id, bc.component_role, bc.component_item_id,
               bc.qty_type, bc.qty_value, bc.qty_delta_mm,
               bc.qty_spacing_mm, bc.qty_min,
               bc.uom, bc.per_panel,
               bc.condition_key, bc.condition_value
        FROM public."BOMComponents" bc
        WHERE bc.parent_component_id = v_comp.id
          AND bc.organization_id = p_org_id
          AND bc.deleted = false AND bc.archived = false
        ORDER BY bc.sort_order ASC
      LOOP
        v_cond_key := NULLIF(TRIM(COALESCE(v_child.condition_key, '')), '');
        IF v_cond_key IS NOT NULL THEN
          v_cond_val := COALESCE(v_child.condition_value, '');
          IF v_cond_key = 'motor_item_id' THEN
            SELECT COALESCE(NULLIF(TRIM(ci.selection_code), ''), ci.sku, '') INTO v_config_val
            FROM public."CatalogItems" ci
            WHERE ci.id = public.try_parse_uuid(v_config->>'motor_item_id')
              AND ci.organization_id = p_org_id
            LIMIT 1;
            IF v_config_val IS NULL THEN v_config_val := ''; END IF;
          ELSE
            v_config_val := COALESCE(v_config->>v_cond_key, '');
          END IF;
          IF v_config_val != v_cond_val THEN
            CONTINUE;
          END IF;
        END IF;

        IF lower(COALESCE(v_child.component_role, '')) LIKE 'intermediate%'
           AND v_panel_count <= 1 THEN
          CONTINUE;
        END IF;

        IF v_child.component_item_id IS NULL THEN CONTINUE; END IF;

        SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
        FROM public."CatalogItems" ci
        WHERE ci.id = v_child.component_item_id AND ci.organization_id = p_org_id
        LIMIT 1;

        SELECT cim.msrp, cim.total_cost INTO v_msrp_info
        FROM public."CatalogItemsMSRP" cim
        WHERE cim.catalog_item_id = v_child.component_item_id AND cim.organization_id = p_org_id
        ORDER BY cim.updated_at DESC NULLS LAST
        LIMIT 1;

        DECLARE
          v_child_qty numeric;
          v_child_cost_unit numeric;
          v_child_cost_total numeric;
        BEGIN
          v_child_qty := COALESCE(v_child.qty_value, 1);
          CASE COALESCE(v_child.qty_type, 'fixed')
            WHEN 'per_width', 'width' THEN
              v_child_qty := GREATEST(0, (v_width_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0)
                             * COALESCE(v_child.qty_value, 1);
            WHEN 'per_height', 'height' THEN
              v_child_qty := GREATEST(0, (v_height_mm + COALESCE(v_child.qty_delta_mm, 0)) / 1000.0)
                             * COALESCE(v_child.qty_value, 1);
            WHEN 'per_m2', 'area' THEN
              v_child_qty := GREATEST(0, v_area_m2)
                             * COALESCE(v_child.qty_value, 1);
            WHEN 'per_spacing' THEN
              v_child_qty := CEIL(
                GREATEST(0, v_width_mm + COALESCE(v_child.qty_delta_mm, 0))
                / GREATEST(v_child.qty_spacing_mm::numeric, 1)
              ) * COALESCE(v_child.qty_value, 1);
              IF v_child.qty_min IS NOT NULL AND v_child_qty < v_child.qty_min THEN
                v_child_qty := v_child.qty_min;
              END IF;
            WHEN 'per_joint' THEN
              v_child_qty := GREATEST(0, v_panel_count - 1) * COALESCE(v_child.qty_value, 1);
            ELSE
              v_child_qty := COALESCE(v_child.qty_value, 1);
          END CASE;

          IF COALESCE(v_child.per_panel, false) AND v_panel_count > 1
             AND COALESCE(v_child.qty_type, 'fixed') = 'fixed' THEN
            IF lower(COALESCE(v_child.component_role,'')) LIKE 'intermediate%'
               OR lower(COALESCE(v_comp.component_role,'')) LIKE 'intermediate%' THEN
              v_child_qty := v_child_qty * GREATEST(1, v_panel_count - 1);
            ELSE
              v_child_qty := v_child_qty * v_panel_count;
            END IF;
          END IF;

          v_child_unit_price := COALESCE(v_msrp_info.msrp, 0);
          v_child_line_total := ROUND(v_child_qty * v_child_unit_price, 2);
          v_child_cost_unit := COALESCE(v_msrp_info.total_cost, 0);
          v_child_cost_total := ROUND(v_child_qty * v_child_cost_unit, 4);
          v_bom_cost_sum := v_bom_cost_sum + v_child_cost_total;
          v_children := v_children || jsonb_build_object(
            'id', v_child.id::text, 'kind', 'child', 'role', COALESCE(v_child.component_role, 'child'),
            'level', 1, 'selected', false, 'catalog_item_id', v_child.component_item_id,
            'sku', v_item_info.sku, 'name', v_item_info.name,
            'qty', ROUND(v_child_qty, 3),
            'uom', COALESCE(v_child.uom, v_item_info.unit_of_measure, 'ea'),
            'unit_price', v_child_unit_price, 'line_total', v_child_line_total,
            'unit_cost', v_child_cost_unit, 'cost_total', v_child_cost_total,
            'children', '[]'::jsonb,
            'meta', jsonb_build_object(
              'condition_key', v_child.condition_key,
              'condition_value', v_child.condition_value,
              'per_panel', COALESCE(v_child.per_panel, false)
            )
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
        'unit_cost', v_comp_unit_cost, 'cost_total', v_comp_cost_total,
        'children', v_children,
        'meta', jsonb_build_object(
          'condition_key', v_comp.condition_key,
          'condition_value', v_comp.condition_value,
          'per_panel', COALESCE(v_comp.per_panel, false)
        )
      );
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

  v_labor_amount := COALESCE(v_cp.labor_amount, 0);
  v_accessories_total := COALESCE(v_cp.accessories_total, 0);
  IF v_labor_amount = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_amount := (v_roll_msrp_total + v_bom_sum) * (v_cp.labor_pct / 100.0);
  END IF;
  v_total_msrp := v_roll_msrp_total + v_bom_sum + v_labor_amount + v_accessories_total;

  v_totals := jsonb_build_object(
    'roll_qty', v_roll_qty,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_sum,
    'accessories_total', v_accessories_total,
    'labor_pct', COALESCE(v_cp.labor_pct, 0),
    'labor_amount', v_labor_amount,
    'total_msrp', v_total_msrp,
    'roll_total_cost', COALESCE(v_roll_total_cost, 0) * GREATEST(v_roll_factor, 0),
    'bom_total_cost', v_bom_cost_sum,
    'accessories_total_cost', 0,
    'fabric_calc', COALESCE(v_fabric_calc, '{"source":"none"}'::jsonb),
    'panel_count', v_panel_count,
    'resolved_cuts', v_resolved_cuts
  );

  RETURN jsonb_build_object(
    'version', '3',
    'product_type_id', v_cp.product_type_id,
    'bom_template_id', p_bom_template_id,
    'price_basis', 'msrp',
    'currency', 'USD',
    'totals', v_totals,
    'items', v_items
  );
END;
$function$;

COMMIT;
