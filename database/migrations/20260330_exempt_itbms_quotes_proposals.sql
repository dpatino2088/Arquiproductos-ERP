-- ============================================================
-- Migration: exempt_itbms for Quotes and Proposals
-- ============================================================
-- Permite excluir ITBMS en clientes que no lo requieren.
-- Cuando exempt_itbms = true: subtotal = total, no se muestra ITBMS.
-- ============================================================

BEGIN;

-- Quotes: add exempt_itbms
ALTER TABLE public."Quotes"
  ADD COLUMN IF NOT EXISTS exempt_itbms boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public."Quotes"."exempt_itbms" IS 'Si true, el Quote no incluye ITBMS. Subtotal = Total.';

-- Proposals: add exempt_itbms
ALTER TABLE public."Proposals"
  ADD COLUMN IF NOT EXISTS exempt_itbms boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public."Proposals"."exempt_itbms" IS 'Si true, la Proposal no incluye ITBMS. itbms_amount = 0, total = taxable_base + fee.';

-- ============================================================
-- recalc_proposal_totals: cuando exempt_itbms = true, itbms_amount = 0
-- ============================================================
CREATE OR REPLACE FUNCTION public.recalc_proposal_totals(p_proposal_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
  v_subtotal numeric(12,4) := 0;
  v_addons_total numeric(12,4) := 0;
  v_discount_pct numeric(12,6);
  v_discount_amount numeric(12,4) := 0;
  v_taxable_base numeric(12,4);
  v_itbms_pct numeric(7,4) := 0.07;
  v_itbms_amount numeric(12,4) := 0;
  v_fee numeric(12,4);
  v_total numeric(12,4);
  v_exempt_itbms boolean := false;
BEGIN
  SELECT p.organization_id, COALESCE(p.exempt_itbms, false)
    INTO v_org_id, v_exempt_itbms
  FROM public."Proposals" p
  WHERE p.id = p_proposal_id AND p.deleted = false;

  IF v_org_id IS NULL THEN
    RETURN;
  END IF;

  IF NOT v_exempt_itbms THEN
    SELECT COALESCE(cs.itbms_pct, 0.07) INTO v_itbms_pct
    FROM public."CostSettings" cs
    WHERE cs.organization_id = v_org_id AND COALESCE(cs.is_active, true)
    ORDER BY cs.created_at DESC
    LIMIT 1;
  END IF;

  SELECT COALESCE(SUM(
    CASE
      WHEN pl.line_type = 'custom' THEN (COALESCE(pl.qty, 1) * COALESCE(pl.unit_price, 0))
      WHEN pl.line_type = 'from_quote' AND pl.quote_line_id IS NOT NULL THEN (
        SELECT
          CASE COALESCE(pl.override_mode::text, 'inherit')
            WHEN 'inherit' THEN COALESCE(ql.msrp, ql.unit_msrp * NULLIF(ql.quantity, 0), 0)
            WHEN 'discount_pct' THEN (COALESCE(ql.msrp, ql.unit_msrp * NULLIF(ql.quantity, 0), 0) * (1 - COALESCE(pl.discount_pct, 0) / 100.0))
            WHEN 'markup_pct' THEN (COALESCE(ql.msrp, ql.unit_msrp * NULLIF(ql.quantity, 0), 0) * (1 + COALESCE(pl.markup_pct, 0) / 100.0))
            WHEN 'fixed_unit_price' THEN (COALESCE(pl.fixed_unit_price, 0) * NULLIF(ql.quantity, 0))
            WHEN 'fixed_line_total' THEN COALESCE(pl.fixed_line_total, 0)
            ELSE COALESCE(ql.msrp, ql.unit_msrp * NULLIF(ql.quantity, 0), 0)
          END
        FROM public."QuoteLines" ql
        WHERE ql.id = pl.quote_line_id
        LIMIT 1
      )
      ELSE 0
    END
  ), 0) INTO v_subtotal
  FROM public."ProposalLines" pl
  WHERE pl.proposal_id = p_proposal_id AND pl.deleted = false;

  SELECT COALESCE(SUM(ao.sale_amount), 0) INTO v_addons_total
  FROM public."ProposalLineAddOns" ao
  WHERE ao.proposal_id = p_proposal_id AND ao.deleted = false;

  v_subtotal := v_subtotal + v_addons_total;

  SELECT COALESCE(p.global_discount_pct, 0), COALESCE(p.global_fee_amount, 0)
  INTO v_discount_pct, v_fee
  FROM public."Proposals" p
  WHERE p.id = p_proposal_id;

  v_discount_amount := ROUND(v_subtotal * (v_discount_pct / 100.0), 2);
  v_taxable_base := GREATEST(v_subtotal - v_discount_amount, 0);

  IF v_exempt_itbms THEN
    v_itbms_amount := 0;
  ELSE
    v_itbms_amount := ROUND(v_taxable_base * v_itbms_pct, 2);
  END IF;

  v_total := ROUND(v_taxable_base + v_itbms_amount + COALESCE(v_fee, 0), 2);

  UPDATE public."Proposals"
  SET subtotal_amount = v_subtotal,
      discount_amount = v_discount_amount,
      itbms_amount = v_itbms_amount,
      total_amount = v_total
  WHERE id = p_proposal_id;
END;
$$;

COMMENT ON FUNCTION public.recalc_proposal_totals(uuid) IS 'Recalculates Proposals totals. When exempt_itbms=true, itbms_amount=0.';

COMMIT;
