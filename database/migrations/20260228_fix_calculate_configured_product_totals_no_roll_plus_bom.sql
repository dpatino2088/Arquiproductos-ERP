-- ============================================================================
-- Fix: calculate_configured_product_totals y RPCs sin roll_plus_bom_total ni roll_total_cost
-- Fecha: 2026-02-28
--
-- ConfiguredProducts puede no tener roll_plus_bom_total ni roll_total_cost.
-- Usar solo msrp_product_subtotal y roll_total_cost_landed / bom_total_cost_landed.
-- Aplicar si falla:
--   "column roll_plus_bom_total of relation ConfiguredProducts does not exist"
--   "column roll_total_cost of relation ConfiguredProducts does not exist"
--
-- Requisito: tabla ConfiguredProducts con columnas de 20260221 (msrp_product_subtotal,
-- roll_total_cost_landed, bom_total_cost_landed, etc.). Si no, esta migración las crea.
-- ============================================================================

-- Crear columnas en ConfiguredProducts si no existen (para que el UPDATE de la función no falle)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'msrp_product_subtotal') THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN msrp_product_subtotal numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'labor_msrp') THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN labor_msrp numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'unit_msrp_total') THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN unit_msrp_total numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'unit_product_cost_landed') THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN unit_product_cost_landed numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'unit_labor_cost') THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN unit_labor_cost numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'roll_total_cost_landed') THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN roll_total_cost_landed numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'bom_total_cost_landed') THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN bom_total_cost_landed numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'accessories_total_cost_landed') THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN accessories_total_cost_landed numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'total_cost_landed_without_labor') THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN total_cost_landed_without_labor numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'total_cost_with_labor') THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN total_cost_with_labor numeric(12,4) DEFAULT 0;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ConfiguredProducts' AND column_name = 'bom_preview_snapshot') THEN
    ALTER TABLE public."ConfiguredProducts" ADD COLUMN bom_preview_snapshot jsonb DEFAULT '{}'::jsonb;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.calculate_configured_product_totals(p_configured_product_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_cp RECORD;
  v_snapshot jsonb;
  v_snapshot_totals jsonb;
  v_item jsonb;
  v_child jsonb;
  v_acc jsonb;

  v_roll_pricing_mode text;
  v_roll_measure_basis text;
  v_roll_factor numeric := 0;
  v_roll_width_m numeric := 0;
  v_height_m numeric := 0;

  v_item_id uuid;
  v_item_qty numeric;
  v_item_msrp numeric;
  v_item_cost numeric;

  v_roll_msrp_total numeric := 0;
  v_bom_total numeric := 0;
  v_accessories_total numeric := 0;
  v_labor_msrp numeric := 0;
  v_unit_msrp_total numeric := 0;
  v_msrp_product_subtotal numeric := 0;

  v_roll_total_cost_landed numeric := 0;
  v_bom_total_cost_landed numeric := 0;
  v_accessories_total_cost_landed numeric := 0;
  v_unit_product_cost_landed numeric := 0;
  v_unit_labor_cost numeric := 0;
  v_total_cost_landed_without_labor numeric := 0;
  v_total_cost_with_labor numeric := 0;
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := COALESCE(v_snapshot->'totals', '{}'::jsonb);

  -- Roll landed MSRP + landed cost (per unit, never multiplied by ConfiguredProducts.quantity)
  IF v_cp.roll_catalog_item_id IS NOT NULL THEN
    SELECT ci.roll_pricing_mode, ci.measure_basis
    INTO v_roll_pricing_mode, v_roll_measure_basis
    FROM public."CatalogItems" ci
    WHERE ci.id = v_cp.roll_catalog_item_id
    LIMIT 1;

    v_roll_width_m := COALESCE(v_cp.roll_width, 0);
    v_height_m := COALESCE(v_cp.height_mm, 0) / 1000.0;

    IF v_roll_pricing_mode = 'per_unit' THEN
      v_roll_factor := 1;
    ELSIF v_roll_pricing_mode = 'per_linear_meter' OR v_roll_measure_basis = 'linear' THEN
      v_roll_factor := v_height_m;
    ELSE
      v_roll_factor := (v_roll_width_m * v_height_m);
    END IF;

    SELECT unit_msrp, unit_cost
    INTO v_item_msrp, v_item_cost
    FROM public.resolve_catalog_item_landed_price_cost(v_cp.organization_id, v_cp.roll_catalog_item_id);

    v_roll_msrp_total := COALESCE(v_item_msrp, 0) * COALESCE(v_roll_factor, 0);
    v_roll_total_cost_landed := COALESCE(v_item_cost, 0) * COALESCE(v_roll_factor, 0);
  END IF;

  -- BOM landed MSRP + landed cost from snapshot items (parents + children)
  IF v_snapshot->>'version' = '1' AND jsonb_typeof(v_snapshot->'items') = 'array' THEN
    FOR v_item IN SELECT value FROM jsonb_array_elements(v_snapshot->'items')
    LOOP
      IF COALESCE(v_item->>'kind', '') = 'parent' THEN
        v_item_qty := COALESCE((v_item->>'qty')::numeric, 0);
        v_item_id := CASE
          WHEN COALESCE(v_item->>'catalog_item_id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            THEN (v_item->>'catalog_item_id')::uuid
          ELSE NULL
        END;

        IF v_item_id IS NOT NULL THEN
          SELECT unit_msrp, unit_cost INTO v_item_msrp, v_item_cost
          FROM public.resolve_catalog_item_landed_price_cost(v_cp.organization_id, v_item_id);
          v_bom_total := v_bom_total + (COALESCE(v_item_qty, 0) * COALESCE(v_item_msrp, 0));
          v_bom_total_cost_landed := v_bom_total_cost_landed + (COALESCE(v_item_qty, 0) * COALESCE(v_item_cost, 0));
        ELSE
          v_bom_total := v_bom_total + COALESCE((v_item->>'line_total')::numeric, 0);
        END IF;

        IF jsonb_typeof(v_item->'children') = 'array' THEN
          FOR v_child IN SELECT value FROM jsonb_array_elements(v_item->'children')
          LOOP
            v_item_qty := COALESCE((v_child->>'qty')::numeric, 0);
            v_item_id := CASE
              WHEN COALESCE(v_child->>'catalog_item_id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                THEN (v_child->>'catalog_item_id')::uuid
              ELSE NULL
            END;

            IF v_item_id IS NOT NULL THEN
              SELECT unit_msrp, unit_cost INTO v_item_msrp, v_item_cost
              FROM public.resolve_catalog_item_landed_price_cost(v_cp.organization_id, v_item_id);
              v_bom_total := v_bom_total + (COALESCE(v_item_qty, 0) * COALESCE(v_item_msrp, 0));
              v_bom_total_cost_landed := v_bom_total_cost_landed + (COALESCE(v_item_qty, 0) * COALESCE(v_item_cost, 0));
            ELSE
              v_bom_total := v_bom_total + COALESCE((v_child->>'line_total')::numeric, 0);
            END IF;
          END LOOP;
        END IF;
      END IF;
    END LOOP;
  END IF;

  -- Accessories MSRP + landed cost (if array exists in config snapshot)
  IF jsonb_typeof(v_cp.config_snapshot->'accessories') = 'array' THEN
    FOR v_acc IN SELECT value FROM jsonb_array_elements(v_cp.config_snapshot->'accessories')
    LOOP
      v_item_qty := GREATEST(COALESCE((v_acc->>'qty')::numeric, 0), 0);
      v_item_id := CASE
        WHEN COALESCE(v_acc->>'id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          THEN (v_acc->>'id')::uuid
        WHEN COALESCE(v_acc->>'catalog_item_id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          THEN (v_acc->>'catalog_item_id')::uuid
        ELSE NULL
      END;

      IF v_item_id IS NOT NULL THEN
        SELECT unit_msrp, unit_cost INTO v_item_msrp, v_item_cost
        FROM public.resolve_catalog_item_landed_price_cost(v_cp.organization_id, v_item_id);
      ELSE
        v_item_msrp := 0;
        v_item_cost := 0;
      END IF;

      v_item_msrp := COALESCE(NULLIF((v_acc->>'price')::numeric, 0), v_item_msrp, 0);

      v_accessories_total := v_accessories_total + (v_item_qty * COALESCE(v_item_msrp, 0));
      v_accessories_total_cost_landed := v_accessories_total_cost_landed + (v_item_qty * COALESCE(v_item_cost, 0));
    END LOOP;
  ELSE
    v_accessories_total := COALESCE(v_cp.accessories_total, COALESCE((v_snapshot_totals->>'accessories_total')::numeric, 0), 0);
    v_accessories_total_cost_landed := COALESCE((v_snapshot_totals->>'accessories_total_cost_landed')::numeric, 0);
  END IF;

  v_msrp_product_subtotal := COALESCE(v_roll_msrp_total, 0) + COALESCE(v_bom_total, 0) + COALESCE(v_accessories_total, 0);
  v_labor_msrp := COALESCE(v_cp.labor_msrp, v_cp.labor_amount, 0);
  IF v_labor_msrp = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_msrp := v_msrp_product_subtotal * CASE WHEN v_cp.labor_pct <= 1 THEN v_cp.labor_pct ELSE (v_cp.labor_pct / 100.0) END;
  END IF;
  v_unit_msrp_total := v_msrp_product_subtotal + v_labor_msrp;

  v_unit_product_cost_landed := COALESCE(v_roll_total_cost_landed, 0) + COALESCE(v_bom_total_cost_landed, 0) + COALESCE(v_accessories_total_cost_landed, 0);
  v_unit_labor_cost := COALESCE(v_cp.unit_labor_cost, 0);
  v_total_cost_landed_without_labor := v_unit_product_cost_landed;
  v_total_cost_with_labor := v_unit_product_cost_landed + v_unit_labor_cost;

  -- UPDATE sin roll_plus_bom_total (usar solo msrp_product_subtotal y columnas existentes)
  UPDATE public."ConfiguredProducts"
  SET
    roll_msrp_total = v_roll_msrp_total,
    bom_total = v_bom_total,
    accessories_total = v_accessories_total,
    labor_amount = v_labor_msrp,
    total_msrp = v_unit_msrp_total,
    msrp_product_subtotal = v_msrp_product_subtotal,
    labor_msrp = v_labor_msrp,
    unit_msrp_total = v_unit_msrp_total,
    unit_product_cost_landed = v_unit_product_cost_landed,
    unit_labor_cost = v_unit_labor_cost,
    roll_total_cost_landed = v_roll_total_cost_landed,
    bom_total_cost_landed = v_bom_total_cost_landed,
    accessories_total_cost_landed = v_accessories_total_cost_landed,
    total_cost_landed_without_labor = v_total_cost_landed_without_labor,
    total_cost_with_labor = v_total_cost_with_labor,
    bom_preview_snapshot = jsonb_set(
      COALESCE(v_snapshot, '{}'::jsonb),
      '{totals}',
      COALESCE(v_snapshot_totals, '{}'::jsonb) || jsonb_build_object(
        'roll_msrp_total', v_roll_msrp_total,
        'bom_total', v_bom_total,
        'accessories_total', v_accessories_total,
        'labor_amount', v_labor_msrp,
        'total_msrp', v_unit_msrp_total,
        'roll_total_cost', v_roll_total_cost_landed,
        'bom_total_cost', v_bom_total_cost_landed,
        'msrp_product_subtotal', v_msrp_product_subtotal,
        'labor_msrp', v_labor_msrp,
        'unit_msrp_total', v_unit_msrp_total,
        'unit_product_cost_landed', v_unit_product_cost_landed,
        'unit_labor_cost', v_unit_labor_cost,
        'roll_total_cost_landed', v_roll_total_cost_landed,
        'bom_total_cost_landed', v_bom_total_cost_landed,
        'accessories_total_cost_landed', v_accessories_total_cost_landed,
        'total_cost_landed_without_labor', v_total_cost_landed_without_labor,
        'total_cost_with_labor', v_total_cost_with_labor
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
    'roll_total_cost_landed', v_roll_total_cost_landed,
    'bom_total_cost_landed', v_bom_total_cost_landed,
    'accessories_total_cost_landed', v_accessories_total_cost_landed,
    'unit_product_cost_landed', v_unit_product_cost_landed,
    'unit_labor_cost', v_unit_labor_cost,
    'total_cost_landed_without_labor', v_total_cost_landed_without_labor,
    'total_cost_with_labor', v_total_cost_with_labor,
    'roll_total_cost', v_roll_total_cost_landed,
    'bom_total_cost', v_bom_total_cost_landed,
    'total_cost', v_total_cost_with_labor
  );
END;
$$;

COMMENT ON FUNCTION public.calculate_configured_product_totals(uuid) IS
'Computes per-unit MSRP and landed costs. Uses msrp_product_subtotal (no roll_plus_bom_total).';

-- ----------------------------------------------------------------------------
-- RPCs commit y sync: solo columnas del DUMP QuoteLines (snapshots + msrp + total_cost)
-- Sin unit_*, accessories_*_snapshot, labor_*_snapshot, product_type_id, dealer_id, fabric_drop, installation_*
-- ----------------------------------------------------------------------------
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
)
RETURNS TABLE(quote_line_id uuid, bom_instance_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
  v_unit_msrp numeric(12,4);
  v_unit_cost numeric(12,4);
  v_product_type_code text;
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

  v_line_quantity := GREATEST(COALESCE(v_cp.quantity, 1), 1);
  v_width_m := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m := COALESCE(v_cp.height_mm / 1000.0, 0);
  v_operating_type := COALESCE(v_cp.config_snapshot->>'operating_type', v_cp.config_snapshot->>'drive_type', v_cp.config_snapshot->>'operation_type');

  -- Unit MSRP/cost desde CP (product subtotal + labor); totales de línea = unit * quantity
  v_unit_msrp := COALESCE(v_cp.total_msrp, 0);
  v_unit_cost := COALESCE(v_cp.unit_product_cost_landed, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  IF v_unit_cost = 0 THEN
    v_unit_cost := COALESCE(v_cp.roll_total_cost_landed, 0) + COALESCE(v_cp.bom_total_cost_landed, 0) + COALESCE(v_cp.accessories_total_cost_landed, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  END IF;

  SELECT pt.code INTO v_product_type_code
  FROM public."ProductTypes" pt
  WHERE pt.id = v_cp.product_type_id
  LIMIT 1;

  SELECT ci.sku, ci.name, ci.category_id, ci.manufacturer_id, m.name AS manufacturer_name,
         ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_m
  INTO v_roll_item
  FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id
    AND ci.is_active = true
  LIMIT 1;

  INSERT INTO public."QuoteLines" (
    organization_id, quote_id, dealer_id,
    configured_product_id, bom_template_id,
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer, collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity,
    hardware_color, drive_type, position, area, fabric_drop,
    roll_msrp_snapshot, bom_msrp_snapshot, roll_cost_snapshot, bom_cost_snapshot,
    msrp, total_cost,
    pricing_locked, last_priced_at, pricing_version,
    product_type, product_type_id
  )
  VALUES (
    p_org_id, p_quote_id, (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1),
    v_cp.id, v_cp.bom_template_id,
    v_cp.roll_catalog_item_id, COALESCE(v_cp.roll_sku, v_roll_item.sku), v_roll_item.name, v_roll_item.category_id, v_roll_item.manufacturer_id, v_roll_item.manufacturer_name,
    COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name), COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name),
    v_cp.roll_catalog_item_id IS NOT NULL, CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END, COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    v_width_m, v_height_m, v_line_quantity,
    v_cp.hardware_color, v_operating_type, p_position, p_area, COALESCE(p_fabric_drop, v_cp.config_snapshot->>'fabricDrop', v_cp.config_snapshot->>'drop_type'),
    COALESCE(v_cp.roll_msrp_total, 0), COALESCE(v_cp.bom_total, 0),
    COALESCE(v_cp.roll_total_cost_landed, 0), COALESCE(v_cp.bom_total_cost_landed, 0),
    ROUND(v_unit_msrp * v_line_quantity, 2), ROUND(v_unit_cost * v_line_quantity, 2),
    true, now(), 1,
    v_product_type_code, v_cp.product_type_id
  )
  RETURNING id INTO v_quote_line_id;

  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_quote_line_pricing_from_configured_product(p_quote_line_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql RECORD;
  v_cp RECORD;
  v_qty numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_unit_cost numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required';
  END IF;

  SELECT id, organization_id, configured_product_id, quantity
  INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;
  IF v_ql.configured_product_id IS NULL THEN
    RETURN;
  END IF;

  PERFORM public.calculate_configured_product_totals(v_ql.configured_product_id);

  SELECT *
  INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = v_ql.configured_product_id
    AND organization_id = v_ql.organization_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found for QuoteLine %', v_ql.configured_product_id, p_quote_line_id;
  END IF;

  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);
  v_unit_msrp := COALESCE(v_cp.total_msrp, 0);
  v_unit_cost := COALESCE(v_cp.unit_product_cost_landed, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  IF v_unit_cost = 0 THEN
    v_unit_cost := COALESCE(v_cp.roll_total_cost_landed, 0) + COALESCE(v_cp.bom_total_cost_landed, 0) + COALESCE(v_cp.accessories_total_cost_landed, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  END IF;

  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  -- Solo snapshots + msrp + total_cost (columnas del DUMP)
  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot = COALESCE(v_cp.roll_msrp_total, 0),
    bom_msrp_snapshot = COALESCE(v_cp.bom_total, 0),
    roll_cost_snapshot = COALESCE(v_cp.roll_total_cost_landed, 0),
    bom_cost_snapshot = COALESCE(v_cp.bom_total_cost_landed, 0),
    msrp = ROUND(v_unit_msrp * v_qty, 2),
    total_cost = ROUND(v_unit_cost * v_qty, 2),
    last_priced_at = now(),
    pricing_version = COALESCE(pricing_version, 0) + 1,
    pricing_locked = true
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;
