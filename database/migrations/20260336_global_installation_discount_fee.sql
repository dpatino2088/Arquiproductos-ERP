-- ============================================================
-- Migration: Global discount and fee for installation
-- ============================================================
-- Adds Proposals.global_installation_discount_pct and global_installation_fee_pct
-- to apply discount/fee specifically to the sum of installation addons.
-- recalc_proposal_totals: installation_net = installation_total * (1 - discount_pct/100) * (1 + fee_pct/100)
-- ============================================================

BEGIN;

ALTER TABLE public."Proposals"
  ADD COLUMN IF NOT EXISTS installation_amount numeric(12,4) NOT NULL DEFAULT 0;

ALTER TABLE public."Proposals"
  ADD COLUMN IF NOT EXISTS global_installation_discount_pct numeric(7,4) NULL DEFAULT 0;

ALTER TABLE public."Proposals"
  ADD COLUMN IF NOT EXISTS global_installation_fee_pct numeric(7,4) NULL DEFAULT 0;

COMMENT ON COLUMN public."Proposals"."installation_amount" IS 'Sum of installation addons (raw, for display). Net after discount/fee goes into subtotal.';
COMMENT ON COLUMN public."Proposals"."global_installation_discount_pct" IS 'Discount % applied to installation addons total (e.g. 15 = 15%).';
COMMENT ON COLUMN public."Proposals"."global_installation_fee_pct" IS 'Fee/surcharge % applied to installation addons total (e.g. 5 = 5%).';

-- Update recalc_proposal_totals: separate installation, apply discount/fee, then add to taxable base
CREATE OR REPLACE FUNCTION public.recalc_proposal_totals(p_proposal_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_org_id uuid;
  v_subtotal_material numeric(12,4) := 0;
  v_installation_total numeric(12,4) := 0;
  v_installation_net numeric(12,4) := 0;
  v_other_addons numeric(12,4) := 0;
  v_inst_discount_pct numeric(7,4) := 0;
  v_inst_fee_pct numeric(7,4) := 0;
  v_subtotal numeric(12,4);
  v_discount_pct numeric(12,6);
  v_discount_amount numeric(12,4) := 0;
  v_taxable_base numeric(12,4);
  v_itbms_pct numeric(7,4) := 0.07;
  v_itbms_amount numeric(12,4) := 0;
  v_fee numeric(12,4);
  v_total numeric(12,4);
  v_exempt_itbms boolean := false;
BEGIN
  SELECT p.organization_id, COALESCE(p.exempt_itbms, false),
         COALESCE(p.global_installation_discount_pct, 0), COALESCE(p.global_installation_fee_pct, 0)
    INTO v_org_id, v_exempt_itbms, v_inst_discount_pct, v_inst_fee_pct
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

  -- Material subtotal (lines only, no addons)
  SELECT COALESCE(SUM(
    CASE
      WHEN pl.line_type = 'custom' THEN (COALESCE(pl.qty, 1) * COALESCE(pl.unit_price, 0))
      WHEN pl.line_type = 'from_quote' AND pl.quote_line_id IS NOT NULL THEN (
        SELECT
          CASE COALESCE(pl.override_mode::text, 'inherit')
            WHEN 'inherit' THEN COALESCE(ql.msrp, (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)), 0)
            WHEN 'discount_pct' THEN (COALESCE(ql.msrp, (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)), 0) * (1 - COALESCE(pl.discount_pct, 0) / 100.0))
            WHEN 'markup_pct' THEN (COALESCE(ql.msrp, (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)), 0) * (1 + COALESCE(pl.markup_pct, 0) / 100.0))
            WHEN 'fixed_unit_price' THEN (COALESCE(pl.fixed_unit_price, 0) * COALESCE(NULLIF(ql.quantity, 0), 1))
            WHEN 'fixed_line_total' THEN COALESCE(pl.fixed_line_total, 0)
            ELSE COALESCE(ql.msrp, (COALESCE(ql.unit_msrp_total_snapshot, ql.msrp / NULLIF(ql.quantity, 0)) * COALESCE(NULLIF(ql.quantity, 0), 1)), 0)
          END
        FROM public."QuoteLines" ql
        WHERE ql.id = pl.quote_line_id
        LIMIT 1
      )
      ELSE 0
    END
  ), 0) INTO v_subtotal_material
  FROM public."ProposalLines" pl
  WHERE pl.proposal_id = p_proposal_id AND pl.deleted = false;

  -- Installation total and other addons
  SELECT COALESCE(SUM(CASE WHEN ao.addon_type = 'installation' THEN ao.sale_amount ELSE 0 END), 0),
         COALESCE(SUM(CASE WHEN ao.addon_type <> 'installation' OR ao.addon_type IS NULL THEN ao.sale_amount ELSE 0 END), 0)
  INTO v_installation_total, v_other_addons
  FROM public."ProposalLineAddOns" ao
  WHERE ao.proposal_id = p_proposal_id AND ao.deleted = false;

  -- Apply global installation discount and fee
  v_installation_net := ROUND(
    v_installation_total * (1 - v_inst_discount_pct / 100.0) * (1 + v_inst_fee_pct / 100.0),
    2
  );

  v_subtotal := v_subtotal_material + v_installation_net + v_other_addons;

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
      installation_amount = v_installation_total,
      discount_amount = v_discount_amount,
      itbms_amount = v_itbms_amount,
      total_amount = v_total
  WHERE id = p_proposal_id;
END;
$$;

COMMENT ON FUNCTION public.recalc_proposal_totals(uuid) IS 'Recalculates Proposals totals. Installation has own discount/fee (global_installation_discount_pct, global_installation_fee_pct). Uses unit_msrp_total_snapshot.';

-- Trigger: recalc when global_installation_discount_pct or global_installation_fee_pct change
CREATE OR REPLACE FUNCTION public.trg_proposals_recalc_totals()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.global_discount_pct IS DISTINCT FROM NEW.global_discount_pct
     OR OLD.global_fee_amount IS DISTINCT FROM NEW.global_fee_amount
     OR OLD.global_installation_discount_pct IS DISTINCT FROM NEW.global_installation_discount_pct
     OR OLD.global_installation_fee_pct IS DISTINCT FROM NEW.global_installation_fee_pct THEN
    PERFORM public.recalc_proposal_totals(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proposals_recalc_totals ON public."Proposals";
CREATE TRIGGER trg_proposals_recalc_totals
  AFTER UPDATE OF global_discount_pct, global_fee_amount, global_installation_discount_pct, global_installation_fee_pct ON public."Proposals"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_proposals_recalc_totals();

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
