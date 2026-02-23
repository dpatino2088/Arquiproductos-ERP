-- Migration: Update SQL functions to use new cost column names (no _landed)
-- Depends on: 20260219_pricing_remove_landed_columns.sql
-- bom_preview_snapshot.totals and all returns use: roll_total_cost, bom_total_cost,
-- accessories_total_cost, unit_product_cost, total_cost.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) build_bom_preview_snapshot
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.build_bom_preview_snapshot(
  p_org_id uuid,
  p_configured_product_id uuid,
  p_bom_template_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
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
    v_cp.width_mm,
    0
  );
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_width_m := v_width_mm / 1000.0;
  v_height_m := v_height_mm / 1000.0;
  v_area_m2 := v_width_m * v_height_m;
  v_width_total_m := v_width_m;

  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT r.msrp, r.dealer_price, r.labor_msrp
    INTO v_roll_msrp_unit, v_roll_dealer_unit, v_roll_labor_unit
    FROM public.get_roll_pricing(p_org_id, v_cp.roll_catalog_item_id) r;

    SELECT ci.sku, ci.name, ci.unit_of_measure,
           ci.roll_pricing_mode, ci.measure_basis,
           COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_catalog
    INTO v_item_info
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
      AND ci.organization_id = p_org_id
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

    SELECT cim.total_cost INTO v_roll_total_cost
    FROM public."CatalogItemsMSRP" cim
    WHERE cim.catalog_item_id = v_cp.roll_catalog_item_id
      AND cim.organization_id = p_org_id
    ORDER BY cim.updated_at DESC NULLS LAST
    LIMIT 1;

    v_roll_item := jsonb_build_object(
      'id', COALESCE(v_cp.roll_catalog_item_id::text, 'roll:' || COALESCE(v_cp.roll_sku, 'unknown')),
      'kind', 'roll',
      'role', 'fabric',
      'level', 0,
      'selected', true,
      'catalog_item_id', v_cp.roll_catalog_item_id,
      'sku', v_cp.roll_sku,
      'name', COALESCE(v_cp.roll_variant_name, v_item_info.name, v_cp.roll_sku),
      'qty', ROUND(v_qty, 3),
      'uom', 'm²',
      'unit_price', v_unit_price,
      'line_total', v_line_total,
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
        AND bc.deleted = false
        AND bc.archived = false
        AND bc.parent_component_id IS NULL
      ORDER BY bc.sort_order ASC
    LOOP
      v_selected := false;
      DECLARE
        v_role_lower text := lower(COALESCE(v_comp.component_role, ''));
        v_selected_id uuid;
        v_config jsonb := COALESCE(v_cp.config_snapshot, '{}'::jsonb);
      BEGIN
        CASE v_role_lower
          WHEN 'bottom_bar'     THEN v_selected_id := public.try_parse_uuid(v_config->>'bottom_bar_item_id');
          WHEN 'headbox'        THEN v_selected_id := public.try_parse_uuid(v_config->>'headbox_item_id');
          WHEN 'side_channel'   THEN v_selected_id := public.try_parse_uuid(v_config->>'side_channel_item_id');
          WHEN 'bottom_channel' THEN v_selected_id := public.try_parse_uuid(v_config->>'bottom_channel_item_id');
          WHEN 'motor'          THEN v_selected_id := public.try_parse_uuid(v_config->>'motor_item_id');
          WHEN 'drive'          THEN v_selected_id := public.try_parse_uuid(v_config->>'drive_item_id');
          WHEN 'tube'           THEN v_selected_id := public.try_parse_uuid(v_config->>'tube_item_id');
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
      WHERE ci.id = v_comp.component_item_id AND ci.organization_id = p_org_id
      LIMIT 1;

      SELECT cim.msrp, cim.total_cost INTO v_msrp_info
      FROM public."CatalogItemsMSRP" cim
      WHERE cim.catalog_item_id = v_comp.component_item_id AND cim.organization_id = p_org_id
      ORDER BY cim.updated_at DESC NULLS LAST
      LIMIT 1;

      v_qty := COALESCE(v_comp.qty_value, 1);
      CASE COALESCE(v_comp.qty_type, 'fixed')
        WHEN 'per_width', 'width' THEN v_qty := GREATEST(0, (v_width_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_height', 'height' THEN v_qty := GREATEST(0, (v_height_mm + COALESCE(v_comp.qty_delta_mm, 0)) / 1000.0);
        WHEN 'per_m2', 'area' THEN v_qty := GREATEST(0, v_area_m2);
        ELSE v_qty := COALESCE(v_comp.qty_value, 1);
      END CASE;

      v_unit_price := COALESCE(v_msrp_info.msrp, 0);
      v_line_total := ROUND(v_qty * v_unit_price, 2);

      v_children := '[]'::jsonb;
      FOR v_child IN
        SELECT bc.id, bc.component_role, bc.component_item_id, bc.qty_type, bc.qty_value, bc.qty_delta_mm, bc.uom
        FROM public."BOMComponents" bc
        WHERE bc.parent_component_id = v_comp.id
          AND bc.organization_id = p_org_id
          AND bc.deleted = false
          AND bc.archived = false
        ORDER BY bc.sort_order ASC
      LOOP
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

  v_labor_amount := COALESCE(v_cp.labor_amount, 0);
  v_accessories_total := COALESCE(v_cp.accessories_total, 0);
  IF v_labor_amount = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_amount := (v_roll_msrp_total + v_bom_sum) * (v_cp.labor_pct / 100.0);
  END IF;
  v_total_msrp := v_roll_msrp_total + v_bom_sum + v_labor_amount + v_accessories_total;

  -- totals: NO *_landed keys
  v_totals := jsonb_build_object(
    'roll_qty', v_roll_qty,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_sum,
    'accessories_total', v_accessories_total,
    'labor_pct', COALESCE(v_cp.labor_pct, 0),
    'labor_amount', v_labor_amount,
    'total_msrp', v_total_msrp,
    'roll_total_cost', COALESCE(v_roll_total_cost, v_cp.roll_total_cost, 0),
    'bom_total_cost', COALESCE(v_cp.bom_total_cost, 0)
  );

  RETURN jsonb_build_object('version', '1', 'product_type_id', v_cp.product_type_id, 'bom_template_id', p_bom_template_id,
    'price_basis', 'msrp', 'currency', 'USD', 'totals', v_totals, 'items', v_items);
END;
$$;

COMMENT ON FUNCTION public.build_bom_preview_snapshot(uuid, uuid, uuid) IS
'BOM preview JSONB. Costs from CatalogItemsMSRP. totals use roll_total_cost, bom_total_cost, unit_product_cost, total_cost (no _landed).';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) calculate_configured_product_totals
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.calculate_configured_product_totals(p_configured_product_id uuid) RETURNS jsonb
LANGUAGE plpgsql
AS $_$
DECLARE
  v_cp RECORD;
  v_snapshot jsonb;
  v_snapshot_totals jsonb;
  v_acc jsonb;
  v_roll RECORD;
  v_roll_factor numeric := 0;
  v_roll_msrp_total numeric := 0;
  v_roll_dealer_total numeric := 0;
  v_bom_total numeric := 0;
  v_accessories_total numeric := 0;
  v_labor_msrp numeric := 0;
  v_msrp_product_subtotal numeric := 0;
  v_unit_msrp_total numeric := 0;
  v_unit_dealer_price numeric := 0;
  v_item_id uuid;
  v_item_qty numeric;
  v_item_msrp numeric;
  v_item_cost numeric;
  v_roll_total_cost numeric := 0;
  v_bom_total_cost numeric := 0;
  v_accessories_total_cost numeric := 0;
  v_unit_product_cost numeric := 0;
  v_unit_labor_cost numeric := 0;
  v_total_cost numeric := 0;
BEGIN
  SELECT * INTO v_cp FROM public."ConfiguredProducts" WHERE id = p_configured_product_id AND deleted = false;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'ConfiguredProduct not found'); END IF;

  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := COALESCE(v_snapshot->'totals', '{}'::jsonb);

  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT r.msrp, r.dealer_price, r.labor_msrp INTO v_roll
    FROM public.get_roll_pricing(v_cp.organization_id, v_cp.roll_catalog_item_id) r;
    IF FOUND THEN
      DECLARE v_roll_pricing_mode text; v_roll_measure_basis text; v_qty_from_json numeric;
      BEGIN
        SELECT ci.roll_pricing_mode, ci.measure_basis INTO v_roll_pricing_mode, v_roll_measure_basis
        FROM public."CatalogItems" ci WHERE ci.id = v_cp.roll_catalog_item_id LIMIT 1;
        IF v_roll_pricing_mode = 'per_unit' THEN v_roll_factor := 1;
        ELSIF v_roll_pricing_mode = 'per_linear_meter' OR v_roll_measure_basis = 'linear' THEN
          v_roll_factor := COALESCE(v_cp.height_mm, 0) / 1000.0;
        ELSE v_roll_factor := COALESCE(v_cp.roll_width, 0) * (COALESCE(v_cp.height_mm, 0) / 1000.0); END IF;
        v_qty_from_json := (v_snapshot_totals->>'roll_qty')::numeric;
        IF COALESCE(v_roll_factor, 0) = 0 AND v_qty_from_json IS NULL THEN v_roll_factor := 1;
        ELSIF v_qty_from_json IS NOT NULL AND v_qty_from_json > 0 THEN v_roll_factor := v_qty_from_json; END IF;
        v_roll_msrp_total := COALESCE(v_roll.msrp, 0) * GREATEST(v_roll_factor, 0);
        v_roll_dealer_total := COALESCE(v_roll.dealer_price, 0) * GREATEST(v_roll_factor, 0);
        v_labor_msrp := COALESCE(v_roll.labor_msrp, 0);
      END;
    END IF;
  END IF;

  v_bom_total := COALESCE((v_snapshot_totals->>'bom_total')::numeric, v_cp.bom_total, 0);
  v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);
  v_msrp_product_subtotal := v_roll_msrp_total;
  IF v_labor_msrp = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_msrp := (v_roll_msrp_total + v_bom_total + v_accessories_total)
      * CASE WHEN v_cp.labor_pct <= 1 THEN v_cp.labor_pct ELSE (v_cp.labor_pct / 100.0) END;
  END IF;
  v_unit_msrp_total := v_roll_msrp_total + v_labor_msrp + v_bom_total + v_accessories_total;
  v_unit_dealer_price := v_roll_dealer_total + v_bom_total + v_accessories_total + v_labor_msrp;
  IF v_unit_dealer_price = 0 THEN v_unit_dealer_price := v_unit_msrp_total; END IF;

  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    DECLARE v_roll_pricing_mode text; v_roll_measure_basis text;
    BEGIN
      SELECT ci.roll_pricing_mode, ci.measure_basis INTO v_roll_pricing_mode, v_roll_measure_basis
      FROM public."CatalogItems" ci WHERE ci.id = v_cp.roll_catalog_item_id LIMIT 1;
      IF v_roll_pricing_mode = 'per_unit' THEN v_roll_factor := 1;
      ELSIF v_roll_pricing_mode = 'per_linear_meter' OR v_roll_measure_basis = 'linear' THEN
        v_roll_factor := COALESCE(v_cp.height_mm, 0) / 1000.0;
      ELSE v_roll_factor := COALESCE(v_cp.roll_width, 0) * (COALESCE(v_cp.height_mm, 0) / 1000.0); END IF;
      IF COALESCE(v_roll_factor, 0) = 0 THEN v_roll_factor := 1; END IF;
      SELECT unit_msrp, unit_cost INTO v_item_msrp, v_item_cost
      FROM public.resolve_catalog_item_landed_price_cost(v_cp.organization_id, v_cp.roll_catalog_item_id);
      v_roll_total_cost := COALESCE(v_item_cost, 0) * COALESCE(v_roll_factor, 0);
    END;
  END IF;

  IF v_roll_total_cost = 0 THEN
    v_roll_total_cost := COALESCE((v_snapshot_totals->>'roll_total_cost')::numeric, 0);
  END IF;

  v_bom_total_cost := COALESCE((v_snapshot_totals->>'bom_total_cost')::numeric, 0);

  IF jsonb_typeof(v_cp.config_snapshot->'accessories') = 'array' THEN
    FOR v_acc IN SELECT value FROM jsonb_array_elements(v_cp.config_snapshot->'accessories')
    LOOP
      v_item_qty := GREATEST(COALESCE((v_acc->>'qty')::numeric, 0), 0);
      v_item_id := CASE
        WHEN COALESCE(v_acc->>'id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (v_acc->>'id')::uuid
        WHEN COALESCE(v_acc->>'catalog_item_id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN (v_acc->>'catalog_item_id')::uuid
        ELSE NULL END;
      IF v_item_id IS NOT NULL THEN
        SELECT unit_msrp, unit_cost INTO v_item_msrp, v_item_cost
        FROM public.resolve_catalog_item_landed_price_cost(v_cp.organization_id, v_item_id);
      ELSE v_item_cost := 0; END IF;
      v_accessories_total_cost := v_accessories_total_cost + (v_item_qty * COALESCE(v_item_cost, 0));
    END LOOP;
  ELSE
    v_accessories_total_cost := COALESCE((v_snapshot_totals->>'accessories_total_cost')::numeric, 0);
  END IF;

  v_unit_product_cost := v_roll_total_cost + v_bom_total_cost + v_accessories_total_cost;
  v_unit_labor_cost := COALESCE(v_cp.unit_labor_cost, 0);
  v_total_cost := v_unit_product_cost + v_unit_labor_cost;

  UPDATE public."ConfiguredProducts"
  SET
    roll_msrp_total = v_roll_msrp_total, bom_total = v_bom_total, accessories_total = v_accessories_total,
    labor_amount = v_labor_msrp, total_msrp = v_unit_msrp_total, msrp_product_subtotal = v_msrp_product_subtotal,
    labor_msrp = v_labor_msrp, unit_msrp_total = v_unit_msrp_total,
    roll_total_cost = v_roll_total_cost, bom_total_cost = v_bom_total_cost,
    accessories_total_cost = v_accessories_total_cost, unit_product_cost = v_unit_product_cost,
    unit_labor_cost = v_unit_labor_cost, total_cost = v_total_cost,
    bom_preview_snapshot = jsonb_set(
      COALESCE(v_snapshot, '{}'::jsonb), '{totals}',
      jsonb_build_object(
        'roll_qty', (v_snapshot_totals->>'roll_qty')::numeric,
        'roll_msrp_total', v_roll_msrp_total, 'roll_dealer_total', v_roll_dealer_total,
        'bom_total', v_bom_total, 'accessories_total', v_accessories_total,
        'labor_pct', COALESCE(v_cp.labor_pct, (v_snapshot_totals->>'labor_pct')::numeric, 0),
        'labor_amount', v_labor_msrp, 'total_msrp', v_unit_msrp_total,
        'msrp_product_subtotal', v_msrp_product_subtotal, 'labor_msrp', v_labor_msrp,
        'unit_msrp_total', v_unit_msrp_total, 'unit_dealer_price', v_unit_dealer_price,
        'roll_total_cost', v_roll_total_cost, 'bom_total_cost', v_bom_total_cost,
        'accessories_total_cost', v_accessories_total_cost,
        'unit_product_cost', v_unit_product_cost, 'unit_labor_cost', v_unit_labor_cost,
        'total_cost', v_total_cost
      ), true
    ),
    updated_at = now()
  WHERE id = p_configured_product_id;

  RETURN jsonb_build_object('configured_product_id', p_configured_product_id, 'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_total, 'total_msrp', v_unit_msrp_total, 'unit_msrp_total', v_unit_msrp_total,
    'unit_dealer_price', v_unit_dealer_price, 'total_cost', v_total_cost);
END;
$_$;

COMMENT ON FUNCTION public.calculate_configured_product_totals(uuid) IS
'Totals from CatalogItemsMSRP. Writes roll_total_cost, bom_total_cost, unit_product_cost, total_cost (no _landed).';

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) create_configured_product_and_bom_preview
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_configured_product_and_bom_preview(
  p_org_id uuid, p_product_type_id uuid, p_config_snapshot jsonb,
  p_quote_id uuid DEFAULT NULL, p_quote_line_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_configured_product_id uuid; v_bom_template_id uuid; v_preview_snapshot jsonb; v_totals_after jsonb;
  v_hardware_color text; v_fabric_item_id uuid; v_width_mm numeric(12,4); v_height_mm numeric(12,4); v_quantity numeric(12,4);
  v_roll_sku text; v_roll_collection_name text; v_roll_variant_name text; v_roll_width numeric(12,4); v_labor_pct numeric(12,4);
BEGIN
  PERFORM public.reject_oneoff_keys(p_config_snapshot);
  SELECT COALESCE(cs.labor_pct, 0) INTO v_labor_pct FROM public."CostSettings" cs WHERE cs.organization_id = p_org_id LIMIT 1;
  IF v_labor_pct IS NULL THEN v_labor_pct := 0; END IF;

  v_bom_template_id := (p_config_snapshot->>'bom_template_id')::uuid;
  IF v_bom_template_id IS NULL THEN
    BEGIN
      SELECT public.select_best_bom_template_v2_strict(p_org_id, p_product_type_id, p_config_snapshot) INTO v_bom_template_id;
    EXCEPTION WHEN OTHERS THEN v_bom_template_id := NULL; END;
  END IF;
  IF v_bom_template_id IS NULL THEN
    RAISE EXCEPTION 'No matching BOMTemplate found for product_type_id=% with config=%', p_product_type_id, p_config_snapshot::text;
  END IF;

  v_hardware_color := COALESCE(p_config_snapshot->>'hardware_color', p_config_snapshot->>'hardwareColor');
  v_fabric_item_id := (p_config_snapshot->>'variantId')::uuid;
  IF v_fabric_item_id IS NULL THEN v_fabric_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid; END IF;
  v_width_mm := COALESCE((p_config_snapshot->'measurements'->>'width_total_mm')::numeric(12,4), (p_config_snapshot->>'width_mm')::numeric(12,4));
  v_height_mm := (p_config_snapshot->>'height_mm')::numeric(12,4);
  v_quantity := COALESCE((p_config_snapshot->>'quantity')::numeric(12,4), 1);

  IF v_fabric_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.collection_name, ci.variant_name, ci.roll_width
    INTO v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width
    FROM public."CatalogItems" ci WHERE ci.id = v_fabric_item_id AND ci.organization_id = p_org_id LIMIT 1;
  END IF;

  INSERT INTO public."ConfiguredProducts" (
    organization_id, quote_id, bom_template_id, product_type_id, width_mm, height_mm, quantity, hardware_color,
    roll_catalog_item_id, roll_sku, roll_collection_name, roll_variant_name, roll_width, config_snapshot, labor_pct,
    roll_msrp_total, bom_total, accessories_total, total_msrp
  ) VALUES (
    p_org_id, p_quote_id, v_bom_template_id, p_product_type_id, v_width_mm, v_height_mm, v_quantity, v_hardware_color,
    v_fabric_item_id, v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width, p_config_snapshot, v_labor_pct,
    0, 0, 0, 0
  )
  RETURNING id INTO v_configured_product_id;

  v_preview_snapshot := public.build_bom_preview_snapshot(p_org_id, v_configured_product_id, v_bom_template_id);
  UPDATE public."ConfiguredProducts" SET bom_preview_snapshot = v_preview_snapshot, updated_at = now()
  WHERE id = v_configured_product_id AND organization_id = p_org_id;

  PERFORM public.calculate_configured_product_totals(v_configured_product_id);

  SELECT jsonb_build_object(
    'roll_msrp_total', cp.roll_msrp_total, 'bom_total', cp.bom_total, 'accessories_total', cp.accessories_total,
    'labor_amount', cp.labor_amount, 'total_msrp', cp.total_msrp, 'msrp_product_subtotal', cp.msrp_product_subtotal,
    'labor_msrp', cp.labor_msrp, 'unit_msrp_total', cp.unit_msrp_total,
    'roll_total_cost', cp.roll_total_cost, 'bom_total_cost', cp.bom_total_cost,
    'accessories_total_cost', cp.accessories_total_cost, 'unit_product_cost', cp.unit_product_cost,
    'unit_labor_cost', cp.unit_labor_cost, 'total_cost', cp.total_cost
  ) INTO v_totals_after
  FROM public."ConfiguredProducts" cp WHERE cp.id = v_configured_product_id;

  SELECT bom_preview_snapshot INTO v_preview_snapshot FROM public."ConfiguredProducts" WHERE id = v_configured_product_id;

  RETURN jsonb_build_object('configured_product_id', v_configured_product_id, 'bom_instance_id', NULL,
    'bom_template_id', v_bom_template_id, 'totals', v_totals_after, 'bom_preview_snapshot', v_preview_snapshot);
END;
$$;

COMMENT ON FUNCTION public.create_configured_product_and_bom_preview(uuid, uuid, jsonb, uuid, uuid) IS
'Creates ConfiguredProduct. Totals use roll_total_cost, bom_total_cost, unit_product_cost, total_cost (no _landed).';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4) sync_quote_line_pricing_from_configured_product
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_quote_line_pricing_from_configured_product(p_quote_line_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_ql RECORD; v_cp RECORD; v_totals jsonb; v_qty numeric(12,4); v_unit_msrp numeric(12,4); v_unit_cost numeric(12,4);
  v_dealer_tier_id uuid; v_dealer_tier_code text; v_discount_pct numeric(5,2); v_unit_dealer_price numeric(12,4);
  v_catalog_dealer_unit numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required'; END IF;

  SELECT ql.id, ql.organization_id, ql.configured_product_id, ql.quantity, ql.pricing_locked, ql.quote_id
  INTO v_ql FROM public."QuoteLines" ql WHERE ql.id = p_quote_line_id;
  IF v_ql.id IS NULL THEN RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id; END IF;
  IF v_ql.configured_product_id IS NULL THEN RETURN; END IF;
  IF COALESCE(v_ql.pricing_locked, false) = true THEN RETURN; END IF;

  PERFORM public.calculate_configured_product_totals(v_ql.configured_product_id);

  SELECT * INTO v_cp FROM public."ConfiguredProducts"
  WHERE id = v_ql.configured_product_id AND organization_id = v_ql.organization_id AND deleted = false;
  IF v_cp.id IS NULL THEN RAISE EXCEPTION 'ConfiguredProduct % not found for QuoteLine %', v_ql.configured_product_id, p_quote_line_id; END IF;

  v_totals := COALESCE(v_cp.bom_preview_snapshot->'totals', '{}'::jsonb);
  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);

  v_unit_msrp := COALESCE(v_cp.total_msrp, (v_totals->>'total_msrp')::numeric, 0);
  v_unit_cost := COALESCE(v_cp.unit_product_cost, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  IF v_unit_cost = 0 THEN
    v_unit_cost := COALESCE((v_totals->>'total_cost')::numeric,
      COALESCE(v_cp.roll_total_cost, 0) + COALESCE(v_cp.bom_total_cost, 0) + COALESCE(v_cp.accessories_total_cost, 0) + COALESCE(v_cp.unit_labor_cost, 0), 0);
  END IF;

  SELECT d.dealer_tier_id, dt.code, COALESCE(dt.discount_pct, 35)
  INTO v_dealer_tier_id, v_dealer_tier_code, v_discount_pct
  FROM public."Quotes" q JOIN public."Dealers" d ON d.id = q.dealer_id
  LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
  WHERE q.id = v_ql.quote_id LIMIT 1;
  IF v_discount_pct IS NULL THEN v_discount_pct := 35; END IF;

  v_unit_dealer_price := ROUND(v_unit_msrp * (1 - v_discount_pct / 100.0), 4);

  SELECT cim.dealer_price INTO v_catalog_dealer_unit
  FROM public."CatalogItemsMSRP" cim
  WHERE cim.organization_id = v_ql.organization_id AND cim.catalog_item_id = v_cp.roll_catalog_item_id
  ORDER BY cim.updated_at DESC NULLS LAST LIMIT 1;

  PERFORM set_config('app.write_source', 'rpc', true);

  UPDATE public."QuoteLines" SET
    roll_msrp_snapshot = COALESCE(v_cp.roll_msrp_total, (v_totals->>'roll_msrp_total')::numeric, 0),
    bom_msrp_snapshot = COALESCE(v_cp.bom_total, (v_totals->>'bom_total')::numeric, 0),
    roll_cost_snapshot = COALESCE(v_cp.roll_total_cost, (v_totals->>'roll_total_cost')::numeric, 0),
    bom_cost_snapshot = COALESCE(v_cp.bom_total_cost, (v_totals->>'bom_total_cost')::numeric, 0),
    unit_msrp_total_snapshot = v_unit_msrp, unit_cost_total_snapshot = v_unit_cost,
    msrp = ROUND(v_unit_msrp * v_qty, 2), total_cost = ROUND(v_unit_cost * v_qty, 2),
    unit_dealer_price_snapshot = v_unit_dealer_price, dealer_price_total = ROUND(v_unit_dealer_price * v_qty, 2),
    dealer_discount_pct = v_discount_pct, dealer_tier_id_snapshot = v_dealer_tier_id,
    dealer_tier_code_snapshot = v_dealer_tier_code, catalog_dealer_unit_snapshot = v_catalog_dealer_unit,
    dealer_price_source = 'tier', last_priced_at = now(),
    pricing_version = COALESCE(pricing_version, 0) + 1, pricing_locked = true
  WHERE id = p_quote_line_id AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.sync_quote_line_pricing_from_configured_product(uuid) IS
'Refreshes QuoteLine pricing from ConfiguredProduct. Uses roll_total_cost, bom_total_cost, unit_product_cost, total_cost (no _landed).';
