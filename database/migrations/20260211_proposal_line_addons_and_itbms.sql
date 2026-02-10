-- ============================================================
-- Proposal Line Add-ons + ITBMS
-- ============================================================
-- A) ProposalLineAddOns: installation, delivery, etc. per ProposalLine (from_quote)
-- B) CostSettings.itbms_pct: ITBMS % for Proposals
-- C) Proposals: discount_amount, itbms_amount
-- D) recalc_proposal_totals: add addons, ITBMS, discount before ITBMS
-- ============================================================

BEGIN;

-- ============================================================
-- A) Table: ProposalLineAddOns
-- ============================================================
CREATE TABLE IF NOT EXISTS public."ProposalLineAddOns" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public."Organizations"(id) ON DELETE CASCADE,
  dealer_id uuid NOT NULL REFERENCES public."Dealers"(id) ON DELETE RESTRICT,
  proposal_id uuid NOT NULL REFERENCES public."Proposals"(id) ON DELETE CASCADE,
  proposal_line_id uuid NOT NULL REFERENCES public."ProposalLines"(id) ON DELETE CASCADE,

  addon_type text NOT NULL DEFAULT 'installation' CHECK (addon_type IN ('installation', 'delivery', 'measurement', 'other')),

  cost_amount numeric(12,4) NOT NULL DEFAULT 0,
  pricing_mode text NOT NULL DEFAULT 'markup_pct' CHECK (pricing_mode IN ('markup_pct', 'fixed_price')),
  markup_pct numeric(7,4),
  sale_amount numeric(12,4) NOT NULL DEFAULT 0,

  taxable boolean NOT NULL DEFAULT true,

  sort_order integer NOT NULL DEFAULT 0,
  deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_proposal_line_addons_proposal_line
  ON public."ProposalLineAddOns"(proposal_line_id) WHERE deleted = false;
CREATE INDEX IF NOT EXISTS idx_proposal_line_addons_proposal
  ON public."ProposalLineAddOns"(proposal_id) WHERE deleted = false;

COMMENT ON TABLE public."ProposalLineAddOns" IS 'Add-ons per ProposalLine (e.g. installation, delivery). Used for ITBMS and line totals.';

DROP TRIGGER IF EXISTS trg_proposal_line_addons_set_updated_at ON public."ProposalLineAddOns";
CREATE TRIGGER trg_proposal_line_addons_set_updated_at
  BEFORE UPDATE ON public."ProposalLineAddOns"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- RLS: ProposalLineAddOns (same pattern as ProposalLines: access via Proposal)
ALTER TABLE public."ProposalLineAddOns" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS proposal_line_addons_select ON public."ProposalLineAddOns";
CREATE POLICY proposal_line_addons_select
  ON public."ProposalLineAddOns" FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR (p.dealer_id IS NOT NULL AND public.is_dealer_portal_user(p.dealer_id))
        )
    )
  );

DROP POLICY IF EXISTS proposal_line_addons_insert ON public."ProposalLineAddOns";
CREATE POLICY proposal_line_addons_insert
  ON public."ProposalLineAddOns" FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND p.deleted = false
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR (p.dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(p.dealer_id))
        )
    )
  );

DROP POLICY IF EXISTS proposal_line_addons_update ON public."ProposalLineAddOns";
CREATE POLICY proposal_line_addons_update
  ON public."ProposalLineAddOns" FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR (p.dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(p.dealer_id))
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR (p.dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(p.dealer_id))
        )
    )
  );

DROP POLICY IF EXISTS proposal_line_addons_delete ON public."ProposalLineAddOns";
CREATE POLICY proposal_line_addons_delete
  ON public."ProposalLineAddOns" FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public."Proposals" p
      WHERE p.id = proposal_id
        AND (
          (p.organization_id IS NOT NULL AND public.is_org_member(p.organization_id))
          OR (p.dealer_id IS NOT NULL AND public.is_dealer_portal_user_with_write(p.dealer_id))
        )
    )
  );

-- ============================================================
-- B) CostSettings: add itbms_pct
-- ============================================================
ALTER TABLE public."CostSettings"
  ADD COLUMN IF NOT EXISTS itbms_pct numeric(7,4) NOT NULL DEFAULT 0.07;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'CostSettings' AND column_name = 'itbms_pct') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'costsettings_itbms_pct_range') THEN
      ALTER TABLE public."CostSettings" ADD CONSTRAINT costsettings_itbms_pct_range CHECK (itbms_pct >= 0 AND itbms_pct <= 1);
    END IF;
  END IF;
END $$;

COMMENT ON COLUMN public."CostSettings"."itbms_pct" IS 'ITBMS % (0-1, e.g. 0.07 = 7%). Used in Proposals totals.';

-- ============================================================
-- C) Proposals: add discount_amount, itbms_amount (if not exist)
-- ============================================================
ALTER TABLE public."Proposals"
  ADD COLUMN IF NOT EXISTS discount_amount numeric(12,4),
  ADD COLUMN IF NOT EXISTS itbms_amount numeric(12,4);

COMMENT ON COLUMN public."Proposals"."discount_amount" IS 'Amount of global discount (before ITBMS). Shown in PDF only when > 0.';
COMMENT ON COLUMN public."Proposals"."itbms_amount" IS 'ITBMS amount. Calculated from taxable_base * itbms_pct.';

-- ============================================================
-- D) Function: recalc_proposal_totals (updated)
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
  v_line_material numeric(12,4);
  v_line_addons numeric(12,4);
BEGIN
  SELECT p.organization_id INTO v_org_id
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

  -- Material total from ProposalLines (same as before)
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

  -- Add-ons total
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
  v_itbms_amount := ROUND(v_taxable_base * v_itbms_pct, 2);
  v_total := ROUND(v_taxable_base + v_itbms_amount + COALESCE(v_fee, 0), 2);

  UPDATE public."Proposals"
  SET subtotal_amount = v_subtotal,
      discount_amount = v_discount_amount,
      itbms_amount = v_itbms_amount,
      total_amount = v_total
  WHERE id = p_proposal_id;
END;
$$;

COMMENT ON FUNCTION public.recalc_proposal_totals(uuid) IS 'Recalculates Proposals.subtotal_amount, discount_amount, itbms_amount, total_amount. Includes ProposalLineAddOns. Discount before ITBMS.';

-- ============================================================
-- E) Trigger: ProposalLineAddOns -> recalc
-- ============================================================
CREATE OR REPLACE FUNCTION public.trg_proposal_line_addons_recalc_totals()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_proposal_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_proposal_id := OLD.proposal_id;
  ELSE
    v_proposal_id := NEW.proposal_id;
  END IF;
  IF v_proposal_id IS NOT NULL THEN
    PERFORM public.recalc_proposal_totals(v_proposal_id);
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proposal_line_addons_recalc_totals ON public."ProposalLineAddOns";
CREATE TRIGGER trg_proposal_line_addons_recalc_totals
  AFTER INSERT OR UPDATE OR DELETE ON public."ProposalLineAddOns"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_proposal_line_addons_recalc_totals();

-- ============================================================
-- F) Backfill recalc (to populate discount_amount, itbms_amount)
-- ============================================================
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
