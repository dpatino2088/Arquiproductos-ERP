-- ============================================================
-- Proposal Line Adjustment % (Opción B)
-- ============================================================
-- ProposalLines.line_adjustment_pct: -10 = discount 10%, +10 = fee 10%, 0 = no change
-- Base price ALWAYS from QuoteLines (or snapshot when sent/accepted)
-- recalc_proposal_totals: use line_adjustment_pct, prefer snapshot
-- Do NOT use override_mode for pricing; keep override_mode='inherit' for compatibility
-- ============================================================

BEGIN;

-- ============================================================
-- A) Add line_adjustment_pct to ProposalLines
-- ============================================================
ALTER TABLE public."ProposalLines"
  ADD COLUMN IF NOT EXISTS line_adjustment_pct numeric(7,4) NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'proposal_lines_line_adjustment_pct_chk'
  ) THEN
    ALTER TABLE public."ProposalLines"
      ADD CONSTRAINT proposal_lines_line_adjustment_pct_chk
      CHECK (line_adjustment_pct >= -100 AND line_adjustment_pct <= 100);
  END IF;
END $$;

UPDATE public."ProposalLines"
SET line_adjustment_pct = 0
WHERE line_adjustment_pct IS NULL;

COMMENT ON COLUMN public."ProposalLines"."line_adjustment_pct" IS 'Line adjustment %: -10 = discount 10%, +10 = fee 10%, 0 = no change. Applied to base from QuoteLine/snapshot.';

-- ============================================================
-- B) Update recalc_proposal_totals: use line_adjustment_pct, prefer snapshot
-- ============================================================
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
              SELECT COALESCE(ql.msrp, ql.unit_msrp * NULLIF(ql.quantity, 0), 0)
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

COMMENT ON FUNCTION public.recalc_proposal_totals(uuid) IS 'Recalculates Proposals totals. Uses line_adjustment_pct (not override_mode). Prefers quote_line_snapshot when sent/accepted.';

-- Backfill recalc
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN SELECT id FROM public."Proposals" WHERE deleted = false
  LOOP
    PERFORM public.recalc_proposal_totals(r.id);
  END LOOP;
END $$;

COMMIT;
