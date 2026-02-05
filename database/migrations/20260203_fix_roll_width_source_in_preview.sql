-- Ensure preview uses normalized roll_width_m when available.

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

  -- Roll info (prefer normalized roll_width_m)
  IF v_fabric_item_id IS NOT NULL THEN
    SELECT
      ci.sku,
      ci.collection_name,
      ci.variant_name,
      COALESCE(ci.roll_width_m, ci.roll_width)
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

