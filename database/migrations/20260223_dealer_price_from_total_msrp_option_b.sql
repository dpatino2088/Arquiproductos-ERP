-- Migration: Dealer price from TOTAL MSRP (Option B)
-- Fix: Dealer price must use total_msrp (roll + bom + labor + accessories) * (1 - dealer_discount_pct).
-- NOT roll_msrp_total only.
--
-- resolve_dealer_discount_pct: Returns discount as 0-1 (e.g. 0.65 for 65% off).
-- calculate_configured_product_totals: Gets dealer_id from quote_id, uses total_msrp for unit_dealer_price.
-- sync_quote_line_pricing_from_configured_product: Uses totals.unit_dealer_price (already correct).

-- ─────────────────────────────────────────────────────────────────────────────
-- 0) resolve_dealer_discount_pct
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.resolve_dealer_discount_pct(
  p_org_id uuid,
  p_dealer_id uuid,
  p_product_type_id uuid DEFAULT NULL
) RETURNS numeric
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(
    (SELECT (dt.discount_pct / 100.0)::numeric
     FROM public."Dealers" d
     LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id AND dt.organization_id = p_org_id
     WHERE p_dealer_id IS NOT NULL AND d.id = p_dealer_id AND d.organization_id = p_org_id
     LIMIT 1),
    0.65
  );
$$;

COMMENT ON FUNCTION public.resolve_dealer_discount_pct(uuid, uuid, uuid) IS
'Returns dealer discount as 0-1 (0.65 = 65% off). Source: Dealers.dealer_tier_id -> DealerTiers.discount_pct. Fallback 0.65 if no config.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 1) calculate_configured_product_totals — dealer price from total_msrp
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
  v_bom_total numeric := 0;
  v_accessories_total numeric := 0;
  v_labor_msrp numeric := 0;
  v_msrp_product_subtotal numeric := 0;
  v_unit_msrp_total numeric := 0;
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
  v_dealer_id uuid;
  v_dealer_discount_pct numeric;
  v_unit_dealer_price numeric := 0;
  v_dealer_price_total numeric := 0;
  v_quantity numeric := 1;
  v_roll_dealer_total numeric := 0;
  v_bom_dealer_total numeric := 0;
  v_labor_dealer_total numeric := 0;
  v_accessories_dealer_total numeric := 0;
BEGIN
  SELECT * INTO v_cp FROM public."ConfiguredProducts" WHERE id = p_configured_product_id AND deleted = false;
  IF NOT FOUND THEN RETURN jsonb_build_object('error', 'ConfiguredProduct not found'); END IF;

  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := COALESCE(v_snapshot->'totals', '{}'::jsonb);
  v_quantity := GREATEST(COALESCE(v_cp.quantity, 1), 1);

  -- Dealer: cp.quote_id -> Quotes.dealer_id, or QuoteLines.quote_id when CP has no quote_id
  IF v_cp.quote_id IS NOT NULL THEN
    SELECT q.dealer_id INTO v_dealer_id FROM public."Quotes" q WHERE q.id = v_cp.quote_id LIMIT 1;
  END IF;
  IF v_dealer_id IS NULL THEN
    SELECT q.dealer_id INTO v_dealer_id
    FROM public."QuoteLines" ql
    JOIN public."Quotes" q ON q.id = ql.quote_id
    WHERE ql.configured_product_id = p_configured_product_id AND ql.deleted = false
    LIMIT 1;
  END IF;
  v_dealer_discount_pct := public.resolve_dealer_discount_pct(v_cp.organization_id, v_dealer_id, v_cp.product_type_id);

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
      END;
    END IF;
  END IF;

  v_bom_total := COALESCE((v_snapshot_totals->>'bom_total')::numeric, v_cp.bom_total, 0);
  v_accessories_total := COALESCE((v_snapshot_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);
  v_msrp_product_subtotal := v_roll_msrp_total;
  IF COALESCE(v_roll.msrp, 0) = 0 AND v_roll_msrp_total = 0 THEN
    v_labor_msrp := 0;
  ELSE
    v_labor_msrp := COALESCE(v_roll.labor_msrp, 0);
  END IF;
  IF v_labor_msrp = 0 AND COALESCE(v_cp.labor_pct, 0) > 0 THEN
    v_labor_msrp := (v_roll_msrp_total + v_bom_total + v_accessories_total)
      * CASE WHEN v_cp.labor_pct <= 1 THEN v_cp.labor_pct ELSE (v_cp.labor_pct / 100.0) END;
  END IF;
  v_unit_msrp_total := v_roll_msrp_total + v_labor_msrp + v_bom_total + v_accessories_total;

  -- Option B: unit_dealer_price = total_msrp * (1 - dealer_discount_pct). NO roll-only.
  v_unit_dealer_price := ROUND(v_unit_msrp_total * (1 - v_dealer_discount_pct), 4);
  v_dealer_price_total := ROUND(v_unit_dealer_price * v_quantity, 2);
  v_roll_dealer_total := ROUND(v_roll_msrp_total * (1 - v_dealer_discount_pct), 4);
  v_bom_dealer_total := ROUND(v_bom_total * (1 - v_dealer_discount_pct), 4);
  v_labor_dealer_total := ROUND(v_labor_msrp * (1 - v_dealer_discount_pct), 4);
  v_accessories_dealer_total := ROUND(v_accessories_total * (1 - v_dealer_discount_pct), 4);

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
        'roll_msrp_total', v_roll_msrp_total, 'bom_total', v_bom_total, 'accessories_total', v_accessories_total,
        'labor_pct', COALESCE(v_cp.labor_pct, (v_snapshot_totals->>'labor_pct')::numeric, 0),
        'labor_amount', v_labor_msrp, 'total_msrp', v_unit_msrp_total,
        'msrp_product_subtotal', v_msrp_product_subtotal, 'labor_msrp', v_labor_msrp,
        'unit_msrp_total', v_unit_msrp_total,
        'dealer_discount_pct', (v_dealer_discount_pct * 100),
        'unit_dealer_price', v_unit_dealer_price, 'dealer_price_total', v_dealer_price_total,
        'roll_dealer_total', v_roll_dealer_total, 'bom_dealer_total', v_bom_dealer_total,
        'labor_dealer_total', v_labor_dealer_total, 'accessories_dealer_total', v_accessories_dealer_total,
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
    'unit_dealer_price', v_unit_dealer_price, 'dealer_price_total', v_dealer_price_total, 'total_cost', v_total_cost);
END;
$_$;

COMMENT ON FUNCTION public.calculate_configured_product_totals(uuid) IS
'Dealer price from total_msrp * (1 - dealer_discount_pct). No roll-only. Source: cp.quote_id -> Quotes.dealer_id -> DealerTiers.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2) sync_quote_line_pricing_from_configured_product — use totals.unit_dealer_price
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

  -- Prefer unit_dealer_price from totals (Option B: total_msrp * (1-discount)); fallback to tier-based calc
  v_unit_dealer_price := (v_totals->>'unit_dealer_price')::numeric;
  IF v_unit_dealer_price IS NULL OR v_unit_dealer_price <= 0 THEN
    SELECT d.dealer_tier_id, dt.code, COALESCE(dt.discount_pct, 35)
    INTO v_dealer_tier_id, v_dealer_tier_code, v_discount_pct
    FROM public."Quotes" q JOIN public."Dealers" d ON d.id = q.dealer_id
    LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
    WHERE q.id = v_ql.quote_id LIMIT 1;
    IF v_discount_pct IS NULL THEN v_discount_pct := 35; END IF;
    v_unit_dealer_price := ROUND(v_unit_msrp * (1 - v_discount_pct / 100.0), 4);
  ELSE
    SELECT d.dealer_tier_id, dt.code, COALESCE(dt.discount_pct, 35)
    INTO v_dealer_tier_id, v_dealer_tier_code, v_discount_pct
    FROM public."Quotes" q JOIN public."Dealers" d ON d.id = q.dealer_id
    LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
    WHERE q.id = v_ql.quote_id LIMIT 1;
    IF v_discount_pct IS NULL THEN v_discount_pct := 35; END IF;
  END IF;

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
'Uses totals.unit_dealer_price (Option B: total_msrp * (1-discount)). Fallback: tier-based calc.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 3) create_configured_product_and_bom_preview — include unit_dealer_price in return
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_configured_product_and_bom_preview(
  p_org_id uuid, p_product_type_id uuid, p_config_snapshot jsonb,
  p_quote_id uuid DEFAULT NULL, p_quote_line_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_configured_product_id uuid; v_bom_template_id uuid; v_preview_snapshot jsonb; v_totals_after jsonb; v_snap_totals jsonb;
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

  SELECT bom_preview_snapshot INTO v_preview_snapshot FROM public."ConfiguredProducts" WHERE id = v_configured_product_id;
  v_snap_totals := COALESCE(v_preview_snapshot->'totals', '{}'::jsonb);
  SELECT jsonb_build_object(
    'roll_msrp_total', cp.roll_msrp_total, 'bom_total', cp.bom_total, 'accessories_total', cp.accessories_total,
    'labor_amount', cp.labor_amount, 'total_msrp', cp.total_msrp, 'msrp_product_subtotal', cp.msrp_product_subtotal,
    'labor_msrp', cp.labor_msrp, 'unit_msrp_total', cp.unit_msrp_total,
    'unit_dealer_price', (v_snap_totals->>'unit_dealer_price')::numeric,
    'dealer_price_total', (v_snap_totals->>'dealer_price_total')::numeric,
    'roll_total_cost', cp.roll_total_cost, 'bom_total_cost', cp.bom_total_cost,
    'accessories_total_cost', cp.accessories_total_cost, 'unit_product_cost', cp.unit_product_cost,
    'unit_labor_cost', cp.unit_labor_cost, 'total_cost', cp.total_cost
  ) INTO v_totals_after
  FROM public."ConfiguredProducts" cp WHERE cp.id = v_configured_product_id;

  RETURN jsonb_build_object('configured_product_id', v_configured_product_id, 'bom_instance_id', NULL,
    'bom_template_id', v_bom_template_id, 'totals', v_totals_after, 'bom_preview_snapshot', v_preview_snapshot);
END;
$$;

COMMENT ON FUNCTION public.create_configured_product_and_bom_preview(uuid, uuid, jsonb, uuid, uuid) IS
'Creates ConfiguredProduct. Totals include unit_dealer_price (Option B: total_msrp * (1-discount)).';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4) commit_configured_product_to_quote_line — FIX: use unit_product_cost (no _landed)
-- Error: record "v_cp" has no field "unit_product_cost_landed"
-- ─────────────────────────────────────────────────────────────────────────────
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
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
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
  v_effective_dealer_id uuid;
  v_dealer_tier_id uuid;
  v_dealer_tier_code text;
  v_discount_pct numeric(5,2);
  v_unit_dealer_price numeric(12,4);
  v_catalog_dealer_unit numeric(12,4);
  v_totals jsonb;
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

  v_totals := COALESCE(v_cp.bom_preview_snapshot->'totals', '{}'::jsonb);
  v_line_quantity := GREATEST(COALESCE(v_cp.quantity, 1), 1);
  v_width_m := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m := COALESCE(v_cp.height_mm / 1000.0, 0);
  v_operating_type := COALESCE(
    v_cp.config_snapshot->>'operating_type',
    v_cp.config_snapshot->>'drive_type',
    v_cp.config_snapshot->>'operation_type'
  );

  v_unit_msrp := COALESCE(v_cp.total_msrp, (v_totals->>'total_msrp')::numeric, 0);
  v_unit_cost := COALESCE(v_cp.unit_product_cost, 0) + COALESCE(v_cp.unit_labor_cost, 0);
  IF v_unit_cost = 0 THEN
    v_unit_cost := COALESCE((v_totals->>'total_cost')::numeric,
      COALESCE(v_cp.roll_total_cost, 0) + COALESCE(v_cp.bom_total_cost, 0)
        + COALESCE(v_cp.accessories_total_cost, 0) + COALESCE(v_cp.unit_labor_cost, 0), 0);
  END IF;

  v_effective_dealer_id := COALESCE(
    p_dealer_id,
    (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)
  );

  SELECT d.dealer_tier_id, dt.code, COALESCE(dt.discount_pct, 35)
  INTO v_dealer_tier_id, v_dealer_tier_code, v_discount_pct
  FROM public."Dealers" d
  LEFT JOIN public."DealerTiers" dt ON dt.id = d.dealer_tier_id
  WHERE d.id = v_effective_dealer_id
  LIMIT 1;

  IF v_discount_pct IS NULL THEN v_discount_pct := 35; END IF;

  -- Option B: prefer totals.unit_dealer_price; fallback total_msrp * (1 - discount)
  v_unit_dealer_price := (v_totals->>'unit_dealer_price')::numeric;
  IF v_unit_dealer_price IS NULL OR v_unit_dealer_price <= 0 THEN
    v_unit_dealer_price := ROUND(v_unit_msrp * (1 - v_discount_pct / 100.0), 4);
  END IF;

  SELECT cim.dealer_price INTO v_catalog_dealer_unit
  FROM public."CatalogItemsMSRP" cim
  WHERE cim.organization_id = p_org_id AND cim.catalog_item_id = v_cp.roll_catalog_item_id
  ORDER BY cim.updated_at DESC NULLS LAST LIMIT 1;

  SELECT pt.code INTO v_product_type_code
  FROM public."ProductTypes" pt
  WHERE pt.id = v_cp.product_type_id LIMIT 1;

  SELECT ci.sku, ci.name, ci.category_id, ci.manufacturer_id, m.name AS manufacturer_name,
         ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width) AS roll_width_m
  INTO v_roll_item
  FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id AND ci.is_active = true
  LIMIT 1;

  PERFORM set_config('app.write_source', 'rpc', true);

  INSERT INTO public."QuoteLines" (
    organization_id, quote_id, dealer_id,
    configured_product_id, bom_template_id,
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer,
    collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity,
    hardware_color, drive_type, position, area, fabric_drop,
    roll_msrp_snapshot, bom_msrp_snapshot,
    roll_cost_snapshot, bom_cost_snapshot,
    unit_msrp_total_snapshot, unit_cost_total_snapshot,
    msrp, total_cost,
    unit_dealer_price_snapshot, dealer_price_total, dealer_discount_pct,
    dealer_tier_id_snapshot, dealer_tier_code_snapshot,
    catalog_dealer_unit_snapshot, dealer_price_source,
    pricing_locked, last_priced_at, pricing_version,
    product_type, product_type_id
  )
  VALUES (
    p_org_id, p_quote_id, v_effective_dealer_id,
    v_cp.id, v_cp.bom_template_id,
    v_cp.roll_catalog_item_id,
    COALESCE(v_cp.roll_sku, v_roll_item.sku), v_roll_item.name,
    v_roll_item.category_id, v_roll_item.manufacturer_id, v_roll_item.manufacturer_name,
    COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name),
    COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name),
    v_cp.roll_catalog_item_id IS NOT NULL,
    CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END,
    COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    v_width_m, v_height_m, v_line_quantity,
    v_cp.hardware_color, v_operating_type, p_position, p_area,
    COALESCE(p_fabric_drop, v_cp.config_snapshot->>'fabricDrop', v_cp.config_snapshot->>'drop_type'),
    COALESCE(v_cp.roll_msrp_total, 0), COALESCE(v_cp.bom_total, 0),
    COALESCE(v_cp.roll_total_cost, 0), COALESCE(v_cp.bom_total_cost, 0),
    v_unit_msrp, v_unit_cost,
    ROUND(v_unit_msrp * v_line_quantity, 2),
    ROUND(v_unit_cost * v_line_quantity, 2),
    v_unit_dealer_price,
    ROUND(v_unit_dealer_price * v_line_quantity, 2),
    v_discount_pct,
    v_dealer_tier_id, v_dealer_tier_code,
    v_catalog_dealer_unit, 'tier',
    true, now(), 1,
    v_product_type_code, v_cp.product_type_id
  )
  RETURNING id INTO v_quote_line_id;

  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;

COMMENT ON FUNCTION public.commit_configured_product_to_quote_line(uuid, uuid, uuid, uuid, text, text, text, text, text) IS
'Creates QuoteLine from ConfiguredProduct. Uses unit_product_cost, roll_total_cost, bom_total_cost (no _landed). Dealer price from totals or total_msrp.';

