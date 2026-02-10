-- ============================================================
-- Proposal: Installation as separate global line
-- ============================================================
-- - Subtotal = material only (no installation addons)
-- - Discount applies to subtotal only
-- - Installation = sum of installation addons, NOT affected by discount/fee
-- - Taxable base = (subtotal - discount) + installation
-- - Each line displays material only
-- ============================================================

BEGIN;

-- Add installation_amount to Proposals
ALTER TABLE public."Proposals"
  ADD COLUMN IF NOT EXISTS installation_amount numeric(12,4) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public."Proposals"."installation_amount" IS 'Sum of installation addons. Shown as separate line, not affected by discount or fee.';

-- Update recalc_proposal_totals
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
  v_installation_total numeric(12,4) := 0;
  v_other_addons numeric(12,4) := 0;
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

  -- Subtotal = material only (no addons)
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

  -- Installation total (separate line, not affected by discount/fee)
  -- Other addons (delivery, etc.) added to taxable base
  SELECT COALESCE(SUM(CASE WHEN ao.addon_type = 'installation' THEN ao.sale_amount ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN ao.addon_type <> 'installation' THEN ao.sale_amount ELSE 0 END), 0)
  INTO v_installation_total, v_other_addons
  FROM public."ProposalLineAddOns" ao
  WHERE ao.proposal_id = p_proposal_id AND ao.deleted = false;

  SELECT COALESCE(p.global_discount_pct, 0)
  INTO v_discount_pct
  FROM public."Proposals" p
  WHERE p.id = p_proposal_id;

  -- Discount applies to subtotal only (material)
  v_discount_amount := ROUND(v_subtotal * (v_discount_pct / 100.0), 2);
  -- Taxable base = (subtotal - discount) + installation + other addons (installation not discounted)
  v_taxable_base := GREATEST(v_subtotal - v_discount_amount, 0) + v_installation_total + v_other_addons;
  v_itbms_amount := ROUND(v_taxable_base * v_itbms_pct, 2);
  v_total := ROUND(v_taxable_base + v_itbms_amount, 2);

  UPDATE public."Proposals"
  SET subtotal_amount = v_subtotal,
      installation_amount = v_installation_total,
      discount_amount = v_discount_amount,
      itbms_amount = v_itbms_amount,
      total_amount = v_total
  WHERE id = p_proposal_id;
END;
$$;

COMMENT ON FUNCTION public.recalc_proposal_totals(uuid) IS 'Subtotal = material only. Installation = separate line, not affected by discount/fee.';

-- Backfill
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
