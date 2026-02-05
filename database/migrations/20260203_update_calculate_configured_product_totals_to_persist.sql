-- Update calculate_configured_product_totals to:
-- - Use current schema (no bom_instance_id/fabric_cut_* fields)
-- - Persist computed totals back into ConfiguredProducts (so frontend can read snapshots)
-- - Return keys compatible with frontend expectations

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

  v_roll_plus_bom_total numeric := 0;
  v_labor_amount numeric := 0;
  v_accessories_total numeric := 0;
  v_total_msrp numeric := 0;
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

  v_roll_plus_bom_total := v_roll_msrp_total + v_bom_msrp;
  v_accessories_total := COALESCE(v_cp.accessories_total, 0);
  v_labor_amount := v_roll_plus_bom_total * (COALESCE(v_cp.labor_pct, 0) / 100.0);
  v_total_msrp := v_roll_plus_bom_total + v_accessories_total + v_labor_amount;

  -- Persist back to ConfiguredProducts (expected by frontend snapshot flow)
  UPDATE public."ConfiguredProducts"
  SET
    roll_msrp_total = v_roll_msrp_total,
    roll_total_cost = v_roll_total_cost,
    bom_total = v_bom_msrp,
    bom_total_cost = v_bom_total_cost,
    roll_plus_bom_total = v_roll_plus_bom_total,
    labor_amount = v_labor_amount,
    total_msrp = v_total_msrp,
    updated_at = now()
  WHERE id = p_configured_product_id;

  RETURN jsonb_build_object(
    'configured_product_id', p_configured_product_id,
    'bom_instance_id', v_bom_instance_id,
    'roll_msrp_total', v_roll_msrp_total,
    'bom_total', v_bom_msrp,
    'roll_plus_bom_total', v_roll_plus_bom_total,
    'labor_amount', v_labor_amount,
    'accessories_total', v_accessories_total,
    'total_msrp', v_total_msrp,
    'roll_total_cost', v_roll_total_cost,
    'bom_total_cost', v_bom_total_cost,
    'total_cost', (v_roll_total_cost + v_bom_total_cost)
  );
END;
$$;

