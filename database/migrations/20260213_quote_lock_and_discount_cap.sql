-- ============================================================
-- Quote Lock + Discount Cap
-- ============================================================
-- REGLA 1: Si Quote tiene Proposal sent/accepted → bloquear UPDATE/DELETE en Quotes y QuoteLines
-- REGLA 2: Proposals.global_discount_pct no puede exceder DealerTiers.max_discount_pct
-- ============================================================

BEGIN;

-- ============================================================
-- 1) DealerTiers.max_discount_pct (cap for Proposals global discount)
-- ============================================================
ALTER TABLE public."DealerTiers"
  ADD COLUMN IF NOT EXISTS max_discount_pct numeric(7,4) NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'dealer_tiers_max_discount_pct_chk') THEN
    ALTER TABLE public."DealerTiers"
      ADD CONSTRAINT dealer_tiers_max_discount_pct_chk
      CHECK (max_discount_pct >= 0 AND max_discount_pct <= 100);
  END IF;
END $$;

-- Backfill: use discount_pct as initial max (tiers like Gold=55 → max_discount_pct=55)
UPDATE public."DealerTiers"
SET max_discount_pct = discount_pct
WHERE max_discount_pct = 0 AND discount_pct > 0;

COMMENT ON COLUMN public."DealerTiers"."max_discount_pct" IS 'Max global discount % allowed for Proposals. Used to cap global_discount_pct.';

-- ============================================================
-- 2) quote_is_locked_by_sent_proposal(quote_id)
-- ============================================================
CREATE OR REPLACE FUNCTION public.quote_is_locked_by_sent_proposal(p_quote_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public."Proposals" p
    WHERE p.quote_id = p_quote_id
      AND COALESCE(p.deleted, false) = false
      AND p.status IN ('sent','accepted')
  );
$$;

COMMENT ON FUNCTION public.quote_is_locked_by_sent_proposal(uuid) IS 'True if Quote has at least one Proposal sent or accepted. Used to block Quote/QuoteLines updates.';

-- ============================================================
-- 3) Triggers: block QuoteLines UPDATE/DELETE when locked
-- ============================================================
CREATE OR REPLACE FUNCTION public.tg_block_quote_lines_if_locked()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF public.quote_is_locked_by_sent_proposal(OLD.quote_id) THEN
    RAISE EXCEPTION 'Quote is locked because a Proposal has been sent/accepted. Create a new Quote.'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_block_quote_lines_update_if_locked ON public."QuoteLines";
CREATE TRIGGER trg_block_quote_lines_update_if_locked
  BEFORE UPDATE ON public."QuoteLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_block_quote_lines_if_locked();

DROP TRIGGER IF EXISTS trg_block_quote_lines_delete_if_locked ON public."QuoteLines";
CREATE TRIGGER trg_block_quote_lines_delete_if_locked
  BEFORE DELETE ON public."QuoteLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_block_quote_lines_if_locked();

-- ============================================================
-- 4) Triggers: block Quotes UPDATE/DELETE when locked
-- ============================================================
CREATE OR REPLACE FUNCTION public.tg_block_quotes_if_locked()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF public.quote_is_locked_by_sent_proposal(OLD.id) THEN
    RAISE EXCEPTION 'Quote is locked because a Proposal has been sent/accepted. Create a new Quote.'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_block_quotes_update_if_locked ON public."Quotes";
CREATE TRIGGER trg_block_quotes_update_if_locked
  BEFORE UPDATE ON public."Quotes"
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_block_quotes_if_locked();

DROP TRIGGER IF EXISTS trg_block_quotes_delete_if_locked ON public."Quotes";
CREATE TRIGGER trg_block_quotes_delete_if_locked
  BEFORE DELETE ON public."Quotes"
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_block_quotes_if_locked();

-- ============================================================
-- 5) assert_proposal_discount_within_dealer_cap
-- ============================================================
CREATE OR REPLACE FUNCTION public.assert_proposal_discount_within_dealer_cap(
  p_dealer_id uuid,
  p_discount_pct numeric
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_tier_id uuid;
  v_cap numeric;
  v_discount numeric := COALESCE(p_discount_pct, 0);
BEGIN
  IF p_dealer_id IS NULL OR v_discount <= 0 THEN
    RETURN;
  END IF;

  SELECT dealer_tier_id INTO v_tier_id
  FROM public."Dealers"
  WHERE id = p_dealer_id;

  IF v_tier_id IS NULL THEN
    RAISE EXCEPTION 'Dealer % has no tier assigned (data error).', p_dealer_id
      USING ERRCODE = 'P0001';
  END IF;

  SELECT max_discount_pct INTO v_cap
  FROM public."DealerTiers"
  WHERE id = v_tier_id;

  IF v_cap IS NULL THEN
    RAISE EXCEPTION 'Dealer tier % missing max_discount_pct (data error).', v_tier_id
      USING ERRCODE = 'P0001';
  END IF;

  IF v_discount > v_cap THEN
    RAISE EXCEPTION 'Discount % exceeds dealer tier cap % (dealer %).', v_discount, v_cap, p_dealer_id
      USING ERRCODE = 'P0001';
  END IF;
END;
$$;

-- ============================================================
-- 6) Trigger: Proposals discount cap
-- ============================================================
CREATE OR REPLACE FUNCTION public.tg_proposals_discount_cap()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.assert_proposal_discount_within_dealer_cap(NEW.dealer_id, NEW.global_discount_pct);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_proposals_discount_cap ON public."Proposals";
CREATE TRIGGER trg_proposals_discount_cap
  BEFORE INSERT OR UPDATE OF global_discount_pct, dealer_id ON public."Proposals"
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_proposals_discount_cap();

COMMIT;
