-- ============================================================================
-- Migration: One-Off fabric in BOM preview and totals
-- Date: 2026-02-11
-- Description: When fabric is One-Off (no roll_catalog_item_id), populate
--              roll_sku/roll_variant_name/roll_width from config_snapshot in
--              create_configured_product_and_bom_preview; add roll item in
--              build_bom_preview_snapshot and compute roll totals in
--              calculate_configured_product_totals.
-- ============================================================================

-- 1) create_configured_product_and_bom_preview: set roll_sku, roll_variant_name, roll_width from oneoff when no variantId
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
BEGIN
  v_bom_template_id := public.select_best_bom_template_for_configured_product(
    p_org_id,
    p_product_type_id,
    p_config_snapshot
  );

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
  v_width_mm := (p_config_snapshot->>'width_mm')::numeric(12,4);
  v_height_mm := (p_config_snapshot->>'height_mm')::numeric(12,4);
  v_quantity := COALESCE((p_config_snapshot->>'quantity')::numeric(12,4), 1);

  v_roll_sku := NULL;
  v_roll_collection_name := NULL;
  v_roll_variant_name := NULL;
  v_roll_width := NULL;

  IF v_fabric_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.collection_name, ci.variant_name, ci.roll_width
      INTO v_roll_sku, v_roll_collection_name, v_roll_variant_name, v_roll_width
    FROM public."CatalogItems" ci
    WHERE ci.id = v_fabric_item_id
      AND ci.organization_id = p_org_id
    LIMIT 1;
  ELSIF p_config_snapshot->>'oneoff_sku' IS NOT NULL
    AND p_config_snapshot->>'oneoff_variant_name' IS NOT NULL
    AND (p_config_snapshot->>'oneoff_roll_width_m')::numeric > 0 THEN
    v_roll_sku := NULLIF(TRIM(p_config_snapshot->>'oneoff_sku'), '');
    v_roll_variant_name := NULLIF(TRIM(p_config_snapshot->>'oneoff_variant_name'), '');
    v_roll_collection_name := NULLIF(TRIM(p_config_snapshot->>'oneoff_collection_name'), '');
    v_roll_width := (p_config_snapshot->>'oneoff_roll_width_m')::numeric(12,4);
  END IF;

  INSERT INTO public."ConfiguredProducts" (
    organization_id,
    quote_id,
    bom_template_id,
    product_type_id,
    width_mm,
    height_mm,
    quantity,
    hardware_color,
    roll_catalog_item_id,
    roll_sku,
    roll_collection_name,
    roll_variant_name,
    roll_width,
    bottom_bar_item_id,
    bottom_bar_sku,
    headbox_item_id,
    headbox_sku,
    side_channel_item_id,
    side_channel_sku,
    bottom_channel_item_id,
    bottom_channel_sku,
    motor_item_id,
    motor_sku,
    drive_item_id,
    drive_sku,
    tube_item_id,
    tube_sku,
    operating_type,
    config_snapshot
  )
  VALUES (
    p_org_id,
    p_quote_id,
    v_bom_template_id,
    p_product_type_id,
    v_width_mm,
    v_height_mm,
    v_quantity,
    v_hardware_color,
    v_fabric_item_id,
    v_roll_sku,
    v_roll_collection_name,
    v_roll_variant_name,
    v_roll_width,
    (p_config_snapshot->>'bottom_bar_item_id')::uuid,
    p_config_snapshot->>'bottom_bar_sku',
    (p_config_snapshot->>'headbox_item_id')::uuid,
    p_config_snapshot->>'headbox_sku',
    (p_config_snapshot->>'side_channel_item_id')::uuid,
    p_config_snapshot->>'side_channel_sku',
    (p_config_snapshot->>'bottom_channel_item_id')::uuid,
    p_config_snapshot->>'bottom_channel_sku',
    (p_config_snapshot->>'motor_item_id')::uuid,
    p_config_snapshot->>'motor_sku',
    (p_config_snapshot->>'drive_item_id')::uuid,
    p_config_snapshot->>'drive_sku',
    (p_config_snapshot->>'tube_item_id')::uuid,
    p_config_snapshot->>'tube_sku',
    COALESCE(
      p_config_snapshot->>'operating_type',
      p_config_snapshot->>'operation_type',
      p_config_snapshot->>'drive_type'
    ),
    p_config_snapshot
  )
  RETURNING id INTO v_configured_product_id;

  v_bom_instance_id := NULL;
  v_totals := public.calculate_configured_product_totals(v_configured_product_id);

  v_preview_snapshot := public.build_bom_preview_snapshot(
    p_org_id,
    v_configured_product_id,
    v_bom_template_id
  );

  UPDATE public."ConfiguredProducts"
  SET bom_preview_snapshot = v_preview_snapshot,
      updated_at = now()
  WHERE id = v_configured_product_id
    AND organization_id = p_org_id;

  RETURN jsonb_build_object(
    'configured_product_id', v_configured_product_id,
    'bom_instance_id', v_bom_instance_id,
    'bom_template_id', v_bom_template_id,
    'totals', v_totals,
    'bom_preview_snapshot', v_preview_snapshot
  );
END;
$$;

-- 2) build_bom_preview_snapshot: not modified here to avoid overwriting 20260207.
--    One-Off roll total is reflected in totals (calculate_configured_product_totals).
--    UI can show One-Off fabric line from totals when no roll item in items (see ReviewStep).

-- 3) calculate_configured_product_totals: when roll_catalog_item_id IS NULL, use oneoff from config_snapshot for roll totals
CREATE OR REPLACE FUNCTION public.calculate_configured_product_totals(p_configured_product_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_bom_instance_id uuid;
  v_part RECORD;
  v_config jsonb;
  v_roll_msrp_unit numeric := 0;
  v_roll_cost_unit numeric := 0;
  v_roll_factor numeric := 0;
  v_roll_msrp_total numeric := 0;
  v_roll_total_cost numeric := 0;
  v_roll_pricing_mode text;
  v_roll_measure_basis text;
  v_roll_width_m numeric := 0;
  v_height_m numeric := 0;
  v_qty numeric := 1;
  v_bom_msrp numeric := 0;
  v_bom_total_cost numeric := 0;
  v_part_msrp numeric;
  v_part_total_cost numeric;
  v_roll_plus_bom_total numeric := 0;
  v_labor_amount numeric := 0;
  v_accessories_total numeric := 0;
  v_total_msrp numeric := 0;
  v_oneoff_unit numeric := 0;
  v_oneoff_basis text;
BEGIN
  SELECT * INTO v_cp FROM public."ConfiguredProducts" WHERE id = p_configured_product_id AND deleted = false;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'ConfiguredProduct not found'); END IF;
  v_config := COALESCE(v_cp.config_snapshot, '{}'::jsonb);

  IF jsonb_typeof(v_config->'accessories') = 'array' THEN
    SELECT COALESCE(SUM((elem->>'price')::numeric * GREATEST(COALESCE((elem->>'qty')::numeric, 0), 0)), 0) INTO v_accessories_total FROM jsonb_array_elements(v_config->'accessories') AS elem;
  ELSE
    v_accessories_total := COALESCE(v_cp.accessories_total, 0);
  END IF;
  v_accessories_total := ROUND(v_accessories_total, 2);

  SELECT bi.id INTO v_bom_instance_id FROM public."BOMInstances" bi WHERE bi.configured_product_id = p_configured_product_id AND bi.organization_id = v_cp.organization_id AND bi.deleted = false AND bi.archived = false ORDER BY bi.created_at DESC LIMIT 1;

  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT msrp, total_cost INTO v_roll_msrp_unit, v_roll_cost_unit FROM public."CatalogItemsMSRP" WHERE catalog_item_id = v_cp.roll_catalog_item_id AND organization_id = v_cp.organization_id LIMIT 1;
    IF v_roll_msrp_unit IS NULL THEN SELECT msrp, total_cost INTO v_roll_msrp_unit, v_roll_cost_unit FROM public."CatalogItemsMSRP" WHERE catalog_item_id = v_cp.roll_catalog_item_id LIMIT 1; END IF;
    SELECT ci.roll_pricing_mode, ci.measure_basis INTO v_roll_pricing_mode, v_roll_measure_basis FROM public."CatalogItems" ci WHERE ci.id = v_cp.roll_catalog_item_id LIMIT 1;
    v_roll_width_m := COALESCE(v_cp.roll_width, 0);
    v_height_m := COALESCE(v_cp.height_mm, 0) / 1000.0;
    v_qty := COALESCE(v_cp.quantity, 1);
    IF v_roll_pricing_mode = 'per_unit' THEN v_roll_factor := v_qty;
    ELSIF v_roll_pricing_mode = 'per_linear_meter' OR v_roll_measure_basis = 'linear' THEN v_roll_factor := v_height_m * v_qty;
    ELSE v_roll_factor := (v_roll_width_m * v_height_m) * v_qty; END IF;
    v_roll_msrp_total := COALESCE(v_roll_msrp_unit, 0) * v_roll_factor;
    v_roll_total_cost := COALESCE(v_roll_cost_unit, 0) * v_roll_factor;
  ELSIF (v_cp.roll_sku IS NOT NULL AND TRIM(v_cp.roll_sku) <> '') OR (v_config->>'oneoff_sku') IS NOT NULL THEN
    v_oneoff_basis := COALESCE(v_config->>'oneoff_cost_basis', 'area');
    v_oneoff_unit := COALESCE((v_config->>'oneoff_cost_per_m2_exw')::numeric, (v_config->>'oneoff_cost_per_m_exw')::numeric, (v_config->>'oneoff_cost_value')::numeric, 0);
    v_height_m := COALESCE(v_cp.height_mm, 0) / 1000.0;
    v_roll_width_m := COALESCE(v_cp.roll_width, (v_config->>'oneoff_roll_width_m')::numeric);
    v_qty := COALESCE(v_cp.quantity, 1);
    IF v_oneoff_basis = 'linear' THEN
      v_roll_factor := v_height_m * v_qty;
      v_roll_msrp_total := v_oneoff_unit * v_roll_factor;
      v_roll_total_cost := v_roll_msrp_total;
    ELSE
      v_roll_factor := (v_roll_width_m * v_height_m) * v_qty;
      v_roll_msrp_total := v_oneoff_unit * v_roll_factor;
      v_roll_total_cost := v_roll_msrp_total;
    END IF;
    v_roll_msrp_total := ROUND(v_roll_msrp_total, 2);
    v_roll_total_cost := ROUND(v_roll_total_cost, 2);
  END IF;

  IF v_bom_instance_id IS NOT NULL THEN
    FOR v_part IN SELECT bil.resolved_part_id, bil.qty FROM public."BOMInstanceLines" bil WHERE bil.bom_instance_id = v_bom_instance_id AND bil.deleted = false AND bil.archived = false AND bil.resolved_part_id IS NOT NULL
    LOOP
      SELECT msrp, total_cost INTO v_part_msrp, v_part_total_cost FROM public."CatalogItemsMSRP" WHERE catalog_item_id = v_part.resolved_part_id AND organization_id = v_cp.organization_id LIMIT 1;
      IF v_part_msrp IS NULL THEN SELECT msrp, total_cost INTO v_part_msrp, v_part_total_cost FROM public."CatalogItemsMSRP" WHERE catalog_item_id = v_part.resolved_part_id LIMIT 1; END IF;
      v_bom_msrp := v_bom_msrp + (COALESCE(v_part_msrp, 0) * COALESCE(v_part.qty, 0));
      v_bom_total_cost := v_bom_total_cost + (COALESCE(v_part_total_cost, 0) * COALESCE(v_part.qty, 0));
    END LOOP;
  END IF;

  v_roll_plus_bom_total := v_roll_msrp_total + v_bom_msrp;
  v_labor_amount := v_roll_plus_bom_total * (COALESCE(v_cp.labor_pct, 0) / 100.0);
  v_total_msrp := v_roll_plus_bom_total + v_accessories_total + v_labor_amount;

  UPDATE public."ConfiguredProducts"
  SET roll_msrp_total = v_roll_msrp_total, roll_total_cost = v_roll_total_cost, bom_total = v_bom_msrp, bom_total_cost = v_bom_total_cost, roll_plus_bom_total = v_roll_plus_bom_total, labor_amount = v_labor_amount, accessories_total = v_accessories_total, total_msrp = v_total_msrp, updated_at = now()
  WHERE id = p_configured_product_id;

  RETURN jsonb_build_object('configured_product_id', p_configured_product_id, 'bom_instance_id', v_bom_instance_id, 'roll_msrp_total', v_roll_msrp_total, 'bom_total', v_bom_msrp, 'roll_plus_bom_total', v_roll_plus_bom_total, 'labor_amount', v_labor_amount, 'accessories_total', v_accessories_total, 'total_msrp', v_total_msrp, 'roll_total_cost', v_roll_total_cost, 'bom_total_cost', v_bom_total_cost, 'total_cost', (v_roll_total_cost + v_bom_total_cost));
END;
$$;

COMMENT ON FUNCTION public.create_configured_product_and_bom_preview(uuid, uuid, jsonb, uuid, uuid) IS 'Creates ConfiguredProduct with pricing. Supports One-Off fabric via config_snapshot oneoff_* when roll_catalog_item_id is null.';
COMMENT ON FUNCTION public.calculate_configured_product_totals(uuid) IS 'Recalculates ConfiguredProduct totals. Roll from catalog or from One-Off (config_snapshot oneoff_*).';
