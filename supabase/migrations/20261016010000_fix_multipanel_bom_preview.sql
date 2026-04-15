-- Fix multi-panel BOM preview pricing
--
-- Root cause: create_configured_product_and_bom_preview inserts ConfiguredProducts
-- with dimension_outputs=NULL, then calls build_bom_preview_snapshot which reads
-- that NULL column. Without tube_panel_cuts in dimension_outputs, fabric pricing
-- falls back to total-width calculation instead of per-panel drops.
--
-- The MO/WO flow works correctly because generate_bom_for_manufacturing_order
-- calls compute_system_dimensions() LIVE before building BOM instance lines.
--
-- Fix: call compute_system_dimensions() after INSERT and store result in
-- dimension_outputs BEFORE calling build_bom_preview_snapshot.

SET search_path = public;

-- ============================================================================
-- 1. Recreate create_configured_product_and_bom_preview with dimension_outputs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_configured_product_and_bom_preview(
  p_org_id uuid,
  p_product_type_id uuid,
  p_config_snapshot jsonb,
  p_quote_id uuid DEFAULT NULL,
  p_quote_line_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
  v_dim_result            jsonb;
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
    NULLIF((p_config_snapshot->'measurements'->>'width_total_mm')::numeric(12,4), 0),
    (p_config_snapshot->>'width_mm')::numeric(12,4),
    0
  );
  v_height_mm  := (p_config_snapshot->>'height_mm')::numeric(12,4);
  v_quantity   := COALESCE((p_config_snapshot->>'quantity')::numeric(12,4), 1);

  IF v_fabric_item_id IS NOT NULL THEN
    SELECT ci.sku, ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width)
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

  -- Compute per-panel dimensions (tube_panel_cuts, bottom_bar_panel_cuts)
  -- BEFORE building BOM preview so fabric pricing uses per-panel drops.
  BEGIN
    v_dim_result := public.compute_system_dimensions(v_configured_product_id);
    IF v_dim_result IS NOT NULL AND v_dim_result != '{}'::jsonb THEN
      UPDATE public."ConfiguredProducts"
      SET dimension_outputs = v_dim_result
      WHERE id = v_configured_product_id AND organization_id = p_org_id;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    NULL;
  END;

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

GRANT EXECUTE ON FUNCTION public.create_configured_product_and_bom_preview(uuid, uuid, jsonb, uuid, uuid) TO authenticated;

-- ============================================================================
-- 2. Backfill existing multi-panel ConfiguredProducts
-- ============================================================================

DO $$
DECLARE
  r RECORD;
  v_dim jsonb;
  v_panels jsonb;
BEGIN
  FOR r IN
    SELECT cp.id, cp.organization_id, cp.bom_template_id
    FROM public."ConfiguredProducts" cp
    WHERE cp.deleted = false
      AND cp.bom_template_id IS NOT NULL
      AND (cp.dimension_outputs IS NULL OR cp.dimension_outputs = '{}'::jsonb)
      AND (
        (cp.config_snapshot->'measurements'->'panels' IS NOT NULL
         AND jsonb_typeof(cp.config_snapshot->'measurements'->'panels') = 'array'
         AND jsonb_array_length(cp.config_snapshot->'measurements'->'panels') > 1)
        OR
        (cp.config_snapshot->'panels' IS NOT NULL
         AND jsonb_typeof(cp.config_snapshot->'panels') = 'array'
         AND jsonb_array_length(cp.config_snapshot->'panels') > 1)
      )
  LOOP
    BEGIN
      v_dim := public.compute_system_dimensions(r.id);
      IF v_dim IS NOT NULL AND v_dim != '{}'::jsonb THEN
        UPDATE public."ConfiguredProducts"
        SET dimension_outputs = v_dim
        WHERE id = r.id;

        UPDATE public."ConfiguredProducts"
        SET bom_preview_snapshot = public.build_bom_preview_snapshot(r.organization_id, r.id, r.bom_template_id),
            updated_at = now()
        WHERE id = r.id;

        PERFORM public.calculate_configured_product_totals(r.id);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Skipping CP % due to error: %', r.id, SQLERRM;
    END;
  END LOOP;
END;
$$;
