-- Definitive build_bom_preview_snapshot
-- Restores features lost in successive rewrites:
--   1. condition_key/condition_value filtering (from 20260614)
--   2. per_spacing qty_type (from 20260614)
--   3. per_joint qty_type (never in build_bom_preview before)
--   4. per_panel multiplier (column existed, never used)
-- Also bumps version to '3'.

CREATE OR REPLACE FUNCTION public.build_bom_preview_snapshot(
  p_org_id uuid,
  p_configured_product_id uuid,
  p_bom_template_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
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
  -- New: condition filtering + panel count
  v_cond_key text;
  v_cond_val text;
  v_config_val text;
  v_panel_count integer;
  v_panels jsonb;
  v_parent_sku text;
  v_parent_name text;
  v_parent_uom text;
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

  -- Extract panel count from config_snapshot
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

  -- ===== ROLL pricing (unchanged) =====
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
      false,
      false,
      false
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
        'area_base_m2', v_consumption.area_base_m2
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
      -- Condition filtering: skip component if condition doesn't match config
      v_cond_key := NULLIF(TRIM(COALESCE(v_comp.condition_key, '')), '');
      IF v_cond_key IS NOT NULL THEN
        v_cond_val := COALESCE(v_comp.condition_value, '');
        v_config_val := COALESCE(v_config->>v_cond_key, '');
        IF v_config_val != v_cond_val THEN
          CONTINUE;
        END IF;
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

        -- Optional components (is_required=false): skip if user didn't select
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

      -- Qty calculation with all types
      v_qty := COALESCE(v_comp.qty_value, 1);
      CASE COALESCE(v_comp.qty_type, 'fixed')
        WHEN 'per_width', 'width' THEN
          v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0)
                   * COALESCE(v_comp.qty_value, 1);
        WHEN 'per_height', 'height' THEN
          v_qty := GREATEST(0, (v_height_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0)
                   * COALESCE(v_comp.qty_value, 1);
        WHEN 'per_m2', 'area' THEN
          v_qty := GREATEST(0, v_area_m2)
                   * COALESCE(v_comp.qty_value, 1);
        WHEN 'per_spacing' THEN
          v_qty := CEIL(
            GREATEST(0, v_width_mm + COALESCE(v_comp.qty_delta_mm, 0))
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

      -- per_panel multiplier
      IF COALESCE(v_comp.per_panel, false) AND v_panel_count > 1 THEN
        v_qty := v_qty * v_panel_count;
      END IF;

      v_unit_price := COALESCE(v_msrp_info.msrp, 0);
      v_line_total := ROUND(v_qty * v_unit_price, 2);
      v_comp_unit_cost := COALESCE(v_msrp_info.total_cost, 0);
      v_comp_cost_total := ROUND(v_qty * v_comp_unit_cost, 4);
      v_bom_cost_sum := v_bom_cost_sum + v_comp_cost_total;

      -- ===== Children =====
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
        -- Condition filtering for children
        v_cond_key := NULLIF(TRIM(COALESCE(v_child.condition_key, '')), '');
        IF v_cond_key IS NOT NULL THEN
          v_cond_val := COALESCE(v_child.condition_value, '');
          v_config_val := COALESCE(v_config->>v_cond_key, '');
          IF v_config_val != v_cond_val THEN
            CONTINUE;
          END IF;
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

          -- per_panel multiplier for children
          IF COALESCE(v_child.per_panel, false) AND v_panel_count > 1 THEN
            v_child_qty := v_child_qty * v_panel_count;
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
    'panel_count', v_panel_count
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
