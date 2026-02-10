-- ============================================================
-- Proposal hardening: enum custom_category + recalc totals
-- ============================================================
-- 1) Enum: standardize on delivery (not transportation).
--    Handles proposal_custom_line_category (MVP): add delivery, service; migrate transportation -> delivery.
--    If column uses proposal_custom_category (V2) it already has delivery/service; no change.
-- 2) Function recalc_proposal_totals(proposal_id)
-- 3) Triggers: after ProposalLines change or Proposals global_discount_pct/global_fee_amount -> recalc
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Enum custom_category: add delivery/service, migrate transportation -> delivery
-- ============================================================
DO $$
DECLARE
  v_typname text;
BEGIN
  SELECT t.typname INTO v_typname
  FROM pg_attribute a
  JOIN pg_class c ON a.attrelid = c.oid
  JOIN pg_type t ON a.atttypid = t.oid
  WHERE c.relname = 'ProposalLines'
    AND a.attname = 'custom_category'
    AND a.attnum > 0
    AND NOT a.attisdropped;

  IF v_typname = 'proposal_custom_line_category' THEN
    IF NOT EXISTS (SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid WHERE t.typname = 'proposal_custom_line_category' AND e.enumlabel = 'delivery') THEN
      ALTER TYPE public.proposal_custom_line_category ADD VALUE 'delivery';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_enum e JOIN pg_type t ON e.enumtypid = t.oid WHERE t.typname = 'proposal_custom_line_category' AND e.enumlabel = 'service') THEN
      ALTER TYPE public.proposal_custom_line_category ADD VALUE 'service';
    END IF;
    UPDATE public."ProposalLines"
    SET custom_category = 'delivery'::public.proposal_custom_line_category
    WHERE custom_category::text = 'transportation';
  END IF;
  -- If v_typname = 'proposal_custom_category' (V2): already has installation, delivery, service, other; nothing to do.
END $$;

-- ============================================================
-- 2) Ensure Proposals has subtotal_amount, total_amount (if missing)
-- ============================================================
ALTER TABLE public."Proposals"
  ADD COLUMN IF NOT EXISTS subtotal_amount numeric(12,4),
  ADD COLUMN IF NOT EXISTS total_amount numeric(12,4);

-- Ensure ProposalLines has columns used by recalc (MVP has quantity; V2 has qty, override_mode, deleted)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ProposalLines' AND column_name = 'qty') THEN
    ALTER TABLE public."ProposalLines" ADD COLUMN qty numeric(12,4) DEFAULT 1;
    UPDATE public."ProposalLines" SET qty = quantity WHERE quantity IS NOT NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ProposalLines' AND column_name = 'quantity') THEN
    ALTER TABLE public."ProposalLines" ADD COLUMN quantity numeric(12,4);
    UPDATE public."ProposalLines" SET quantity = qty WHERE qty IS NOT NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ProposalLines' AND column_name = 'override_mode') THEN
    ALTER TABLE public."ProposalLines" ADD COLUMN override_mode text DEFAULT 'inherit';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'ProposalLines' AND column_name = 'deleted') THEN
    ALTER TABLE public."ProposalLines" ADD COLUMN deleted boolean NOT NULL DEFAULT false;
  END IF;
END $$;

-- ============================================================
-- 3) Function: recalc_proposal_totals(p_proposal_id)
-- ============================================================
CREATE OR REPLACE FUNCTION public.recalc_proposal_totals(p_proposal_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_subtotal numeric(12,4) := 0;
  v_total numeric(12,4);
  v_discount_pct numeric(12,6);
  v_fee numeric(12,4);
  v_line_total numeric(12,4);
  v_base numeric(12,4);
  v_ql_qty numeric(12,4);
BEGIN
  FOR v_line_total IN
    SELECT
      CASE
        WHEN pl.line_type = 'custom' THEN
          (COALESCE(pl.qty, pl.quantity, 1) * COALESCE(pl.unit_price, 0))
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
    FROM public."ProposalLines" pl
    WHERE pl.proposal_id = p_proposal_id
      AND pl.deleted = false
  LOOP
    v_subtotal := v_subtotal + COALESCE(v_line_total, 0);
  END LOOP;

  SELECT COALESCE(p.global_discount_pct, 0), COALESCE(p.global_fee_amount, 0)
  INTO v_discount_pct, v_fee
  FROM public."Proposals" p
  WHERE p.id = p_proposal_id;

  v_total := v_subtotal * (1 - v_discount_pct / 100.0) + v_fee;

  UPDATE public."Proposals"
  SET subtotal_amount = v_subtotal,
      total_amount = v_total
  WHERE id = p_proposal_id;
END;
$$;

COMMENT ON FUNCTION public.recalc_proposal_totals(uuid) IS 'Recalculates Proposals.subtotal_amount and total_amount from ProposalLines (and QuoteLines base for from_quote). Respects deleted=false.';

-- ============================================================
-- 4) Trigger: after ProposalLines insert/update/delete
-- ============================================================
CREATE OR REPLACE FUNCTION public.trg_proposal_lines_recalc_totals()
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

DROP TRIGGER IF EXISTS trg_proposal_lines_recalc_totals ON public."ProposalLines";
CREATE TRIGGER trg_proposal_lines_recalc_totals
  AFTER INSERT OR UPDATE OR DELETE ON public."ProposalLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_proposal_lines_recalc_totals();

-- ============================================================
-- 5) Trigger: after Proposals update of global_discount_pct, global_fee_amount
-- ============================================================
CREATE OR REPLACE FUNCTION public.trg_proposals_recalc_totals()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.global_discount_pct IS DISTINCT FROM NEW.global_discount_pct
     OR OLD.global_fee_amount IS DISTINCT FROM NEW.global_fee_amount THEN
    PERFORM public.recalc_proposal_totals(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proposals_recalc_totals ON public."Proposals";
CREATE TRIGGER trg_proposals_recalc_totals
  AFTER UPDATE OF global_discount_pct, global_fee_amount ON public."Proposals"
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_proposals_recalc_totals();

-- ============================================================
-- 6) Backfill: recalc all proposals (optional, one-time)
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
