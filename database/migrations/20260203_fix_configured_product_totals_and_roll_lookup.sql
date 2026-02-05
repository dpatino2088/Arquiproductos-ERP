-- Fix configured product totals + roll lookup to match current schema.
-- - Removes references to non-existent ConfiguredProducts fields (bom_instance_id, fabric_cut_*).
-- - Uses BOMInstances.configured_product_id to locate BOM instance when present.
-- - Computes roll totals based on CatalogItemsMSRP and roll dimensions.
-- - Fixes roll lookup in create_configured_product_and_bom_preview (CatalogItems has no is_fabric).

CREATE OR REPLACE FUNCTION public.calculate_configured_product_totals(p_configured_product_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_bom_instance_id uuid;
  v_part RECORD;

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
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  -- Locate latest BOMInstance for this configured product (may be NULL for previews)
  SELECT bi.id INTO v_bom_instance_id
  FROM public."BOMInstances" bi
  WHERE bi.configured_product_id = p_configured_product_id
    AND bi.organization_id = v_cp.organization_id
    AND bi.deleted = false
    AND bi.archived = false
  ORDER BY bi.created_at DESC
  LIMIT 1;

  -- Roll totals
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT msrp, total_cost
      INTO v_roll_msrp_unit, v_roll_cost_unit
    FROM public."CatalogItemsMSRP"
    WHERE catalog_item_id = v_cp.roll_catalog_item_id
      AND organization_id = v_cp.organization_id
    LIMIT 1;

    IF v_roll_msrp_unit IS NULL THEN
      SELECT msrp, total_cost
        INTO v_roll_msrp_unit, v_roll_cost_unit
      FROM public."CatalogItemsMSRP"
      WHERE catalog_item_id = v_cp.roll_catalog_item_id
      LIMIT 1;
    END IF;

    SELECT ci.roll_pricing_mode, ci.measure_basis
      INTO v_roll_pricing_mode, v_roll_measure_basis
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
    LIMIT 1;

    v_roll_width_m := COALESCE(v_cp.roll_width, 0);
    v_height_m := COALESCE(v_cp.height_mm, 0) / 1000.0;
    v_qty := COALESCE(v_cp.quantity, 1);

    -- Default behavior:
    -- - Fabrics priced per m²: roll_width (m) × height (m) × qty
    -- - Per linear meter: height (m) × qty
    -- - Per unit: qty
    IF v_roll_pricing_mode = 'per_unit' THEN
      v_roll_factor := v_qty;
    ELSIF v_roll_pricing_mode = 'per_linear_meter' OR v_roll_measure_basis = 'linear' THEN
      v_roll_factor := v_height_m * v_qty;
    ELSE
      -- per_square_meter OR unknown: treat as area
      v_roll_factor := (v_roll_width_m * v_height_m) * v_qty;
    END IF;

    v_roll_msrp_total := COALESCE(v_roll_msrp_unit, 0) * v_roll_factor;
    v_roll_total_cost := COALESCE(v_roll_cost_unit, 0) * v_roll_factor;
  END IF;

  -- BOM totals (components). If no BOMInstance yet, BOM totals stay 0.
  IF v_bom_instance_id IS NOT NULL THEN
    FOR v_part IN
      SELECT bil.resolved_part_id, bil.qty
      FROM public."BOMInstanceLines" bil
      WHERE bil.bom_instance_id = v_bom_instance_id
        AND bil.deleted = false
        AND bil.archived = false
        AND bil.resolved_part_id IS NOT NULL
    LOOP
      SELECT msrp, total_cost
        INTO v_part_msrp, v_part_total_cost
      FROM public."CatalogItemsMSRP"
      WHERE catalog_item_id = v_part.resolved_part_id
        AND organization_id = v_cp.organization_id
      LIMIT 1;

      IF v_part_msrp IS NULL THEN
        SELECT msrp, total_cost
          INTO v_part_msrp, v_part_total_cost
        FROM public."CatalogItemsMSRP"
        WHERE catalog_item_id = v_part.resolved_part_id
        LIMIT 1;
      END IF;

      v_bom_msrp := v_bom_msrp + (COALESCE(v_part_msrp, 0) * COALESCE(v_part.qty, 0));
      v_bom_total_cost := v_bom_total_cost + (COALESCE(v_part_total_cost, 0) * COALESCE(v_part.qty, 0));
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'bom_instance_id', v_bom_instance_id,
    'roll_msrp', v_roll_msrp_total,
    'roll_total_cost', v_roll_total_cost,
    'bom_msrp', v_bom_msrp,
    'bom_total_cost', v_bom_total_cost,
    'total_msrp', (v_roll_msrp_total + v_bom_msrp),
    'total_cost', (v_roll_total_cost + v_bom_total_cost)
  );
END;
$$;


CREATE OR REPLACE FUNCTION public.create_configured_product_and_bom_preview(
  p_org_id uuid,
  p_product_type_id uuid,
  p_config_snapshot jsonb,
  p_quote_id uuid DEFAULT NULL::uuid,
  p_quote_line_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_configured_product_id uuid;
  v_bom_template_id uuid;
  v_bom_instance_id uuid;
  v_totals jsonb;
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
    RAISE EXCEPTION 'No matching BOMTemplate found for org %, product_type %', p_org_id, p_product_type_id;
  END IF;

  v_hardware_color := COALESCE(
    p_config_snapshot->>'hardware_color',
    p_config_snapshot->>'hardwareColor',
    p_config_snapshot->>'operatingSystemColor'
  );

  v_fabric_item_id := (p_config_snapshot->>'roll_catalog_item_id')::uuid;
  IF v_fabric_item_id IS NULL THEN
    v_fabric_item_id := (p_config_snapshot->>'fabric_catalog_item_id')::uuid;
  END IF;
  IF v_fabric_item_id IS NULL THEN
    v_fabric_item_id := (p_config_snapshot->>'variantId')::uuid;
  END IF;

  v_width_mm := (p_config_snapshot->>'width_mm')::numeric;
  IF v_width_mm IS NULL THEN
    v_width_mm := COALESCE((p_config_snapshot->>'width_m')::numeric, 0) * 1000;
  END IF;

  v_height_mm := (p_config_snapshot->>'height_mm')::numeric;
  IF v_height_mm IS NULL THEN
    v_height_mm := COALESCE((p_config_snapshot->>'height_m')::numeric, 0) * 1000;
  END IF;

  v_quantity := COALESCE((p_config_snapshot->>'quantity')::numeric, 1);

  -- Roll info (CatalogItems has no is_fabric boolean; use roll flags / type)
  IF v_fabric_item_id IS NOT NULL THEN
    SELECT
      ci.sku,
      ci.collection_name,
      ci.variant_name,
      ci.roll_width
    INTO
      v_roll_sku,
      v_roll_collection_name,
      v_roll_variant_name,
      v_roll_width
    FROM public."CatalogItems" ci
    WHERE ci.id = v_fabric_item_id
      AND ci.is_roll = true
      AND ci.roll_type = 'fabric'
      AND ci.is_active = true
      AND ci.organization_id = p_org_id
    LIMIT 1;
  END IF;

  INSERT INTO public."ConfiguredProducts"(
    organization_id,
    quote_id,
    bom_template_id,
    product_type_id,
    roll_catalog_item_id,
    roll_sku,
    roll_collection_name,
    roll_variant_name,
    roll_width,
    width_mm,
    height_mm,
    quantity,
    hardware_color,
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
  ) VALUES (
    p_org_id,
    p_quote_id,
    v_bom_template_id,
    p_product_type_id,
    v_fabric_item_id,
    v_roll_sku,
    v_roll_collection_name,
    v_roll_variant_name,
    v_roll_width,
    v_width_mm,
    v_height_mm,
    v_quantity,
    v_hardware_color,
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

  -- No BOMInstance in preview when quote_line_id is NULL (constraint).
  v_bom_instance_id := NULL;

  v_totals := public.calculate_configured_product_totals(v_configured_product_id);

  RETURN jsonb_build_object(
    'configured_product_id', v_configured_product_id,
    'bom_instance_id', v_bom_instance_id,
    'bom_template_id', v_bom_template_id,
    'totals', v_totals
  );
END;
$$;

