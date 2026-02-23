-- ====================================================
-- Migration 20260320: CostSettings.labor_cost_pct + UI
-- ====================================================
-- 1) Agregar columna labor_cost_pct a CostSettings (mismo formato que labor_pct: 0.05 = 5%).
-- 2) Usar labor_cost_pct como base para labor_cost. Si NULL, fallback a labor_pct.
-- 3) labor_pct sigue usándose para MSRP (labor_amount); labor_cost_pct para costo (labor_cost).
-- ====================================================

BEGIN;

ALTER TABLE public."CostSettings"
  ADD COLUMN IF NOT EXISTS labor_cost_pct numeric(7,4) DEFAULT NULL;

COMMENT ON COLUMN public."CostSettings".labor_cost_pct IS
'Labor cost % (0.05 = 5%). Applied to materials cost (roll+bom+accessories). If NULL, falls back to labor_pct.';

-- ----------------------------------------------------------------------------
-- calculate_configured_product_totals: usar labor_cost_pct para labor_cost
-- ----------------------------------------------------------------------------
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
  v_labor_pct numeric := 0;
  v_labor_cost_pct numeric := 0;
  v_base_cost_for_labor numeric := 0;
  v_labor_dealer numeric := 0;
BEGIN
  SELECT * INTO v_cp FROM public."ConfiguredProducts" WHERE id = p_configured_product_id AND deleted = false;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'ConfiguredProduct not found'); END IF;

  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := COALESCE(v_snapshot->'totals', '{}'::jsonb);

  -- labor_pct (MSRP side): CP first, then CostSettings
  v_labor_pct := COALESCE(v_cp.labor_pct, (v_snapshot_totals->>'labor_pct')::numeric);
  IF v_labor_pct IS NULL THEN
    SELECT COALESCE(cs.labor_pct, 0) INTO v_labor_pct
    FROM public."CostSettings" cs
    WHERE cs.organization_id = v_cp.organization_id AND COALESCE(cs.is_active, true)
    ORDER BY cs.created_at DESC LIMIT 1;
  END IF;
  IF v_labor_pct IS NULL THEN v_labor_pct := 0; END IF;

  -- labor_cost_pct (cost side): CostSettings first, fallback to labor_pct
  SELECT COALESCE(cs.labor_cost_pct, cs.labor_pct, 0) INTO v_labor_cost_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = v_cp.organization_id AND COALESCE(cs.is_active, true)
  ORDER BY cs.created_at DESC LIMIT 1;
  IF v_labor_cost_pct IS NULL THEN v_labor_cost_pct := v_labor_pct; END IF;

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
  IF v_labor_msrp = 0 AND v_labor_pct > 0 THEN
    v_labor_msrp := (v_roll_msrp_total + v_bom_total + v_accessories_total)
      * CASE WHEN v_labor_pct <= 1 THEN v_labor_pct ELSE (v_labor_pct / 100.0) END;
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
    v_roll_total_cost := COALESCE((v_snapshot_totals->>'roll_total_cost')::numeric, v_cp.roll_total_cost, 0);
  END IF;

  v_bom_total_cost := COALESCE((v_snapshot_totals->>'bom_total_cost')::numeric, v_cp.bom_total_cost, 0);

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
    v_accessories_total_cost := COALESCE((v_snapshot_totals->>'accessories_total_cost')::numeric, v_cp.accessories_total_cost, 0);
  END IF;

  v_unit_product_cost := v_roll_total_cost + v_bom_total_cost + v_accessories_total_cost;

  -- labor_cost = base_cost_for_labor * labor_cost_pct (CostSettings.labor_cost_pct, fallback labor_pct)
  v_base_cost_for_labor := v_roll_total_cost + v_bom_total_cost + v_accessories_total_cost;
  v_unit_labor_cost := ROUND(
    v_base_cost_for_labor
    * CASE WHEN v_labor_cost_pct <= 1 THEN v_labor_cost_pct ELSE (v_labor_cost_pct / 100.0) END,
    4
  );
  v_total_cost := v_unit_product_cost + v_unit_labor_cost;

  -- labor_dealer_total: proporcional a unit_dealer_price/total_msrp (Option B)
  v_labor_dealer := CASE
    WHEN v_unit_msrp_total > 0 AND v_unit_dealer_price > 0
    THEN ROUND(v_labor_msrp * (v_unit_dealer_price / v_unit_msrp_total), 4)
    ELSE 0
  END;

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
        'labor_pct', v_labor_pct,
        'labor_cost_pct', CASE WHEN v_labor_cost_pct <= 1 THEN v_labor_cost_pct * 100 ELSE v_labor_cost_pct END,
        'labor_amount', v_labor_msrp,
        'labor_msrp_total', v_labor_msrp,
        'labor_cost', v_unit_labor_cost,
        'labor_dealer_total', v_labor_dealer,
        'total_msrp', v_unit_msrp_total,
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
    'unit_dealer_price', v_unit_dealer_price, 'total_cost', v_total_cost, 'labor_cost', v_unit_labor_cost);
END;
$_$;

COMMENT ON FUNCTION public.calculate_configured_product_totals(uuid) IS
'Totals from CatalogItemsMSRP. labor_cost uses CostSettings.labor_cost_pct (fallback labor_pct). Persists labor_cost, labor_cost_pct in bom_preview_snapshot.totals.';

-- ----------------------------------------------------------------------------
-- build_bom_preview_snapshot: usar labor_cost_pct para labor_cost
-- ----------------------------------------------------------------------------
-- (La función completa está en 20260319; aquí solo reemplazamos la lógica de labor_cost_pct)
-- Se necesita reemplazar la función entera porque build_bom_preview_snapshot
-- está definida en 20260319. Aquí aplicamos el cambio incremental.

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
  v_labor_pct numeric := 0;
  v_labor_cost_pct numeric := 0;
  v_base_cost numeric := 0;
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
  v_labor_pct := v_cp.labor_pct;
  IF v_labor_pct IS NULL THEN
    SELECT COALESCE(cs.labor_pct, 0) INTO v_labor_pct
    FROM public."CostSettings" cs
    WHERE cs.organization_id = p_org_id AND COALESCE(cs.is_active, true)
    ORDER BY cs.created_at DESC LIMIT 1;
  END IF;
  IF v_labor_pct IS NULL THEN v_labor_pct := 0; END IF;

  -- labor_cost_pct: CostSettings first, fallback to labor_pct
  SELECT COALESCE(cs.labor_cost_pct, cs.labor_pct, 0) INTO v_labor_cost_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = p_org_id AND COALESCE(cs.is_active, true)
  ORDER BY cs.created_at DESC LIMIT 1;
  IF v_labor_cost_pct IS NULL THEN v_labor_cost_pct := v_labor_pct; END IF;

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
    SELECT r.msrp, r.dealer_price, r.labor_msrp INTO v_roll_msrp_unit, v_roll_dealer_unit, v_roll_labor_unit
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
  IF v_labor_amount = 0 AND v_labor_pct > 0 THEN
    v_labor_amount := (v_roll_msrp_total + v_bom_sum) * CASE WHEN v_labor_pct <= 1 THEN v_labor_pct ELSE (v_labor_pct / 100.0) END;
  END IF;
  v_total_msrp := v_roll_msrp_total + v_bom_sum + v_labor_amount + v_accessories_total;

  -- labor_cost = base_cost * labor_cost_pct (CostSettings.labor_cost_pct, fallback labor_pct)
  v_bom_total_cost_val := COALESCE(v_cp.bom_total_cost, 0);
  v_base_cost := v_roll_total_cost + v_bom_total_cost_val + COALESCE(v_cp.accessories_total_cost, 0);
  v_labor_cost := ROUND(v_base_cost * CASE WHEN v_labor_cost_pct <= 1 THEN v_labor_cost_pct ELSE (v_labor_cost_pct / 100.0) END, 4);

  v_totals := jsonb_build_object(
    'roll_qty', v_roll_qty,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_sum,
    'accessories_total', v_accessories_total,
    'labor_pct', v_labor_pct,
    'labor_cost_pct', CASE WHEN v_labor_cost_pct <= 1 THEN v_labor_cost_pct * 100 ELSE v_labor_cost_pct END,
    'labor_amount', v_labor_amount,
    'labor_msrp_total', v_labor_amount,
    'labor_cost', v_labor_cost,
    'roll_total_cost', v_roll_total_cost,
    'bom_total_cost', v_bom_total_cost_val
  );

  RETURN jsonb_build_object('version', '1', 'product_type_id', v_cp.product_type_id, 'bom_template_id', p_bom_template_id,
    'price_basis', 'msrp', 'currency', 'USD', 'totals', v_totals, 'items', v_items);
END;
$$;

COMMENT ON FUNCTION public.build_bom_preview_snapshot(uuid, uuid, uuid) IS
'BOM preview JSONB. labor_cost uses CostSettings.labor_cost_pct (fallback labor_pct).';

COMMIT;
