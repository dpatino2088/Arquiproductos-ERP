-- ============================================================================
-- ConfiguredProducts: 1) Persistir totales desde bom_preview_snapshot (MSRP en 0)
--                    2) Leer headbox/side_channel/etc. desde config_snapshot (JSON)
--                    3) Eliminar columnas redundantes
-- Fecha: 2026-02-04
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1) build_bom_preview_snapshot: leer *_item_id desde config_snapshot (no columnas)
--    Así podremos eliminar las columnas; la info ya está en config_snapshot.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.build_bom_preview_snapshot(
  p_org_id uuid,
  p_configured_product_id uuid,
  p_bom_template_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_items jsonb := '[]'::jsonb;
  v_totals jsonb;
  v_comp RECORD;
  v_child RECORD;
  v_item_info RECORD;
  v_msrp_info RECORD;
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
BEGIN
  SELECT id, organization_id, product_type_id, bom_template_id, config_snapshot,
         width_mm, height_mm, quantity, roll_catalog_item_id, roll_sku, roll_collection_name,
         roll_variant_name, roll_width, roll_msrp_total, bom_total, labor_amount, labor_pct,
         accessories_total, roll_total_cost, bom_total_cost
  INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND organization_id = p_org_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  v_width_mm := COALESCE(v_cp.width_mm, 0);
  v_height_mm := COALESCE(v_cp.height_mm, 0);
  v_width_m := v_width_mm / 1000.0;
  v_height_m := v_height_mm / 1000.0;
  v_area_m2 := v_width_m * v_height_m;

  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id AND ci.organization_id = p_org_id LIMIT 1;
    SELECT msrp, total_cost INTO v_msrp_info
    FROM public."CatalogItemsMSRP"
    WHERE catalog_item_id = v_cp.roll_catalog_item_id AND organization_id = p_org_id LIMIT 1;
    v_qty := v_area_m2 * COALESCE(v_cp.quantity, 1);
    v_unit_price := COALESCE(v_msrp_info.msrp, 0);
    v_line_total := ROUND(v_qty * v_unit_price, 2);
    v_roll_item := jsonb_build_object(
      'id', COALESCE(v_cp.roll_catalog_item_id::text, 'roll:' || COALESCE(v_cp.roll_sku, 'unknown')),
      'kind', 'roll', 'role', 'fabric', 'level', 0, 'selected', true,
      'catalog_item_id', v_cp.roll_catalog_item_id, 'sku', v_cp.roll_sku,
      'name', COALESCE(v_cp.roll_variant_name, v_item_info.name, v_cp.roll_sku),
      'qty', ROUND(v_qty, 3), 'uom', 'm²', 'unit_price', v_unit_price, 'line_total', v_line_total,
      'children', '[]'::jsonb,
      'meta', jsonb_build_object('collection_name', v_cp.roll_collection_name, 'variant_name', v_cp.roll_variant_name, 'roll_width', v_cp.roll_width)
    );
    v_items := v_items || v_roll_item;
  END IF;

  IF p_bom_template_id IS NOT NULL THEN
    FOR v_comp IN
      SELECT bc.id, bc.component_role, bc.component_item_id, bc.qty_type, bc.qty_value, bc.qty_delta_mm, bc.uom, bc.parent_component_id, bc.sort_order
      FROM public."BOMComponents" bc
      WHERE bc.bom_template_id = p_bom_template_id AND bc.organization_id = p_org_id
        AND bc.deleted = false AND bc.archived = false AND bc.parent_component_id IS NULL
      ORDER BY bc.sort_order ASC
    LOOP
      v_selected := false;
      DECLARE
        v_role_lower text := lower(v_comp.component_role);
        v_selected_id uuid;
      BEGIN
        -- Leer desde config_snapshot (columnas headbox/side_channel/etc. se eliminan)
        CASE v_role_lower
          WHEN 'bottom_bar' THEN v_selected_id := (v_cp.config_snapshot->>'bottom_bar_item_id')::uuid;
          WHEN 'headbox' THEN v_selected_id := (v_cp.config_snapshot->>'headbox_item_id')::uuid;
          WHEN 'side_channel' THEN v_selected_id := (v_cp.config_snapshot->>'side_channel_item_id')::uuid;
          WHEN 'bottom_channel' THEN v_selected_id := (v_cp.config_snapshot->>'bottom_channel_item_id')::uuid;
          WHEN 'motor' THEN v_selected_id := (v_cp.config_snapshot->>'motor_item_id')::uuid;
          WHEN 'drive' THEN v_selected_id := (v_cp.config_snapshot->>'drive_item_id')::uuid;
          WHEN 'tube' THEN v_selected_id := (v_cp.config_snapshot->>'tube_item_id')::uuid;
          ELSE v_selected_id := NULL;
        END CASE;
        IF v_selected_id IS NOT NULL THEN
          v_comp.component_item_id := v_selected_id;
          v_selected := true;
        END IF;
      END;
      IF v_comp.component_item_id IS NULL THEN CONTINUE; END IF;
      SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
      FROM public."CatalogItems" ci WHERE ci.id = v_comp.component_item_id AND ci.organization_id = p_org_id LIMIT 1;
      SELECT msrp, total_cost INTO v_msrp_info
      FROM public."CatalogItemsMSRP" WHERE catalog_item_id = v_comp.component_item_id AND organization_id = p_org_id LIMIT 1;
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
        WHERE bc.parent_component_id = v_comp.id AND bc.organization_id = p_org_id AND bc.deleted = false AND bc.archived = false
        ORDER BY bc.sort_order ASC
      LOOP
        IF v_child.component_item_id IS NULL THEN CONTINUE; END IF;
        SELECT ci.sku, ci.name, ci.unit_of_measure INTO v_item_info
        FROM public."CatalogItems" ci WHERE ci.id = v_child.component_item_id AND ci.organization_id = p_org_id LIMIT 1;
        SELECT msrp, total_cost INTO v_msrp_info
        FROM public."CatalogItemsMSRP" WHERE catalog_item_id = v_child.component_item_id AND organization_id = p_org_id LIMIT 1;
        DECLARE
          v_child_qty numeric;
          v_child_unit_price numeric;
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
            'id', v_child.id::text, 'kind', 'child', 'role', COALESCE(v_child.component_role, 'child'), 'level', 1, 'selected', false,
            'catalog_item_id', v_child.component_item_id, 'sku', v_item_info.sku, 'name', v_item_info.name,
            'qty', ROUND(v_child_qty, 3), 'uom', COALESCE(v_child.uom, v_item_info.unit_of_measure, 'ea'),
            'unit_price', v_child_unit_price, 'line_total', v_child_line_total, 'children', '[]'::jsonb, 'meta', '{}'::jsonb
          );
        END;
      END LOOP;
      v_items := v_items || jsonb_build_object(
        'id', v_comp.id::text, 'kind', 'parent', 'role', COALESCE(v_comp.component_role, 'component'), 'level', 0, 'selected', v_selected,
        'catalog_item_id', v_comp.component_item_id, 'sku', v_item_info.sku, 'name', v_item_info.name,
        'qty', ROUND(v_qty, 3), 'uom', COALESCE(v_comp.uom, v_item_info.unit_of_measure, 'ea'),
        'unit_price', v_unit_price, 'line_total', v_line_total, 'children', v_children, 'meta', '{}'::jsonb
      );
    END LOOP;
  END IF;

  SELECT COALESCE(SUM((item->>'line_total')::numeric), 0) INTO v_roll_msrp_total
  FROM jsonb_array_elements(v_items) AS item WHERE item->>'kind' = 'roll';
  IF v_roll_msrp_total = 0 THEN v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0); END IF;
  SELECT COALESCE(SUM(
    (item->>'line_total')::numeric + COALESCE((SELECT SUM((c->>'line_total')::numeric) FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c), 0)
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
    'roll_msrp_total', v_roll_msrp_total, 'bom_total', v_bom_sum, 'accessories_total', v_accessories_total,
    'labor_pct', COALESCE(v_cp.labor_pct, 0), 'labor_amount', v_labor_amount, 'total_msrp', v_total_msrp,
    'roll_total_cost', COALESCE(v_cp.roll_total_cost, 0), 'bom_total_cost', COALESCE(v_cp.bom_total_cost, 0)
  );
  RETURN jsonb_build_object('version', '1', 'product_type_id', v_cp.product_type_id, 'bom_template_id', p_bom_template_id, 'price_basis', 'msrp', 'currency', 'USD', 'totals', v_totals, 'items', v_items);
END;
$$;

-- ----------------------------------------------------------------------------
-- 2) create_configured_product_and_bom_preview: INSERT sin columnas de componentes
--    y persistir totales desde snapshot en columnas numéricas (evita MSRP en 0)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_configured_product_and_bom_preview(
  p_org_id uuid,
  p_product_type_id uuid,
  p_config_snapshot jsonb,
  p_quote_id uuid DEFAULT NULL,
  p_quote_line_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_configured_product_id uuid;
  v_bom_template_id uuid;
  v_bom_instance_id uuid;
  v_totals jsonb;
  v_preview_snapshot jsonb;
  v_hardware_color text;
  v_fabric_item_id uuid;
  v_width_mm numeric(12,4);
  v_height_mm numeric(12,4);
  v_quantity numeric(12,4);
  v_roll_sku text;
  v_roll_collection_name text;
  v_roll_variant_name text;
  v_roll_width numeric(12,4);
  v_totals_json jsonb;
BEGIN
  v_bom_template_id := public.select_best_bom_template_for_configured_product(p_org_id, p_product_type_id, p_config_snapshot);
  IF v_bom_template_id IS NULL THEN
    RAISE EXCEPTION 'No matching BOMTemplate found for product_type_id=% with config=%', p_product_type_id, p_config_snapshot::text;
  END IF;
  v_hardware_color := COALESCE(p_config_snapshot->>'hardware_color', p_config_snapshot->>'hardwareColor');
  v_fabric_item_id := (p_config_snapshot->>'variantId')::uuid;
  IF v_fabric_item_id IS NULL THEN v_fabric_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid; END IF;
  v_width_mm := (p_config_snapshot->>'width_mm')::numeric(12,4);
  v_height_mm := (p_config_snapshot->>'height_mm')::numeric(12,4);
  v_quantity := COALESCE((p_config_snapshot->>'quantity')::numeric(12,4), 1);
  v_roll_sku := NULL; v_roll_collection_name := NULL; v_roll_variant_name := NULL; v_roll_width := NULL;
  IF v_fabric_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width)
      INTO v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width
    FROM public."CatalogItems" ci WHERE ci.id = v_fabric_item_id AND ci.organization_id = p_org_id LIMIT 1;
  END IF;

  INSERT INTO public."ConfiguredProducts" (
    organization_id, quote_id, bom_template_id, product_type_id,
    width_mm, height_mm, quantity, hardware_color,
    roll_catalog_item_id, roll_sku, roll_collection_name, roll_variant_name, roll_width,
    config_snapshot
  )
  VALUES (
    p_org_id, p_quote_id, v_bom_template_id, p_product_type_id,
    v_width_mm, v_height_mm, v_quantity, v_hardware_color,
    v_fabric_item_id, v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width,
    p_config_snapshot
  )
  RETURNING id INTO v_configured_product_id;

  v_bom_instance_id := NULL;
  v_totals := public.calculate_configured_product_totals(v_configured_product_id);
  v_preview_snapshot := public.build_bom_preview_snapshot(p_org_id, v_configured_product_id, v_bom_template_id);

  v_totals_json := v_preview_snapshot->'totals';
  UPDATE public."ConfiguredProducts"
  SET bom_preview_snapshot = v_preview_snapshot,
      roll_msrp_total = COALESCE((v_totals_json->>'roll_msrp_total')::numeric, 0),
      bom_total = COALESCE((v_totals_json->>'bom_total')::numeric, 0),
      roll_plus_bom_total = COALESCE((v_totals_json->>'roll_msrp_total')::numeric, 0) + COALESCE((v_totals_json->>'bom_total')::numeric, 0),
      total_msrp = COALESCE((v_totals_json->>'total_msrp')::numeric, 0),
      roll_total_cost = COALESCE((v_totals_json->>'roll_total_cost')::numeric, 0),
      bom_total_cost = COALESCE((v_totals_json->>'bom_total_cost')::numeric, 0),
      labor_amount = COALESCE((v_totals_json->>'labor_amount')::numeric, 0),
      accessories_total = COALESCE((v_totals_json->>'accessories_total')::numeric, 0),
      updated_at = now()
  WHERE id = v_configured_product_id AND organization_id = p_org_id;

  RETURN jsonb_build_object(
    'configured_product_id', v_configured_product_id,
    'bom_instance_id', v_bom_instance_id,
    'bom_template_id', v_bom_template_id,
    'totals', v_totals_json,
    'bom_preview_snapshot', v_preview_snapshot
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 3) commit_configured_product_to_quote_line: operating_type SOLO desde config_snapshot
--    (Tras DROP COLUMN operating_type, v_cp.operating_type ya no existe.)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.commit_configured_product_to_quote_line(
  p_org_id uuid,
  p_quote_id uuid,
  p_configured_product_id uuid,
  p_company_id uuid DEFAULT NULL,
  p_position text DEFAULT NULL,
  p_area text DEFAULT NULL
)
RETURNS TABLE(quote_line_id uuid, bom_instance_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cp RECORD;
  v_quote_line_id uuid;
  v_bom_instance_id uuid;
  v_width_m numeric(12,4);
  v_height_m numeric(12,4);
  v_roll_item RECORD;
  v_operating_type text;
  v_roll_msrp_total numeric(12,4);
  v_bom_total numeric(12,4);
  v_total_msrp numeric(12,4);
  v_roll_total_cost numeric(12,4);
  v_bom_total_cost numeric(12,4);
  v_labor_amount numeric(12,4);
  v_accessories_total numeric(12,4);
  v_snapshot jsonb;
  v_snapshot_totals jsonb;
  v_recalc jsonb;
BEGIN
  IF p_org_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_org_id is required'; END IF;
  IF p_quote_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_quote_id is required'; END IF;
  IF p_configured_product_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_configured_product_id is required'; END IF;

  SELECT * INTO v_cp FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id AND organization_id = p_org_id AND deleted = false;
  IF v_cp.id IS NULL THEN RAISE EXCEPTION 'ConfiguredProduct % not found or does not belong to org %', p_configured_product_id, p_org_id; END IF;
  IF v_cp.bom_template_id IS NULL THEN RAISE EXCEPTION 'ConfiguredProduct % has no bom_template_id', p_configured_product_id; END IF;

  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := v_snapshot->'totals';
  v_roll_msrp_total := 0; v_bom_total := 0; v_roll_total_cost := 0; v_bom_total_cost := 0;
  v_labor_amount := 0; v_accessories_total := 0; v_total_msrp := 0;

  IF v_snapshot->>'version' = '1' AND jsonb_array_length(v_snapshot->'items') > 0 THEN
    SELECT COALESCE(SUM(
      (item->>'line_total')::numeric + COALESCE((SELECT SUM((c->>'line_total')::numeric) FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c), 0)
    ), 0) INTO v_bom_total FROM jsonb_array_elements(v_snapshot->'items') AS item WHERE item->>'kind' = 'parent';
    SELECT COALESCE(SUM((item->>'line_total')::numeric), 0) INTO v_roll_msrp_total FROM jsonb_array_elements(v_snapshot->'items') AS item WHERE item->>'kind' = 'roll';
    v_labor_amount := COALESCE((v_snapshot_totals->>'labor_amount')::numeric, 0);
    v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, 0);
    v_roll_total_cost := COALESCE((v_snapshot_totals->>'roll_total_cost')::numeric, 0);
    v_bom_total_cost := COALESCE((v_snapshot_totals->>'bom_total_cost')::numeric, 0);
  ELSIF v_snapshot->>'version' = '1' AND v_snapshot_totals IS NOT NULL THEN
    v_roll_msrp_total := COALESCE((v_snapshot_totals->>'roll_msrp_total')::numeric, 0);
    v_bom_total := COALESCE((v_snapshot_totals->>'bom_total')::numeric, 0);
    v_roll_total_cost := COALESCE((v_snapshot_totals->>'roll_total_cost')::numeric, 0);
    v_bom_total_cost := COALESCE((v_snapshot_totals->>'bom_total_cost')::numeric, 0);
    v_labor_amount := COALESCE((v_snapshot_totals->>'labor_amount')::numeric, 0);
    v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, 0);
    v_total_msrp := COALESCE((v_snapshot_totals->>'total_msrp')::numeric, 0);
  ELSE
    v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0);
    v_bom_total := COALESCE(v_cp.bom_total, 0);
    v_roll_total_cost := COALESCE(v_cp.roll_total_cost, 0);
    v_bom_total_cost := COALESCE(v_cp.bom_total_cost, 0);
    v_labor_amount := COALESCE(v_cp.labor_amount, 0);
    v_accessories_total := COALESCE(v_cp.accessories_total, 0);
    v_total_msrp := COALESCE(v_cp.total_msrp, 0);
  END IF;
  v_total_msrp := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total;
  IF (v_total_msrp IS NULL OR v_total_msrp = 0) THEN
    BEGIN
      v_recalc := public.calculate_configured_product_totals(p_configured_product_id);
      IF v_recalc IS NOT NULL AND NOT (v_recalc ? 'error') THEN
        v_roll_msrp_total := COALESCE((v_recalc->>'roll_msrp_total')::numeric, 0);
        v_bom_total := COALESCE((v_recalc->>'bom_total')::numeric, 0);
        v_roll_total_cost := COALESCE((v_recalc->>'roll_total_cost')::numeric, 0);
        v_bom_total_cost := COALESCE((v_recalc->>'bom_total_cost')::numeric, 0);
        v_labor_amount := COALESCE((v_recalc->>'labor_amount')::numeric, 0);
        v_accessories_total := COALESCE((v_recalc->>'accessories_total')::numeric, 0);
        v_total_msrp := COALESCE((v_recalc->>'total_msrp')::numeric, 0);
        IF v_total_msrp = 0 THEN v_total_msrp := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total; END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;

  v_width_m := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m := COALESCE(v_cp.height_mm / 1000.0, 0);
  -- operating_type SOLO desde config_snapshot (columnas ya eliminadas)
  v_operating_type := COALESCE(
    v_cp.config_snapshot->>'operating_type',
    v_cp.config_snapshot->>'drive_type',
    v_cp.config_snapshot->>'operation_type'
  );
  IF v_operating_type IS NOT NULL THEN
    v_operating_type := lower(trim(v_operating_type));
    IF v_operating_type IN ('motorized', 'motorised') THEN v_operating_type := 'motor'; END IF;
  END IF;

  SELECT ci.sku, ci.name, ci.category_id, ci.manufacturer_id, m.name AS manufacturer_name, ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_m
  INTO v_roll_item FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id AND ci.is_active = true LIMIT 1;

  INSERT INTO public."QuoteLines" (
    organization_id, company_id, quote_id, product_type_id, configured_product_id, bom_template_id,
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer, collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity, hardware_color, drive_type, position, area,
    roll_msrp_snapshot, bom_msrp_snapshot, roll_cost_snapshot, bom_cost_snapshot, msrp, total_cost,
    pricing_locked, last_priced_at, pricing_version
  )
  VALUES (
    p_org_id, COALESCE(p_company_id, (SELECT company_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)), p_quote_id,
    v_cp.product_type_id, v_cp.id, v_cp.bom_template_id,
    v_cp.roll_catalog_item_id, COALESCE(v_cp.roll_sku, v_roll_item.sku), v_roll_item.name, v_roll_item.category_id, v_roll_item.manufacturer_id, v_roll_item.manufacturer_name, COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name), COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name), v_cp.roll_catalog_item_id IS NOT NULL, CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END, COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    v_width_m, v_height_m, COALESCE(v_cp.quantity, 1), v_cp.hardware_color, v_operating_type, p_position, p_area,
    v_roll_msrp_total, v_bom_total, v_roll_total_cost, v_bom_total_cost, v_total_msrp, v_roll_total_cost + v_bom_total_cost + v_labor_amount,
    true, now(), 1
  )
  RETURNING id INTO v_quote_line_id;
  IF v_quote_line_id IS NULL THEN RAISE EXCEPTION 'Failed to insert QuoteLine for ConfiguredProduct %', p_configured_product_id; END IF;
  RETURN QUERY SELECT v_quote_line_id, NULL::uuid;
END;
$$;

-- ----------------------------------------------------------------------------
-- 4) Eliminar columnas redundantes (headbox, side_channel, etc. están en config_snapshot)
-- ----------------------------------------------------------------------------
ALTER TABLE public."ConfiguredProducts"
  DROP COLUMN IF EXISTS headbox_item_id,
  DROP COLUMN IF EXISTS headbox_sku,
  DROP COLUMN IF EXISTS side_channel_item_id,
  DROP COLUMN IF EXISTS side_channel_sku,
  DROP COLUMN IF EXISTS bottom_channel_item_id,
  DROP COLUMN IF EXISTS bottom_channel_sku,
  DROP COLUMN IF EXISTS bottom_bar_item_id,
  DROP COLUMN IF EXISTS bottom_bar_sku,
  DROP COLUMN IF EXISTS motor_item_id,
  DROP COLUMN IF EXISTS motor_item_sku,
  DROP COLUMN IF EXISTS drive_item_id,
  DROP COLUMN IF EXISTS drive_sku,
  DROP COLUMN IF EXISTS tube_item_id,
  DROP COLUMN IF EXISTS tube_sku,
  DROP COLUMN IF EXISTS operating_type;

COMMIT;
