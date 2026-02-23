-- ============================================================================
-- 2026-03-28
-- FIX: Two root causes for $0 pricing on new QuoteLines:
--
-- 1) build_bom_preview_snapshot references cs.labor_cost_pct which does NOT
--    exist in CostSettings (migration 20260320 never applied). This causes
--    the function to fail when called, producing an empty snapshot.
--
-- 2) calculate_configured_product_totals lost the logic to rebuild the
--    snapshot when cost data is missing (removed in 20260326/27).
--
-- Fix: update BOTH functions.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1) FIX build_bom_preview_snapshot: remove cs.labor_cost_pct reference
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
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  -- FIX: use labor_pct only (labor_cost_pct column does not exist)
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

    v_roll_qty := GREATEST(v_roll_factor, 0) * COALESCE(v_cp.quantity, 1);
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

    SELECT cim.total_cost INTO v_roll_total_cost
    FROM public."CatalogItemsMSRP" cim
    WHERE cim.catalog_item_id = v_cp.roll_catalog_item_id AND cim.organization_id = p_org_id
    ORDER BY cim.updated_at DESC NULLS LAST LIMIT 1;

    v_roll_total_cost := COALESCE(v_roll_total_cost, 0) * COALESCE(v_roll_qty, 0);

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

      v_items := v_items || jsonb_build_object(
        'id', v_comp.id::text, 'kind', 'parent', 'role', COALESCE(v_comp.component_role, 'component'),
        'level', 0, 'selected', v_selected, 'catalog_item_id', v_comp.component_item_id,
        'sku', v_item_info.sku, 'name', v_item_info.name,
        'qty', ROUND(v_qty, 3),
        'uom', COALESCE(v_comp.uom, v_item_info.unit_of_measure, 'ea'),
        'unit_price', v_unit_price, 'line_total', v_line_total,
        'children', v_children, 'meta', '{}'::jsonb
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
    'msrp_product_subtotal', v_msrp_product_subtotal
  );

  RETURN jsonb_build_object('version', '1', 'product_type_id', v_cp.product_type_id, 'bom_template_id', p_bom_template_id,
    'price_basis', 'msrp', 'currency', 'USD', 'totals', v_totals, 'items', v_items);
END;
$$;

COMMENT ON FUNCTION public.build_bom_preview_snapshot(uuid, uuid, uuid) IS
'BOM preview JSONB. Uses labor_pct only (labor_cost_pct removed). Fabric UOM from fabric_pricing_basis.';

-- ============================================================================
-- 2) FIX calculate_configured_product_totals: rebuild snapshot when missing
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
  v_dealer_price_total numeric := 0;
  v_msrp_total numeric := 0;
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  -- *** FIX: Rebuild snapshot when cost data is missing ***
  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_totals := COALESCE(v_snapshot->'totals', '{}'::jsonb);

  IF (v_totals->>'roll_total_cost') IS NULL
     AND (v_totals->>'bom_total_cost') IS NULL
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

  -- MSRP subtotals (prefer snapshot, fallback CP columns)
  -- NOTE: snapshot roll values include product_qty; normalize to per-unit.
  v_roll_msrp_total := COALESCE((v_totals->>'roll_msrp_total')::numeric, v_cp.roll_msrp_total, 0);
  v_bom_total := COALESCE((v_totals->>'bom_total')::numeric, v_cp.bom_total, 0);
  v_accessories_total := COALESCE((v_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);

  -- Cost subtotals (prefer snapshot, fallback CP columns)
  v_roll_cost := COALESCE((v_totals->>'roll_total_cost')::numeric, v_cp.roll_total_cost, 0);
  v_bom_cost := COALESCE((v_totals->>'bom_total_cost')::numeric, v_cp.bom_total_cost, 0);
  v_accessories_cost := COALESCE((v_totals->>'accessories_total_cost')::numeric, v_cp.accessories_total_cost, 0);

  -- FIX: build_bom_preview_snapshot bakes product_qty into roll costs/MSRP
  -- but NOT into BOM costs. Normalize roll to per-unit so the pricing ladder
  -- produces per-unit prices; commit/sync multiply by qty at the end.
  IF v_qty > 1 THEN
    v_roll_cost := v_roll_cost / v_qty;
    v_roll_msrp_total := v_roll_msrp_total / v_qty;
  END IF;

  v_msrp_product_subtotal := v_roll_msrp_total + v_bom_total + v_accessories_total;

  -- Cost inputs: labor_pct only
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

  -- Cost -> Dealer -> MSRP
  v_materials_cost := ROUND(v_roll_cost + v_bom_cost + v_accessories_cost, 4);
  v_labor_cost := ROUND(v_materials_cost * v_labor_pct, 4);
  v_total_cost := ROUND(v_materials_cost + v_labor_cost, 4);

  v_unit_dealer_price := ROUND(v_total_cost / v_dealer_factor, 4);
  v_unit_msrp_total := ROUND(v_unit_dealer_price / v_msrp_factor, 4);
  v_msrp_total := ROUND(v_unit_msrp_total * v_qty, 4);
  v_dealer_price_total := ROUND(v_unit_dealer_price * v_qty, 4);

  v_labor_msrp := ROUND(GREATEST(0, v_unit_msrp_total - v_msrp_product_subtotal), 4);

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
    bom_preview_snapshot = jsonb_set(
      COALESCE(v_snapshot, '{}'::jsonb),
      '{totals}',
      jsonb_build_object(
        'roll_msrp_total', v_roll_msrp_total,
        'bom_total', v_bom_total,
        'accessories_total', v_accessories_total,
        'msrp_product_subtotal', v_msrp_product_subtotal,
        'labor_amount', v_labor_msrp,
        'labor_msrp', v_labor_msrp,
        'unit_msrp', v_unit_msrp_total,
        'unit_msrp_total', v_unit_msrp_total,
        'total_msrp', v_unit_msrp_total,
        'msrp_total', v_msrp_total,
        'roll_cost', v_roll_cost,
        'roll_total_cost', v_roll_cost,
        'bom_cost', v_bom_cost,
        'bom_total_cost', v_bom_cost,
        'accessories_cost', v_accessories_cost,
        'accessories_total_cost', v_accessories_cost,
        'materials_cost', v_materials_cost,
        'unit_product_cost', v_materials_cost,
        'labor_cost', v_labor_cost,
        'unit_labor_cost', v_labor_cost,
        'total_cost', v_total_cost,
        'labor_pct', ROUND(v_labor_pct * 100, 4),
        'minimum_margin_pct', ROUND(v_minimum_margin_pct * 100, 4),
        'msrp_margin_pct', ROUND(v_msrp_margin_pct * 100, 4),
        'default_msrp_pct', ROUND(v_msrp_margin_pct * 100, 4),
        'unit_dealer_price', v_unit_dealer_price,
        'dealer_price_total', v_dealer_price_total
      ),
      true
    ),
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
    'dealer_price_total', v_dealer_price_total,
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
'Pricing ladder: COST -> DEALER -> MSRP. Rebuilds bom_preview_snapshot when cost data is missing. labor_pct only.';

COMMIT;
