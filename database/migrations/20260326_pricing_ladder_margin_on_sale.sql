-- ============================================================================
-- 2026-03-26
-- Pricing ladder stabilization (future-only, no backfill)
--
-- COST -> DEALER -> MSRP
--   materials_cost   = roll_cost + bom_cost + accessories_cost
--   labor_cost       = materials_cost * labor_pct
--   total_cost       = materials_cost + labor_cost
--   unit_dealer_price= total_cost / (1 - minimum_margin_pct)
--   unit_msrp        = unit_dealer_price / (1 - default_msrp_pct)
--
-- Notes:
-- - "Dealer Discount" is not part of this formula.
-- - MSRP margin is margin-on-sale.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.calculate_configured_product_totals(
  p_configured_product_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_cp RECORD;
  v_cs RECORD;
  v_snapshot jsonb;
  v_totals jsonb;
  v_qty numeric := 1;

  v_roll_msrp_total numeric := 0;
  v_bom_total numeric := 0;
  v_accessories_total numeric := 0;
  v_msrp_product_subtotal numeric := 0;
  v_unit_msrp_total numeric := 0;
  v_labor_msrp numeric := 0;

  v_roll_cost numeric := 0;
  v_bom_cost numeric := 0;
  v_accessories_cost numeric := 0;
  v_materials_cost numeric := 0;
  v_labor_cost numeric := 0;
  v_total_cost numeric := 0;

  v_labor_pct numeric := 0;
  v_minimum_margin_pct numeric := 0.35;
  v_msrp_margin_pct numeric := 0.65;
  v_dealer_factor numeric := 0.65;
  v_msrp_factor numeric := 0.35;

  v_unit_dealer_price numeric := 0;
  v_dealer_price_total numeric := 0;
  v_msrp_total numeric := 0;
BEGIN
  SELECT * INTO v_cp
  FROM public."ConfiguredProducts"
  WHERE id = p_configured_product_id
    AND deleted = false;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'ConfiguredProduct not found');
  END IF;

  SELECT
    cs.labor_pct,
    cs.minimum_margin_pct,
    cs.default_msrp_pct
  INTO v_cs
  FROM public."CostSettings" cs
  WHERE cs.organization_id = v_cp.organization_id
    AND COALESCE(cs.is_active, true)
  ORDER BY cs.created_at DESC
  LIMIT 1;

  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_totals := COALESCE(v_snapshot->'totals', '{}'::jsonb);
  v_qty := GREATEST(COALESCE(v_cp.quantity, 1), 1);

  -- MSRP subtotals (prefer snapshot, fallback CP columns)
  v_roll_msrp_total := COALESCE((v_totals->>'roll_msrp_total')::numeric, v_cp.roll_msrp_total, 0);
  v_bom_total := COALESCE((v_totals->>'bom_total')::numeric, v_cp.bom_total, 0);
  v_accessories_total := COALESCE((v_totals->>'accessories_total')::numeric, v_cp.accessories_total, 0);
  v_msrp_product_subtotal := v_roll_msrp_total + v_bom_total + v_accessories_total;

  -- Cost subtotals (prefer snapshot, fallback CP columns)
  v_roll_cost := COALESCE((v_totals->>'roll_total_cost')::numeric, v_cp.roll_total_cost, 0);
  v_bom_cost := COALESCE((v_totals->>'bom_total_cost')::numeric, v_cp.bom_total_cost, 0);
  v_accessories_cost := COALESCE((v_totals->>'accessories_total_cost')::numeric, v_cp.accessories_total_cost, 0);

  -- Cost inputs (decimals, not percentages)
  v_labor_pct := COALESCE(v_cs.labor_pct, v_cp.labor_pct, (v_totals->>'labor_pct')::numeric, 0);
  IF v_labor_pct > 1 THEN
    v_labor_pct := v_labor_pct / 100.0;
  END IF;
  v_labor_pct := GREATEST(0, v_labor_pct);

  v_minimum_margin_pct := COALESCE(v_cs.minimum_margin_pct, (v_totals->>'minimum_margin_pct')::numeric, 0.35);
  IF v_minimum_margin_pct > 1 THEN
    v_minimum_margin_pct := v_minimum_margin_pct / 100.0;
  END IF;
  v_minimum_margin_pct := LEAST(GREATEST(v_minimum_margin_pct, 0), 0.99);

  v_msrp_margin_pct := COALESCE(v_cs.default_msrp_pct, (v_totals->>'msrp_margin_pct')::numeric, (v_totals->>'default_msrp_pct')::numeric, 0.65);
  IF v_msrp_margin_pct > 1 THEN
    v_msrp_margin_pct := v_msrp_margin_pct / 100.0;
  END IF;
  v_msrp_margin_pct := LEAST(GREATEST(v_msrp_margin_pct, 0), 0.99);

  v_dealer_factor := GREATEST(0.01, 1 - v_minimum_margin_pct);
  v_msrp_factor := GREATEST(0.01, 1 - v_msrp_margin_pct);

  -- Cost -> Dealer -> MSRP
  v_materials_cost := ROUND(v_roll_cost + v_bom_cost + v_accessories_cost, 4);
  v_labor_cost := ROUND(v_materials_cost * v_labor_pct, 4);
  v_total_cost := ROUND(v_materials_cost + v_labor_cost, 4);

  v_unit_dealer_price := ROUND(v_total_cost / v_dealer_factor, 4);
  v_unit_msrp_total := ROUND(v_unit_dealer_price / v_msrp_factor, 4);
  v_msrp_total := ROUND(v_unit_msrp_total * v_qty, 4);
  v_dealer_price_total := ROUND(v_unit_dealer_price * v_qty, 4);

  -- Keep MSRP subtotal split and derive labor MSRP remainder for compatibility.
  v_labor_msrp := ROUND(GREATEST(0, v_unit_msrp_total - v_msrp_product_subtotal), 4);

  UPDATE public."ConfiguredProducts"
  SET
    roll_msrp_total = v_roll_msrp_total,
    bom_total = v_bom_total,
    accessories_total = v_accessories_total,
    msrp_product_subtotal = v_msrp_product_subtotal,
    labor_amount = v_labor_msrp,
    labor_msrp = v_labor_msrp,
    total_msrp = v_unit_msrp_total,
    unit_msrp_total = v_unit_msrp_total,
    roll_total_cost = v_roll_cost,
    bom_total_cost = v_bom_cost,
    accessories_total_cost = v_accessories_cost,
    unit_product_cost = v_materials_cost,
    unit_labor_cost = v_labor_cost,
    total_cost = v_total_cost,
    labor_pct = v_labor_pct,
    bom_preview_snapshot = jsonb_set(
      COALESCE(v_snapshot, '{}'::jsonb),
      '{totals}',
      jsonb_build_object(
        -- MSRP
        'roll_msrp_total', v_roll_msrp_total,
        'bom_total', v_bom_total,
        'accessories_total', v_accessories_total,
        'msrp_product_subtotal', v_msrp_product_subtotal,
        'labor_amount', v_labor_msrp,
        'labor_msrp', v_labor_msrp,
        'unit_msrp', v_unit_msrp_total,
        'unit_msrp_total', v_unit_msrp_total,
        'total_msrp', v_unit_msrp_total,
        'msrp_total', v_msrp_total,

        -- Costs
        'roll_cost', v_roll_cost,
        'roll_total_cost', v_roll_cost,
        'bom_cost', v_bom_cost,
        'bom_total_cost', v_bom_cost,
        'accessories_cost', v_accessories_cost,
        'accessories_total_cost', v_accessories_cost,
        'materials_cost', v_materials_cost,
        'unit_product_cost', v_materials_cost,
        'labor_cost', v_labor_cost,
        'unit_labor_cost', v_labor_cost,
        'total_cost', v_total_cost,

        -- Pricing ladder params and outputs
        'labor_pct', ROUND(v_labor_pct * 100, 4),
        'labor_cost_pct', ROUND(v_labor_pct * 100, 4),
        'minimum_margin_pct', ROUND(v_minimum_margin_pct * 100, 4),
        'msrp_margin_pct', ROUND(v_msrp_margin_pct * 100, 4),
        'default_msrp_pct', ROUND(v_msrp_margin_pct * 100, 4),
        'unit_dealer_price', v_unit_dealer_price,
        'dealer_price_total', v_dealer_price_total
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
    'msrp_total', v_msrp_total,
    'unit_dealer_price', v_unit_dealer_price,
    'dealer_price_total', v_dealer_price_total,
    'roll_cost', v_roll_cost,
    'bom_cost', v_bom_cost,
    'materials_cost', v_materials_cost,
    'labor_cost', v_labor_cost,
    'total_cost', v_total_cost,
    'labor_pct', v_labor_pct,
    'minimum_margin_pct', v_minimum_margin_pct,
    'msrp_margin_pct', v_msrp_margin_pct
  );
END;
$$;

COMMENT ON FUNCTION public.calculate_configured_product_totals(uuid) IS
'Pricing ladder: COST -> DEALER -> MSRP. unit_dealer_price = total_cost/(1-minimum_margin_pct). unit_msrp = unit_dealer_price/(1-default_msrp_pct). Future-only.';

COMMIT;
