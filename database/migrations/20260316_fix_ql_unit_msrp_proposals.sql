-- ============================================================================
-- Migration: Fix ql.unit_msrp references in proposal functions
-- Date: 2026-03-16
-- Description:
--   QuoteLines canonical unit price column is unit_msrp_total_snapshot (20260301).
--   Column unit_msrp (20260205) may not exist in some DBs (per PRICING_DOCS_INDEX).
--   recalc_proposal_totals and freeze_proposal_snapshot referenced ql.unit_msrp,
--   causing "column ql.unit_msrp does not exist" when loading proposal/quote UI.
--   This migration replaces those references with unit_msrp_total_snapshot and
--   msrp/quantity fallback.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) recalc_proposal_totals: use unit_msrp_total_snapshot instead of unit_msrp
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recalc_proposal_totals(p_proposal_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
  v_status text;
  v_subtotal numeric(12,4) := 0;
  v_addons_total numeric(12,4) := 0;
  v_discount_pct numeric(12,6);
  v_discount_amount numeric(12,4) := 0;
  v_taxable_base numeric(12,4);
  v_itbms_pct numeric(7,4) := 0.07;
  v_itbms_amount numeric(12,4) := 0;
  v_total numeric(12,4);
BEGIN
  SELECT p.organization_id, p.status::text INTO v_org_id, v_status
  FROM public."Proposals" p
  WHERE p.id = p_proposal_id AND p.deleted = false;

  IF v_org_id IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(cs.itbms_pct, 0.07) INTO v_itbms_pct
  FROM public."CostSettings" cs
  WHERE cs.organization_id = v_org_id AND COALESCE(cs.is_active, true)
  ORDER BY cs.created_at DESC
  LIMIT 1;

  -- Material total from ProposalLines: use line_adjustment_pct (NOT override_mode)
  -- Base: prefer snapshot when status in (sent, accepted), else QuoteLines
  -- Use unit_msrp_total_snapshot (canonical); fallback to msrp/quantity. No unit_msrp.
  SELECT COALESCE(SUM(
    CASE
      WHEN pl.line_type = 'custom' THEN (COALESCE(pl.qty, 1) * COALESCE(pl.unit_price, 0))
      WHEN pl.line_type = 'from_quote' THEN (
        (
          CASE
            WHEN v_status IN ('sent','accepted')
                 AND pl.quote_line_snapshot IS NOT NULL
                 AND (pl.quote_line_snapshot->>'base_line_msrp') IS NOT NULL
            THEN COALESCE((pl.quote_line_snapshot->>'base_line_msrp')::numeric, 0)
            WHEN pl.quote_line_id IS NOT NULL THEN (
              SELECT COALESCE(
                ql.msrp,
                (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)),
                0
              )
              FROM public."QuoteLines" ql
              WHERE ql.id = pl.quote_line_id
              LIMIT 1
            )
            ELSE 0
          END
        ) * (1 + COALESCE(pl.line_adjustment_pct, 0) / 100.0)
      )
      ELSE 0
    END
  ), 0) INTO v_subtotal
  FROM public."ProposalLines" pl
  WHERE pl.proposal_id = p_proposal_id AND pl.deleted = false;

  -- Add-ons total
  SELECT COALESCE(SUM(ao.sale_amount), 0) INTO v_addons_total
  FROM public."ProposalLineAddOns" ao
  WHERE ao.proposal_id = p_proposal_id AND ao.deleted = false;

  v_subtotal := v_subtotal + v_addons_total;

  SELECT COALESCE(p.global_discount_pct, 0)
  INTO v_discount_pct
  FROM public."Proposals" p
  WHERE p.id = p_proposal_id;

  v_discount_amount := ROUND(v_subtotal * (v_discount_pct / 100.0), 2);
  v_taxable_base := GREATEST(v_subtotal - v_discount_amount, 0);
  v_itbms_amount := ROUND(v_taxable_base * v_itbms_pct, 2);
  v_total := ROUND(v_taxable_base + v_itbms_amount, 2);

  UPDATE public."Proposals"
  SET subtotal_amount = v_subtotal,
      discount_amount = v_discount_amount,
      itbms_amount = v_itbms_amount,
      total_amount = v_total
  WHERE id = p_proposal_id;
END;
$$;

COMMENT ON FUNCTION public.recalc_proposal_totals(uuid) IS 'Recalculates Proposals totals. Uses unit_msrp_total_snapshot (not unit_msrp). Prefers quote_line_snapshot when sent/accepted.';

-- ----------------------------------------------------------------------------
-- 2) freeze_proposal_snapshot: use unit_msrp_total_snapshot instead of unit_msrp
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.freeze_proposal_snapshot(p_proposal_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_proposal RECORD;
  v_pl RECORD;
  v_ql RECORD;
  v_cp RECORD;
  v_snapshot jsonb;
  v_config jsonb;
  v_base_mode text;
  v_base_unit numeric(12,4);
  v_base_line numeric(12,4);
BEGIN
  SELECT id, status, sent_at INTO v_proposal
  FROM public."Proposals"
  WHERE id = p_proposal_id AND deleted = false;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_proposal.status NOT IN ('sent', 'accepted') THEN
    RETURN;
  END IF;

  -- For each ProposalLine from_quote with null quote_line_snapshot
  -- Select unit_msrp_total_snapshot (canonical); no unit_msrp
  FOR v_pl IN
    SELECT pl.id, pl.quote_line_id
    FROM public."ProposalLines" pl
    WHERE pl.proposal_id = p_proposal_id
      AND pl.deleted = false
      AND pl.line_type = 'from_quote'
      AND pl.quote_line_id IS NOT NULL
      AND pl.quote_line_snapshot IS NULL
  LOOP
    SELECT ql.name, ql.sku, ql.quantity, ql.width_m, ql.height_m, ql.area, ql.position,
           ql.product_type, ql.collection_name, ql.variant_name, ql.drive_type,
           ql.msrp, ql.unit_msrp_total_snapshot, ql.configured_product_id
    INTO v_ql
    FROM public."QuoteLines" ql
    WHERE ql.id = v_pl.quote_line_id
    LIMIT 1;

    IF NOT FOUND THEN
      v_snapshot := jsonb_build_object(
        'name', '—',
        'sku', NULL,
        'qty', 1,
        'width_m', NULL,
        'height_m', NULL,
        'measurements', '{}'::jsonb,
        'accessories', NULL,
        'base_price_mode', 'msrp',
        'base_unit_msrp', NULL,
        'base_line_msrp', NULL,
        'captured_at', now()
      );
    ELSE
      v_config := NULL;
      IF v_ql.configured_product_id IS NOT NULL THEN
        SELECT config_snapshot INTO v_config
        FROM public."ConfiguredProducts"
        WHERE id = v_ql.configured_product_id AND deleted = false
        LIMIT 1;
      END IF;

      -- Use unit_msrp_total_snapshot; fallback to msrp/quantity
      v_base_unit := COALESCE(v_ql.unit_msrp_total_snapshot, v_ql.msrp / NULLIF(v_ql.quantity, 0));
      v_base_line := COALESCE(v_ql.msrp, v_base_unit * COALESCE(NULLIF(v_ql.quantity, 0), 1));
      v_base_mode := CASE WHEN v_ql.msrp IS NOT NULL AND v_ql.msrp > 0 THEN 'msrp' ELSE 'unit_msrp' END;

      v_snapshot := jsonb_build_object(
        'name', v_ql.name,
        'sku', v_ql.sku,
        'qty', COALESCE(v_ql.quantity, 1),
        'width_m', v_ql.width_m,
        'height_m', v_ql.height_m,
        'area', v_ql.area,
        'position', v_ql.position,
        'product_type', v_ql.product_type,
        'collection_name', v_ql.collection_name,
        'variant_name', v_ql.variant_name,
        'drive_type', v_ql.drive_type,
        'measurements', COALESCE(v_config->'measurements', '{}'::jsonb),
        'accessories', v_config->'accessories',
        'base_price_mode', v_base_mode,
        'base_unit_msrp', v_base_unit,
        'base_line_msrp', v_base_line,
        'captured_at', now()
      );
    END IF;

    UPDATE public."ProposalLines"
    SET quote_line_snapshot = v_snapshot
    WHERE id = v_pl.id;
  END LOOP;

  UPDATE public."Proposals"
  SET sent_at = COALESCE(sent_at, now())
  WHERE id = p_proposal_id;
END;
$$;

COMMENT ON FUNCTION public.freeze_proposal_snapshot(uuid) IS 'Captures QuoteLine + ConfiguredProduct snapshot. Uses unit_msrp_total_snapshot (not unit_msrp).';
