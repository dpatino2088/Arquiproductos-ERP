-- ============================================================================
-- 2026-03-29: Pricing Single Source of Truth
-- ============================================================================
-- Purpose: Make ConfiguredProducts the single source of truth for pricing.
-- Rules:
--   - Snapshot totals are UNIT (no product quantity multiplication)
--   - calculate_configured_product_totals is the ONLY pricing ladder engine
--   - QuoteLines commit/sync only COPY from CP (no recalculation)
--   - No references to labor_cost_pct (column removed)
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1) build_bom_preview_snapshot: UNIT totals (no v_cp.quantity multiplier)
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

  -- Interconnected panels: each panel needs its own fabric cut
  v_panel_count := GREATEST(
    COALESCE((v_config->'measurements'->>'panel_count')::integer, 0),
    COALESCE(jsonb_array_length(v_config->'measurements'->'panels'), 0),
    COALESCE(jsonb_array_length(v_config->'panels'), 0),
    1
  );

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

    -- Interconnected: multiply roll factor by panel count (each panel needs its own fabric)
    v_roll_factor := v_roll_factor * v_panel_count;

    -- UNIT totals: do NOT multiply by v_cp.quantity
    v_roll_qty := GREATEST(v_roll_factor, 0);
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

    -- UNIT: roll cost = cost_per_unit * roll_factor (no product quantity)
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
             bc.qty_delta_mm, bc.uom, bc.parent_component_id, bc.sort_order
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
        ELSE v_qty := COALESCE(v_comp.qty_value, 1);
      END CASE;

      v_unit_price := COALESCE(v_msrp_info.msrp, 0);
      v_line_total := ROUND(v_qty * v_unit_price, 2);
      v_bom_cost_from_items := v_bom_cost_from_items + (v_qty * COALESCE(v_msrp_info.total_cost, 0));

      -- FIX: save parent item info BEFORE children loop overwrites v_item_info
      DECLARE
        v_parent_sku text := v_item_info.sku;
        v_parent_name text := v_item_info.name;
        v_parent_uom text := v_item_info.unit_of_measure;
      BEGIN

      v_children := '[]'::jsonb;
      FOR v_child IN
        SELECT bc.id, bc.component_role, bc.component_item_id, bc.qty_type, bc.qty_value, bc.qty_delta_mm, bc.uom
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

      -- Use saved parent info (not v_item_info which was overwritten by last child)
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

  -- All totals are UNIT (no product quantity multiplication)
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
    'dealer_price_total', 0
  );

  RETURN jsonb_build_object('version', '1', 'product_type_id', v_cp.product_type_id, 'bom_template_id', p_bom_template_id,
    'price_basis', 'msrp', 'currency', 'USD', 'totals', v_totals, 'items', v_items);
END;
$$;

COMMENT ON FUNCTION public.build_bom_preview_snapshot(uuid, uuid, uuid) IS
'BOM preview JSONB. Totals are UNIT (no product quantity). Uses labor_pct only.';


-- ============================================================================
-- 2) calculate_configured_product_totals: ONLY pricing ladder engine (UNIT)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.calculate_configured_product_totals(
  p_configured_product_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
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

  -- Rebuild snapshot when cost data missing AND has bom_template_id
  IF ((v_totals->>'roll_total_cost') IS NULL OR (v_totals->>'bom_total_cost') IS NULL)
     AND v_cp.bom_template_id IS NOT NULL THEN
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

  -- MSRP subtotals (snapshot totals are already UNIT)
  v_roll_msrp_total := COALESCE((v_totals->>'roll_msrp_total')::numeric, v_cp.roll_msrp_total, 0);
  v_bom_total := COALESCE((v_totals->>'bom_total')::numeric, v_cp.bom_total, 0);
  v_accessories_total := COALESCE((v_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);

  -- Cost subtotals (snapshot totals are already UNIT)
  v_roll_cost := COALESCE((v_totals->>'roll_total_cost')::numeric, v_cp.roll_total_cost, 0);
  v_bom_cost := COALESCE((v_totals->>'bom_total_cost')::numeric, v_cp.bom_total_cost, 0);
  v_accessories_cost := COALESCE((v_totals->>'accessories_total_cost')::numeric, v_cp.accessories_total_cost, 0);

  -- Defensive: legacy snapshot may have multiplied roll by qty; normalize
  IF v_qty > 1 AND (v_roll_cost > 0 OR v_roll_msrp_total > 0) THEN
    IF (v_totals->>'legacy_qty_multiplied') = 'true' THEN
      v_roll_cost := v_roll_cost / v_qty;
      v_roll_msrp_total := v_roll_msrp_total / v_qty;
    END IF;
  END IF;

  v_msrp_product_subtotal := v_roll_msrp_total + v_bom_total + v_accessories_total;

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
  v_labor_cost := ROUND(v_materials_cost * v_labor_pct, 4);
  v_total_cost := ROUND(v_materials_cost + v_labor_cost, 4);

  v_unit_dealer_price := ROUND(v_total_cost / v_dealer_factor, 4);
  v_unit_msrp_total := ROUND(v_unit_dealer_price / v_msrp_factor, 4);
  v_dealer_price_total_unit := v_unit_dealer_price;
  v_msrp_total := ROUND(v_unit_msrp_total * v_qty, 4);

  v_labor_msrp := ROUND(GREATEST(0, v_unit_msrp_total - v_msrp_product_subtotal), 4);

  -- Update snapshot totals with unit_dealer_price and dealer_price_total (UNIT)
  v_totals := jsonb_set(v_totals, '{unit_dealer_price}', to_jsonb(v_unit_dealer_price), true);
  v_totals := jsonb_set(v_totals, '{dealer_price_total}', to_jsonb(v_dealer_price_total_unit), true);

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
    'minimum_margin_pct', v_minimum_margin_pct,
    'msrp_margin_pct', v_msrp_margin_pct
  );
END;
$$;

COMMENT ON FUNCTION public.calculate_configured_product_totals(uuid) IS
'Pricing ladder: COST -> DEALER -> MSRP. Rebuilds snapshot when cost data missing. All values UNIT.';


-- ============================================================================
-- 3) commit_configured_product_to_quote_line: COPY ONLY (no recalculation)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.commit_configured_product_to_quote_line(
  p_org_id uuid,
  p_quote_id uuid,
  p_configured_product_id uuid,
  p_dealer_id uuid DEFAULT NULL,
  p_position text DEFAULT NULL,
  p_area text DEFAULT NULL,
  p_fabric_drop text DEFAULT NULL,
  p_installation_type text DEFAULT NULL,
  p_installation_location text DEFAULT NULL
) RETURNS TABLE(quote_line_id uuid, bom_instance_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public'
AS $$
DECLARE
  v_cp RECORD;
  v_roll_item RECORD;
  v_quote_line_id uuid;
  v_bom_instance_id uuid;
  v_width_m numeric(12,4);
  v_height_m numeric(12,4);
  v_line_quantity numeric(12,4);
  v_operating_type text;
  v_product_type_code text;
  v_effective_dealer_id uuid;
  v_dealer_tier_id uuid;
  v_dealer_tier_code text;
  v_unit_dealer numeric(12,4);
  v_totals jsonb;
  v_installation_type text;
  v_installation_location text;
BEGIN
  IF p_org_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_org_id is required'; END IF;
  IF p_quote_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_quote_id is required'; END IF;
  IF p_configured_product_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_configured_product_id is required'; END IF;

  PERFORM public.calculate_configured_product_totals(p_configured_product_id);

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found or does not belong to org %', p_configured_product_id, p_org_id;
  END IF;

  v_totals := COALESCE(v_cp.bom_preview_snapshot->'totals', '{}'::jsonb);
  v_line_quantity := GREATEST(COALESCE(v_cp.quantity, 1), 1);
  v_width_m := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m := COALESCE(v_cp.height_mm / 1000.0, 0);
  v_operating_type := COALESCE(
    v_cp.config_snapshot->>'operating_type',
    v_cp.config_snapshot->>'drive_type',
    v_cp.config_snapshot->>'operation_type'
  );
  v_installation_type := COALESCE(p_installation_type, v_cp.config_snapshot->>'installationType');
  v_installation_location := COALESCE(p_installation_location, v_cp.config_snapshot->>'installationLocation');

  -- unit_dealer_price from snapshot; fallback to total_cost/(1-min_margin) if missing
  v_unit_dealer := COALESCE(
    nullif((v_totals->>'unit_dealer_price')::numeric, 0),
    CASE
      WHEN (1 - COALESCE((SELECT cs.minimum_margin_pct FROM public."CostSettings" cs
            WHERE cs.organization_id = v_cp.organization_id AND COALESCE(cs.is_active, true)
            ORDER BY cs.created_at DESC LIMIT 1), 0.35)) > 0.01
      THEN v_cp.total_cost / (1 - COALESCE((SELECT cs.minimum_margin_pct FROM public."CostSettings" cs
            WHERE cs.organization_id = v_cp.organization_id AND COALESCE(cs.is_active, true)
            ORDER BY cs.created_at DESC LIMIT 1), 0.35))
      ELSE 0
    END
  );

  v_effective_dealer_id := COALESCE(
    p_dealer_id,
    (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)
  );

  SELECT d.dealer_tier_id, dt.code
  INTO v_dealer_tier_id, v_dealer_tier_code
  FROM public."Dealers" d
  LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
  WHERE d.id = v_effective_dealer_id
  LIMIT 1;

  SELECT pt.code INTO v_product_type_code
  FROM public."ProductTypes" pt
  WHERE pt.id = v_cp.product_type_id LIMIT 1;

  SELECT ci.sku, ci.name, ci.category_id, ci.manufacturer_id, m.name AS manufacturer_name,
         ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_m
  INTO v_roll_item
  FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id AND ci.is_active = true
  LIMIT 1;

  PERFORM set_config('app.write_source', 'rpc', true);

  -- COPY ONLY: all values from ConfiguredProducts; multiply by qty for line totals
  INSERT INTO public."QuoteLines" (
    organization_id, quote_id, dealer_id,
    configured_product_id, bom_template_id,
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer,
    collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity,
    hardware_color, drive_type, position, area, fabric_drop,
    installation_type, installation_location,
    roll_msrp_snapshot, bom_msrp_snapshot, labor_msrp_snapshot,
    roll_cost_snapshot, bom_cost_snapshot, labor_cost_snapshot,
    unit_msrp_total_snapshot, unit_cost_total_snapshot,
    unit_dealer_price_snapshot,
    msrp, total_cost, dealer_price_total,
    dealer_discount_pct, dealer_tier_id_snapshot, dealer_tier_code_snapshot,
    catalog_dealer_unit_snapshot, dealer_price_source,
    pricing_locked, last_priced_at, pricing_version,
    product_type, product_type_id
  )
  VALUES (
    p_org_id, p_quote_id, v_effective_dealer_id,
    v_cp.id, v_cp.bom_template_id,
    v_cp.roll_catalog_item_id,
    COALESCE(v_cp.roll_sku, v_roll_item.sku), v_roll_item.name,
    v_roll_item.category_id, v_roll_item.manufacturer_id, v_roll_item.manufacturer_name,
    COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name),
    COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name),
    v_cp.roll_catalog_item_id IS NOT NULL,
    CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END,
    COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    v_width_m, v_height_m, v_line_quantity,
    v_cp.hardware_color, v_operating_type, p_position, p_area,
    COALESCE(p_fabric_drop, v_cp.config_snapshot->>'fabricDrop', v_cp.config_snapshot->>'drop_type'),
    v_installation_type, v_installation_location,
    COALESCE(v_cp.roll_msrp_total, 0), COALESCE(v_cp.bom_total, 0), COALESCE(v_cp.labor_amount, 0),
    COALESCE((v_totals->>'roll_total_cost')::numeric, v_cp.roll_total_cost, 0),
    COALESCE((v_totals->>'bom_total_cost')::numeric, v_cp.bom_total_cost, 0),
    COALESCE(v_cp.unit_labor_cost, 0),
    COALESCE(v_cp.total_msrp, 0),
    COALESCE(v_cp.total_cost, 0),
    v_unit_dealer,
    ROUND(COALESCE(v_cp.total_msrp, 0) * v_line_quantity, 2),
    ROUND(COALESCE(v_cp.total_cost, 0) * v_line_quantity, 2),
    ROUND(v_unit_dealer * v_line_quantity, 2),
    COALESCE((SELECT COALESCE(dt.discount_pct, 35) FROM public."Dealers" d
      LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id WHERE d.id = v_effective_dealer_id LIMIT 1), 35),
    v_dealer_tier_id, v_dealer_tier_code,
    (SELECT cim.dealer_price FROM public."CatalogItemsMSRP" cim
      WHERE cim.organization_id = p_org_id AND cim.catalog_item_id = v_cp.roll_catalog_item_id
      ORDER BY cim.updated_at DESC NULLS LAST LIMIT 1),
    'tier',
    true, now(), 1,
    v_product_type_code, v_cp.product_type_id
  )
  RETURNING id INTO v_quote_line_id;

  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;

COMMENT ON FUNCTION public.commit_configured_product_to_quote_line(uuid, uuid, uuid, uuid, text, text, text, text, text) IS
'Creates QuoteLine from ConfiguredProduct. COPY only from CP - no pricing recalculation. Uses unit values * qty for line totals.';


-- ============================================================================
-- 4) sync_quote_line_pricing_from_configured_product: COPY ONLY + p_force
-- ============================================================================
CREATE OR REPLACE FUNCTION public.sync_quote_line_pricing_from_configured_product(
  p_quote_line_id uuid,
  p_force boolean DEFAULT false
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_ql RECORD;
  v_cp RECORD;
  v_totals jsonb;
  v_qty numeric(12,4);
  v_unit_dealer numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required';
  END IF;

  SELECT ql.id, ql.organization_id, ql.configured_product_id, ql.quantity, ql.pricing_locked
  INTO v_ql
  FROM public."QuoteLines" ql
  WHERE ql.id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;
  IF v_ql.configured_product_id IS NULL THEN RETURN; END IF;

  IF COALESCE(v_ql.pricing_locked, false) = true AND NOT p_force THEN
    RETURN;
  END IF;

  PERFORM public.calculate_configured_product_totals(v_ql.configured_product_id);

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = v_ql.configured_product_id
    AND organization_id = v_ql.organization_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found for QuoteLine %', v_ql.configured_product_id, p_quote_line_id;
  END IF;

  v_totals := COALESCE(v_cp.bom_preview_snapshot->'totals', '{}'::jsonb);
  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);

  v_unit_dealer := COALESCE(
    nullif((v_totals->>'unit_dealer_price')::numeric, 0),
    CASE
      WHEN (1 - COALESCE((SELECT cs.minimum_margin_pct FROM public."CostSettings" cs
            WHERE cs.organization_id = v_cp.organization_id AND COALESCE(cs.is_active, true)
            ORDER BY cs.created_at DESC LIMIT 1), 0.35)) > 0.01
      THEN v_cp.total_cost / (1 - COALESCE((SELECT cs.minimum_margin_pct FROM public."CostSettings" cs
            WHERE cs.organization_id = v_cp.organization_id AND COALESCE(cs.is_active, true)
            ORDER BY cs.created_at DESC LIMIT 1), 0.35))
      ELSE 0
    END
  );

  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);
  PERFORM set_config('app.write_source', 'rpc', true);

  -- COPY ONLY: from ConfiguredProducts; use QuoteLine quantity for line totals
  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot         = COALESCE(v_cp.roll_msrp_total, 0),
    bom_msrp_snapshot          = COALESCE(v_cp.bom_total, 0),
    labor_msrp_snapshot        = COALESCE(v_cp.labor_amount, 0),
    roll_cost_snapshot         = COALESCE((v_totals->>'roll_total_cost')::numeric, v_cp.roll_total_cost, 0),
    bom_cost_snapshot          = COALESCE((v_totals->>'bom_total_cost')::numeric, v_cp.bom_total_cost, 0),
    labor_cost_snapshot        = COALESCE(v_cp.unit_labor_cost, 0),
    unit_msrp_total_snapshot   = COALESCE(v_cp.total_msrp, 0),
    unit_cost_total_snapshot   = COALESCE(v_cp.total_cost, 0),
    unit_dealer_price_snapshot = v_unit_dealer,
    msrp                       = ROUND(COALESCE(v_cp.total_msrp, 0) * v_qty, 2),
    total_cost                 = ROUND(COALESCE(v_cp.total_cost, 0) * v_qty, 2),
    dealer_price_total         = ROUND(v_unit_dealer * v_qty, 2),
    last_priced_at             = now(),
    pricing_version            = COALESCE(pricing_version, 0) + 1
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.sync_quote_line_pricing_from_configured_product(uuid, boolean) IS
'Refreshes QuoteLine pricing from ConfiguredProduct. COPY only. p_force=true ignores pricing_locked.';


-- ============================================================================
-- 5) Fix create_configured_product_and_bom_preview: remove _landed column refs
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_configured_product_and_bom_preview(
  p_org_id          uuid,
  p_product_type_id uuid,
  p_config_snapshot jsonb,
  p_quote_id        uuid DEFAULT NULL,
  p_quote_line_id   uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_configured_product_id uuid;
  v_bom_template_id       uuid;
  v_preview_snapshot      jsonb;
  v_totals_after          jsonb;
  v_hardware_color        text;
  v_fabric_item_id        uuid;
  v_width_mm              numeric(12,4);
  v_height_mm             numeric(12,4);
  v_quantity              numeric(12,4);
  v_roll_sku              text;
  v_roll_collection_name  text;
  v_roll_variant_name     text;
  v_roll_width            numeric(12,4);
  v_labor_pct             numeric(12,4);
BEGIN
  PERFORM public.reject_oneoff_keys(p_config_snapshot);

  SELECT COALESCE(cs.labor_pct, 0)
  INTO v_labor_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_org_id
  LIMIT 1;

  IF v_labor_pct IS NULL THEN v_labor_pct := 0; END IF;

  v_bom_template_id := (p_config_snapshot->>'bom_template_id')::uuid;

  IF v_bom_template_id IS NULL THEN
    BEGIN
      SELECT public.select_best_bom_template_v2_strict(
        p_org_id,
        p_product_type_id,
        p_config_snapshot
      ) INTO v_bom_template_id;
    EXCEPTION WHEN OTHERS THEN
      v_bom_template_id := NULL;
    END;
  END IF;

  IF v_bom_template_id IS NULL THEN
    RAISE EXCEPTION 'No matching BOMTemplate found for product_type_id=% with config=%',
      p_product_type_id, p_config_snapshot::text;
  END IF;

  v_hardware_color := COALESCE(
    p_config_snapshot->>'hardware_color',
    p_config_snapshot->>'hardwareColor'
  );

  v_fabric_item_id := (p_config_snapshot->>'variantId')::uuid;
  IF v_fabric_item_id IS NULL THEN
    v_fabric_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid;
  END IF;

  v_width_mm := COALESCE(
    (p_config_snapshot->'measurements'->>'width_total_mm')::numeric(12,4),
    (p_config_snapshot->>'width_mm')::numeric(12,4)
  );
  v_height_mm  := (p_config_snapshot->>'height_mm')::numeric(12,4);
  v_quantity   := COALESCE((p_config_snapshot->>'quantity')::numeric(12,4), 1);

  IF v_fabric_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.collection_name, ci.variant_name, ci.roll_width
    INTO v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width
    FROM public."CatalogItems" ci
    WHERE ci.id = v_fabric_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;
  END IF;

  INSERT INTO public."ConfiguredProducts" (
    organization_id, quote_id, bom_template_id, product_type_id,
    width_mm, height_mm, quantity, hardware_color,
    roll_catalog_item_id, roll_sku, roll_collection_name, roll_variant_name, roll_width,
    config_snapshot, labor_pct,
    roll_msrp_total, bom_total, accessories_total, total_msrp
  )
  VALUES (
    p_org_id, p_quote_id, v_bom_template_id, p_product_type_id,
    v_width_mm, v_height_mm, v_quantity, v_hardware_color,
    v_fabric_item_id, v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width,
    p_config_snapshot, v_labor_pct,
    0, 0, 0, 0
  )
  RETURNING id INTO v_configured_product_id;

  v_preview_snapshot := public.build_bom_preview_snapshot(
    p_org_id, v_configured_product_id, v_bom_template_id
  );

  UPDATE public."ConfiguredProducts"
  SET bom_preview_snapshot = v_preview_snapshot, updated_at = now()
  WHERE id = v_configured_product_id AND organization_id = p_org_id;

  PERFORM public.calculate_configured_product_totals(v_configured_product_id);

  SELECT
    jsonb_build_object(
      'roll_msrp_total',           cp.roll_msrp_total,
      'bom_total',                 cp.bom_total,
      'accessories_total',         cp.accessories_total,
      'labor_amount',              cp.labor_amount,
      'total_msrp',                cp.total_msrp,
      'msrp_product_subtotal',     cp.msrp_product_subtotal,
      'labor_msrp',                cp.labor_msrp,
      'unit_msrp_total',           cp.unit_msrp_total,
      'roll_total_cost',           cp.roll_total_cost,
      'bom_total_cost',            cp.bom_total_cost,
      'accessories_total_cost',    cp.accessories_total_cost,
      'unit_product_cost',         cp.unit_product_cost,
      'unit_labor_cost',           cp.unit_labor_cost,
      'total_cost',                cp.total_cost
    )
  INTO v_totals_after
  FROM public."ConfiguredProducts" cp
  WHERE cp.id = v_configured_product_id;

  SELECT bom_preview_snapshot
  INTO v_preview_snapshot
  FROM public."ConfiguredProducts"
  WHERE id = v_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id', v_configured_product_id,
    'bom_instance_id',       NULL,
    'bom_template_id',       v_bom_template_id,
    'totals',                v_totals_after,
    'bom_preview_snapshot',  v_preview_snapshot
  );
END;
$$;

COMMENT ON FUNCTION public.create_configured_product_and_bom_preview(uuid, uuid, jsonb, uuid, uuid) IS
'Creates ConfiguredProduct + BOM snapshot + pricing totals. No _landed column references.';

GRANT EXECUTE ON FUNCTION public.create_configured_product_and_bom_preview(uuid, uuid, jsonb, uuid, uuid)
  TO authenticated, service_role, anon;


COMMIT;
