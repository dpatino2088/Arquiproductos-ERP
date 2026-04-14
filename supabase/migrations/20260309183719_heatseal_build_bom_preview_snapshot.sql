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
  v_can_rotate boolean := false;
  v_is_weldable boolean := false;
  v_bottom_bar_wrapped boolean := false;
  v_cond_key text;
  v_cond_value text;
  v_config_val text;
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

  v_bottom_bar_wrapped := COALESCE(
    (v_config->>'bottom_bar_wrapped')::boolean,
    (v_config->>'bottom_rail_type') = 'wrapped',
    false
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
      SELECT rs.can_rotate, rs.is_weldable
      INTO v_can_rotate, v_is_weldable
      FROM public."CatalogItemRollSpecs" rs
      WHERE rs.catalog_item_id = v_cp.roll_catalog_item_id
        AND rs.organization_id = p_org_id
      LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v_can_rotate := false;
      v_is_weldable := false;
    END;

    BEGIN
      SELECT * INTO v_consumption
      FROM public.compute_fabric_pricing_from_rule(
        p_org_id, v_cp.product_type_id, NULL,
        v_height_m, v_width_m, v_roll_width_effective,
        COALESCE(v_roll_msrp_unit, 0),
        v_dim_outputs,
        COALESCE(v_can_rotate, false),
        COALESCE(v_is_weldable, false),
        v_bottom_bar_wrapped
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
        'panel_detail', v_consumption.panel_detail,
        'is_rotated', COALESCE(v_consumption.is_rotated, false),
        'heatseal_seams', COALESCE(v_consumption.heatseal_seams, 0),
        'heatseal_cost', COALESCE(v_consumption.heatseal_cost, 0),
        'bottom_bar_wrapped', v_bottom_bar_wrapped,
        'bottom_bar_wrap_cost', COALESCE(v_consumption.bottom_bar_wrap_cost, 0),
        'can_rotate', COALESCE(v_can_rotate, false),
        'is_weldable', COALESCE(v_is_weldable, false),
        'roll_width_m', v_roll_width_effective
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
             bc.parent_component_id, bc.sort_order,
             bc.condition_key, bc.condition_value
      FROM public."BOMComponents" bc
      WHERE bc.bom_template_id = p_bom_template_id
        AND bc.organization_id = p_org_id
        AND bc.deleted = false AND bc.archived = false
        AND bc.parent_component_id IS NULL
      ORDER BY bc.sort_order ASC
    LOOP
      v_cond_key := NULLIF(TRIM(COALESCE(v_comp.condition_key, '')), '');
      IF v_cond_key IS NOT NULL THEN
        v_cond_value := COALESCE(v_comp.condition_value, '');
        v_config_val := COALESCE(v_config->>v_cond_key, '');
        IF v_config_val != v_cond_value THEN
          CONTINUE;
        END IF;
      END IF;

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
               bc.qty_delta_mm, bc.qty_spacing_mm, bc.qty_min, bc.uom,
               bc.condition_key, bc.condition_value
        FROM public."BOMComponents" bc
        WHERE bc.parent_component_id = v_comp.id
          AND bc.organization_id = p_org_id AND bc.deleted = false AND bc.archived = false
        ORDER BY bc.sort_order ASC
      LOOP
        v_cond_key := NULLIF(TRIM(COALESCE(v_child.condition_key, '')), '');
        IF v_cond_key IS NOT NULL THEN
          v_cond_value := COALESCE(v_child.condition_value, '');
          v_config_val := COALESCE(v_config->>v_cond_key, '');
          IF v_config_val != v_cond_value THEN
            CONTINUE;
          END IF;
        END IF;

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
'BOM preview with consumption engine. Reads CatalogItemRollSpecs for can_rotate/is_weldable, '
'config_snapshot for bottom_bar_wrapped. Passes these to compute_fabric_pricing_from_rule for '
'auto-rotation, heat-seal costing, and bottom-bar-wrap surcharge. Applies condition_key/'
'condition_value filtering on BOM components. fabric_calc includes is_rotated, heatseal_seams, '
'heatseal_cost, bottom_bar_wrap_cost for full auditability.';

NOTIFY pgrst, 'reload schema';;
