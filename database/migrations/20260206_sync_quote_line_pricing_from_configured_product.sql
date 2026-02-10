-- ============================================================================
-- Migration: sync_quote_line_pricing_from_configured_product
-- Date: 2026-02-06
-- Description:
--   EDIT flow: after updating QuoteLines.configured_product_id to CP_NEW,
--   sync pricing fields from ConfiguredProducts (same source as ADD uses via
--   commit_configured_product_to_quote_line). compute_quote_line_cost does NOT
--   update QuoteLines.msrp/unit_msrp/snapshots; this RPC does.
-- ============================================================================

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
  v_total_msrp numeric(12,4);
  v_unit_msrp numeric(12,4);
  v_roll_total_cost numeric(12,4);
  v_bom_total_cost numeric(12,4);
  v_labor_amount numeric(12,4);
  v_accessories_total numeric(12,4);
  v_line_quantity numeric(12,4);
BEGIN
  IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'sync_quote_line_pricing_from_configured_product: p_quote_line_id is required';
  END IF;

  -- Allow this session to update pricing columns (guard rail trigger)
  PERFORM set_config('app.allow_quote_line_pricing_update', 'true', true);

  -- a) Load QuoteLine
  SELECT id, organization_id, configured_product_id, quantity
  INTO v_ql
  FROM public."QuoteLines"
  WHERE id = p_quote_line_id;

  IF v_ql.id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine % not found', p_quote_line_id;
  END IF;
  IF v_ql.configured_product_id IS NULL THEN
    RETURN; -- nothing to sync
  END IF;

  v_line_quantity := NULLIF(GREATEST(COALESCE(v_ql.quantity, 1), 0.001), 0);

  -- b) Load ConfiguredProducts
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

  -- c) Same totals logic as commit_configured_product_to_quote_line
  v_snapshot := COALESCE(v_cp.bom_preview_snapshot, '{}'::jsonb);
  v_snapshot_totals := v_snapshot->'totals';
  v_roll_msrp_total := 0;
  v_bom_total := 0;
  v_roll_total_cost := 0;
  v_bom_total_cost := 0;
  v_labor_amount := 0;
  v_accessories_total := 0;
  v_total_msrp := 0;

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
      v_recalc := public.calculate_configured_product_totals(v_ql.configured_product_id);
      IF v_recalc IS NOT NULL AND NOT (v_recalc ? 'error') THEN
        v_roll_msrp_total := COALESCE((v_recalc->>'roll_msrp_total')::numeric, 0);
        v_bom_total := COALESCE((v_recalc->>'bom_total')::numeric, 0);
        v_roll_total_cost := COALESCE((v_recalc->>'roll_total_cost')::numeric, 0);
        v_bom_total_cost := COALESCE((v_recalc->>'bom_total_cost')::numeric, 0);
        v_labor_amount := COALESCE((v_recalc->>'labor_amount')::numeric, 0);
        v_accessories_total := COALESCE((v_recalc->>'accessories_total')::numeric, 0);
        v_total_msrp := COALESCE((v_recalc->>'total_msrp')::numeric, 0);
        IF v_total_msrp = 0 THEN
          v_total_msrp := v_roll_msrp_total + v_bom_total + v_labor_amount + v_accessories_total;
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END IF;

  -- d) unit_msrp = total per unit; msrp = unit_msrp * line quantity (line total)
  v_unit_msrp := v_total_msrp / NULLIF(COALESCE(v_cp.quantity, 1), 0);
  v_total_msrp := v_unit_msrp * v_line_quantity;

  -- e) Update QuoteLines with same fields as commit_configured_product_to_quote_line
  UPDATE public."QuoteLines"
  SET
    roll_msrp_snapshot = v_roll_msrp_total,
    bom_msrp_snapshot = v_bom_total,
    roll_cost_snapshot = v_roll_total_cost,
    bom_cost_snapshot = v_bom_total_cost,
    unit_msrp = v_unit_msrp,
    msrp = v_total_msrp,
    total_cost = v_roll_total_cost + v_bom_total_cost + v_labor_amount,
    last_priced_at = now(),
    pricing_version = COALESCE(pricing_version, 0) + 1,
    pricing_locked = true
  WHERE id = p_quote_line_id
    AND organization_id = v_ql.organization_id;
END;
$$;

COMMENT ON FUNCTION public.sync_quote_line_pricing_from_configured_product(uuid) IS
'Syncs QuoteLines pricing (msrp, unit_msrp, snapshots, total_cost) from its configured_product_id. Use after EDIT when QuoteLine is pointed to CP_NEW. Same source as commit_configured_product_to_quote_line.';
