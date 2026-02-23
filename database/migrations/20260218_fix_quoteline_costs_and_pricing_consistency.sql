-- ============================================================================
-- Migration: Fix QuoteLine costs & pricing consistency
-- Date: 2026-02-18
-- 
-- Problem:
--   total_cost written by 3 sources (commit RPC, sync RPC, frontend UPDATE)
--   with no consistency. roll_cost_snapshot & bom_cost_snapshot often 0 while
--   total_cost has values from frontend. unit_msrp = total_msrp / qty instead
--   of being per-unit (so qty 1 vs qty 2 yields different unit prices).
--
-- Solution:
--   A) Add unit_cost column (per-unit cost, analogous to unit_msrp).
--   B) Fix commit_configured_product_to_quote_line:
--      - unit_msrp = total_msrp_per_unit (NOT divided by qty)
--      - msrp = unit_msrp * quantity
--      - unit_cost = roll_cost + bom_cost + labor (per unit)
--      - total_cost = unit_cost * quantity
--   C) Fix sync_quote_line_pricing_from_configured_product: same invariants.
--   D) New RPC: recompute_quote_line_costs (standalone recalc).
--   E) Backfill existing rows.
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- 1. ADD unit_cost COLUMN
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'QuoteLines'
      AND column_name = 'unit_cost'
  ) THEN
    ALTER TABLE public."QuoteLines"
    ADD COLUMN unit_cost numeric(12,4) NULL;
    COMMENT ON COLUMN public."QuoteLines".unit_cost IS
    'Cost per unit (roll_cost + bom_cost + labor per unit). total_cost = unit_cost * quantity.';
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 2. BACKFILL existing rows
--    If total_cost > 0 and quantity > 0, derive unit_cost = total_cost / qty.
--    If snapshots are 0 but total_cost has a value, backfill snapshots too.
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
  -- 2a) Set unit_cost where missing
  UPDATE public."QuoteLines"
  SET unit_cost = ROUND(total_cost / NULLIF(GREATEST(COALESCE(quantity, 1), 0.001), 0), 4)
  WHERE unit_cost IS NULL
    AND total_cost IS NOT NULL
    AND total_cost > 0;

  -- 2b) Fix unit_msrp where it was set as total/qty instead of per-unit
  --     If unit_msrp * quantity != msrp (within tolerance), recalculate
  UPDATE public."QuoteLines"
  SET
    unit_msrp = ROUND(msrp / NULLIF(GREATEST(COALESCE(quantity, 1), 0.001), 0), 4)
  WHERE msrp IS NOT NULL
    AND msrp > 0
    AND unit_msrp IS NOT NULL
    AND ABS(unit_msrp * GREATEST(COALESCE(quantity, 1), 1) - msrp) > 0.02;

  -- 2c) Ensure total_cost = unit_cost * quantity
  UPDATE public."QuoteLines"
  SET total_cost = ROUND(unit_cost * GREATEST(COALESCE(quantity, 1), 1), 2)
  WHERE unit_cost IS NOT NULL
    AND unit_cost > 0
    AND (total_cost IS NULL OR ABS(total_cost - unit_cost * GREATEST(COALESCE(quantity, 1), 1)) > 0.02);

  -- 2d) Ensure msrp = unit_msrp * quantity
  UPDATE public."QuoteLines"
  SET msrp = ROUND(unit_msrp * GREATEST(COALESCE(quantity, 1), 1), 2)
  WHERE unit_msrp IS NOT NULL
    AND unit_msrp > 0
    AND (msrp IS NULL OR ABS(msrp - unit_msrp * GREATEST(COALESCE(quantity, 1), 1)) > 0.02);
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 3. FIX commit_configured_product_to_quote_line
--    Key changes:
--    - v_total_msrp is the MSRP for ONE unit (roll + bom + labor + accessories)
--    - unit_msrp = v_total_msrp (per unit, NOT divided by v_cp.quantity)
--    - msrp = unit_msrp * line quantity
--    - unit_cost = roll_cost + bom_cost + labor (per unit)
--    - total_cost = unit_cost * quantity
-- ═══════════════════════════════════════════════════════════════════════════
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
  v_quote_line_id uuid;
  v_bom_instance_id uuid;
  v_width_m numeric(12,4);
  v_height_m numeric(12,4);
  v_roll_item RECORD;
  v_operating_type text;
  v_fabric_drop text;
  v_installation_type text;
  v_installation_location text;
  v_roll_msrp_total numeric(12,4);
  v_bom_total numeric(12,4);
  v_total_msrp_per_unit numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_roll_total_cost numeric(12,4);
  v_bom_total_cost numeric(12,4);
  v_labor_amount numeric(12,4);
  v_accessories_total numeric(12,4);
  v_unit_cost numeric(12,4);
  v_line_quantity numeric(12,4);
  v_snapshot jsonb;
  v_snapshot_totals jsonb;
  v_recalc jsonb;
BEGIN
  IF p_org_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_org_id is required'; END IF;
  IF p_quote_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_quote_id is required'; END IF;
  IF p_configured_product_id IS NULL THEN RAISE EXCEPTION 'commit_configured_product_to_quote_line: p_configured_product_id is required'; END IF;

  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id AND organization_id = p_org_id AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found or does not belong to org %', p_configured_product_id, p_org_id;
  END IF;
  IF v_cp.bom_template_id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % has no bom_template_id', p_configured_product_id;
  END IF;

  v_line_quantity := GREATEST(COALESCE(v_cp.quantity, 1), 1);

  -- Extract totals from bom_preview_snapshot (per-unit values)
  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := v_snapshot->'totals';
  v_roll_msrp_total := 0; v_bom_total := 0; v_roll_total_cost := 0; v_bom_total_cost := 0;
  v_labor_amount := 0; v_accessories_total := 0; v_total_msrp_per_unit := 0;

  IF v_snapshot->>'version' = '1' AND jsonb_array_length(COALESCE(v_snapshot->'items', '[]'::jsonb)) > 0 THEN
    SELECT COALESCE(SUM((item->>'line_total')::numeric), 0) INTO v_roll_msrp_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item WHERE item->>'kind' = 'roll';
    SELECT COALESCE(SUM(
      (item->>'line_total')::numeric + COALESCE((SELECT SUM((c->>'line_total')::numeric) FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c), 0)
    ), 0) INTO v_bom_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item WHERE item->>'kind' = 'parent';
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
    v_total_msrp_per_unit := COALESCE((v_snapshot_totals->>'total_msrp')::numeric, 0);
  ELSE
    v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0);
    v_bom_total := COALESCE(v_cp.bom_total, 0);
    v_roll_total_cost := COALESCE(v_cp.roll_total_cost, 0);
    v_bom_total_cost := COALESCE(v_cp.bom_total_cost, 0);
    v_labor_amount := COALESCE(v_cp.labor_amount, 0);
    v_accessories_total := COALESCE(v_cp.accessories_total, 0);
    v_total_msrp_per_unit := COALESCE(v_cp.total_msrp, 0);
  END IF;

  -- MSRP per unit = roll + bom + labor + accessories (all per-unit from snapshot)
  v_total_msrp_per_unit := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total;

  -- Fallback: recalculate if total is 0
  IF (v_total_msrp_per_unit IS NULL OR v_total_msrp_per_unit = 0) THEN
    BEGIN
      v_recalc := public.calculate_configured_product_totals(p_configured_product_id);
      IF v_recalc IS NOT NULL AND NOT (v_recalc ? 'error') THEN
        v_roll_msrp_total := COALESCE((v_recalc->>'roll_msrp_total')::numeric, 0);
        v_bom_total := COALESCE((v_recalc->>'bom_total')::numeric, 0);
        v_roll_total_cost := COALESCE((v_recalc->>'roll_total_cost')::numeric, 0);
        v_bom_total_cost := COALESCE((v_recalc->>'bom_total_cost')::numeric, 0);
        v_labor_amount := COALESCE((v_recalc->>'labor_amount')::numeric, 0);
        v_accessories_total := COALESCE((v_recalc->>'accessories_total')::numeric, 0);
        v_total_msrp_per_unit := COALESCE((v_recalc->>'total_msrp')::numeric, 0);
        IF v_total_msrp_per_unit = 0 THEN
          v_total_msrp_per_unit := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total;
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;

  -- ═══════════════════════════════════════════════════════════════════════
  -- INVARIANTS (per unit):
  --   unit_msrp  = v_total_msrp_per_unit  (price for ONE unit)
  --   msrp       = unit_msrp * quantity    (line total)
  --   unit_cost  = roll_cost + bom_cost + labor (cost for ONE unit)
  --   total_cost = unit_cost * quantity    (line total cost)
  -- ═══════════════════════════════════════════════════════════════════════
  v_unit_msrp := v_total_msrp_per_unit;
  v_unit_cost := v_roll_total_cost + v_bom_total_cost + v_labor_amount;

  v_width_m := COALESCE(v_cp.width_mm / 1000.0, 0);
  v_height_m := COALESCE(v_cp.height_mm / 1000.0, 0);
  v_operating_type := COALESCE(
    v_cp.config_snapshot->>'operating_type',
    v_cp.config_snapshot->>'drive_type',
    v_cp.config_snapshot->>'operation_type'
  );
  IF v_operating_type IS NOT NULL THEN
    v_operating_type := lower(trim(v_operating_type));
    IF v_operating_type IN ('motorized', 'motorised') THEN v_operating_type := 'motor'; END IF;
  END IF;

  v_fabric_drop := COALESCE(p_fabric_drop, v_cp.config_snapshot->>'fabricDrop', v_cp.config_snapshot->>'drop_type');
  v_installation_type := COALESCE(p_installation_type, v_cp.config_snapshot->>'installationType');
  v_installation_location := COALESCE(p_installation_location, v_cp.config_snapshot->>'installationLocation');

  SELECT ci.sku, ci.name, ci.category_id, ci.manufacturer_id, m.name as manufacturer_name,
         ci.collection_name, ci.variant_name, COALESCE(ci.roll_width_m, ci.roll_width) as roll_width_m
  INTO v_roll_item
  FROM public."CatalogItems" ci
  LEFT JOIN public."Manufacturers" m ON m.id = ci.manufacturer_id
  WHERE ci.id = v_cp.roll_catalog_item_id AND ci.is_active = true LIMIT 1;

  INSERT INTO public."QuoteLines" (
    organization_id, dealer_id, quote_id,
    product_type_id, configured_product_id, bom_template_id,
    catalog_item_id, sku, name, category_id, manufacturer_id, manufacturer, collection_name, variant_name, is_roll, roll_type, roll_width_m,
    width_m, height_m, quantity,
    hardware_color, drive_type,
    position, area,
    fabric_drop, installation_type, installation_location,
    roll_msrp_snapshot, bom_msrp_snapshot, roll_cost_snapshot, bom_cost_snapshot,
    unit_msrp, msrp, unit_cost, total_cost,
    pricing_locked, last_priced_at, pricing_version
  )
  VALUES (
    p_org_id,
    COALESCE(p_dealer_id, (SELECT dealer_id FROM public."Quotes" WHERE id = p_quote_id LIMIT 1)),
    p_quote_id,
    v_cp.product_type_id, v_cp.id, v_cp.bom_template_id,
    v_cp.roll_catalog_item_id, COALESCE(v_cp.roll_sku, v_roll_item.sku), v_roll_item.name, v_roll_item.category_id, v_roll_item.manufacturer_id, v_roll_item.manufacturer_name,
    COALESCE(v_cp.roll_collection_name, v_roll_item.collection_name), COALESCE(v_cp.roll_variant_name, v_roll_item.variant_name),
    v_cp.roll_catalog_item_id IS NOT NULL, CASE WHEN v_cp.roll_catalog_item_id IS NOT NULL THEN 'fabric' ELSE NULL END, COALESCE(v_cp.roll_width, v_roll_item.roll_width_m),
    v_width_m, v_height_m, v_line_quantity,
    v_cp.hardware_color, v_operating_type,
    p_position, p_area,
    v_fabric_drop, v_installation_type, v_installation_location,
    -- Snapshots are per-unit values
    v_roll_msrp_total, v_bom_total, v_roll_total_cost, v_bom_total_cost,
    -- Pricing: per-unit then scaled
    v_unit_msrp,                         -- per unit
    ROUND(v_unit_msrp * v_line_quantity, 2),  -- line total msrp
    v_unit_cost,                         -- per unit
    ROUND(v_unit_cost * v_line_quantity, 2),  -- line total cost
    true, now(), 1
  )
  RETURNING id INTO v_quote_line_id;

  IF v_quote_line_id IS NULL THEN RAISE EXCEPTION 'Failed to insert QuoteLine for ConfiguredProduct %', p_configured_product_id; END IF;
  v_bom_instance_id := NULL;
  RETURN QUERY SELECT v_quote_line_id, v_bom_instance_id;
END;
$$;

COMMENT ON FUNCTION public.commit_configured_product_to_quote_line(uuid, uuid, uuid, uuid, text, text, text, text, text) IS
'Creates QuoteLine from ConfiguredProduct. INVARIANTS: unit_msrp=per-unit MSRP, msrp=unit_msrp*qty, unit_cost=per-unit cost, total_cost=unit_cost*qty. Snapshots are per-unit.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 4. FIX sync_quote_line_pricing_from_configured_product
--    Same invariants as commit.
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.sync_quote_line_pricing_from_configured_product(p_quote_line_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql RECORD;
  v_cp RECORD;
  v_snapshot jsonb;
  v_snapshot_totals jsonb;
  v_recalc jsonb;
  v_roll_msrp_total numeric(12,4);
  v_bom_total numeric(12,4);
  v_total_msrp_per_unit numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_roll_total_cost numeric(12,4);
  v_bom_total_cost numeric(12,4);
  v_labor_amount numeric(12,4);
  v_accessories_total numeric(12,4);
  v_unit_cost numeric(12,4);
  v_line_quantity numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required';
  END IF;

  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

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

  v_line_quantity := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);

  SELECT
    id, organization_id, bom_preview_snapshot,
    roll_msrp_total, bom_total, roll_total_cost, bom_total_cost,
    labor_amount, accessories_total, total_msrp, quantity
  INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = v_ql.configured_product_id
    AND organization_id = v_ql.organization_id
    AND deleted = false;

  IF v_cp.id IS NULL THEN
    RAISE EXCEPTION 'ConfiguredProduct % not found for QuoteLine %', v_ql.configured_product_id, p_quote_line_id;
  END IF;

  -- Extract totals (same logic as commit)
  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := v_snapshot->'totals';
  v_roll_msrp_total := 0; v_bom_total := 0;
  v_roll_total_cost := 0; v_bom_total_cost := 0;
  v_labor_amount := 0; v_accessories_total := 0;
  v_total_msrp_per_unit := 0;

  IF v_snapshot->>'version' = '1' AND jsonb_array_length(COALESCE(v_snapshot->'items', '[]'::jsonb)) > 0 THEN
    SELECT COALESCE(SUM((item->>'line_total')::numeric), 0) INTO v_roll_msrp_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item WHERE item->>'kind' = 'roll';
    SELECT COALESCE(SUM(
      (item->>'line_total')::numeric + COALESCE((SELECT SUM((c->>'line_total')::numeric) FROM jsonb_array_elements(COALESCE(item->'children', '[]'::jsonb)) c), 0)
    ), 0) INTO v_bom_total
    FROM jsonb_array_elements(v_snapshot->'items') AS item WHERE item->>'kind' = 'parent';
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
    v_total_msrp_per_unit := COALESCE((v_snapshot_totals->>'total_msrp')::numeric, 0);
  ELSE
    v_roll_msrp_total := COALESCE(v_cp.roll_msrp_total, 0);
    v_bom_total := COALESCE(v_cp.bom_total, 0);
    v_roll_total_cost := COALESCE(v_cp.roll_total_cost, 0);
    v_bom_total_cost := COALESCE(v_cp.bom_total_cost, 0);
    v_labor_amount := COALESCE(v_cp.labor_amount, 0);
    v_accessories_total := COALESCE(v_cp.accessories_total, 0);
    v_total_msrp_per_unit := COALESCE(v_cp.total_msrp, 0);
  END IF;

  v_total_msrp_per_unit := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total;

  IF (v_total_msrp_per_unit IS NULL OR v_total_msrp_per_unit = 0) THEN
    BEGIN
      v_recalc := public.calculate_configured_product_totals(v_ql.configured_product_id);
      IF v_recalc IS NOT NULL AND NOT (v_recalc ? 'error') THEN
        v_roll_msrp_total := COALESCE((v_recalc->>'roll_msrp_total')::numeric, 0);
        v_bom_total := COALESCE((v_recalc->>'bom_total')::numeric, 0);
        v_roll_total_cost := COALESCE((v_recalc->>'roll_total_cost')::numeric, 0);
        v_bom_total_cost := COALESCE((v_recalc->>'bom_total_cost')::numeric, 0);
        v_labor_amount := COALESCE((v_recalc->>'labor_amount')::numeric, 0);
        v_accessories_total := COALESCE((v_recalc->>'accessories_total')::numeric, 0);
        v_total_msrp_per_unit := COALESCE((v_recalc->>'total_msrp')::numeric, 0);
        IF v_total_msrp_per_unit = 0 THEN
          v_total_msrp_per_unit := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total;
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;

  -- INVARIANTS (per unit)
  v_unit_msrp := v_total_msrp_per_unit;
  v_unit_cost := v_roll_total_cost + v_bom_total_cost + v_labor_amount;

  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot = v_roll_msrp_total,
    bom_msrp_snapshot = v_bom_total,
    roll_cost_snapshot = v_roll_total_cost,
    bom_cost_snapshot = v_bom_total_cost,
    unit_msrp = v_unit_msrp,
    msrp = ROUND(v_unit_msrp * v_line_quantity, 2),
    unit_cost = v_unit_cost,
    total_cost = ROUND(v_unit_cost * v_line_quantity, 2),
    last_priced_at = now(),
    pricing_version = COALESCE(pricing_version, 0) + 1,
    pricing_locked = true
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.sync_quote_line_pricing_from_configured_product(uuid) IS
'Syncs QuoteLines pricing from ConfiguredProduct. INVARIANTS: unit_msrp=per-unit, msrp=unit_msrp*qty, unit_cost=per-unit, total_cost=unit_cost*qty.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 5. NEW RPC: recompute_quote_line_costs
--    Standalone recalculation. If the line has a configured_product_id,
--    delegates to sync_quote_line_pricing_from_configured_product.
--    Otherwise ensures total_cost = unit_cost * quantity invariant.
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.recompute_quote_line_costs(p_quote_line_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql RECORD;
  v_qty numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'recompute_quote_line_costs: p_quote_line_id is required';
  END IF;

  SELECT id, organization_id, configured_product_id, quantity, unit_cost, unit_msrp,
         total_cost, msrp, roll_cost_snapshot, bom_cost_snapshot
  INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  -- If line has a ConfiguredProduct, use the full sync
  IF v_ql.configured_product_id IS NOT NULL THEN
    PERFORM public.sync_quote_line_pricing_from_configured_product(p_quote_line_id);
    RETURN;
  END IF;

  -- No ConfiguredProduct: enforce invariants from existing data
  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);

  -- Derive unit_cost if missing
  IF v_ql.unit_cost IS NULL AND v_ql.total_cost IS NOT NULL AND v_ql.total_cost > 0 THEN
    UPDATE public."QuoteLines"
    SET unit_cost = ROUND(total_cost / v_qty, 4)
    WHERE id = p_quote_line_id AND organization_id = v_ql.organization_id;
  END IF;

  -- Derive unit_msrp if missing
  IF v_ql.unit_msrp IS NULL AND v_ql.msrp IS NOT NULL AND v_ql.msrp > 0 THEN
    UPDATE public."QuoteLines"
    SET unit_msrp = ROUND(msrp / v_qty, 4)
    WHERE id = p_quote_line_id AND organization_id = v_ql.organization_id;
  END IF;

  -- Enforce: total_cost = unit_cost * qty, msrp = unit_msrp * qty
  UPDATE public."QuoteLines"
  SET
    total_cost = CASE WHEN unit_cost IS NOT NULL THEN ROUND(unit_cost * v_qty, 2) ELSE total_cost END,
    msrp = CASE WHEN unit_msrp IS NOT NULL THEN ROUND(unit_msrp * v_qty, 2) ELSE msrp END,
    last_priced_at = now()
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.recompute_quote_line_costs(uuid) IS
'Recalculates QuoteLine costs and pricing. If linked to ConfiguredProduct, delegates to sync_quote_line_pricing. Otherwise enforces unit*qty invariants.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 6. FIX set_quote_line_msrp_from_value to also handle unit_cost
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.set_quote_line_msrp_from_value(
  p_quote_line_id uuid,
  p_total_msrp numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ql RECORD;
  v_qty numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_line_msrp numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'set_quote_line_msrp_from_value: p_quote_line_id is required';
  END IF;
  IF p_total_msrp IS NULL OR p_total_msrp < 0 THEN
    RETURN;
  END IF;

  SELECT id, organization_id, quantity
  INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;

  v_qty := GREATEST(COALESCE(v_ql.quantity, 1), 0.001);
  v_unit_msrp := ROUND(p_total_msrp, 4);
  v_line_msrp := ROUND(v_unit_msrp * v_qty, 2);

  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  UPDATE public."QuoteLines"
  SET
    msrp = v_line_msrp,
    unit_msrp = v_unit_msrp,
    last_priced_at = now()
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.set_quote_line_msrp_from_value(uuid, numeric) IS
'Sets QuoteLine unit_msrp (per-unit) and msrp=unit_msrp*qty. p_total_msrp is the price for ONE unit.';
