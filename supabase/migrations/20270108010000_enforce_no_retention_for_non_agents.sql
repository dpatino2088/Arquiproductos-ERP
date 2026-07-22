-- Enforce, at the data layer, that a dealer who is NOT a tax retention agent
-- always pays the full 7% ITBMS and can never have any retention applied.
--
-- Background: retention was already gated in the UI (InvoiceNew, InvoiceDetail)
-- and in the create_tax_retention_note RPC (returns 'dealer_not_retention_agent').
-- This migration adds two structural guarantees so it is impossible to bypass
-- via a raw insert or stale rate, and cleans up confusing leftover rates.

SET search_path = public;

-- 1) Keep tax_retention_rate consistent with the agent flag.
--    When a dealer is not a retention agent, force the rate to 0 so no code
--    path (present or future) can ever compute a retention from a stale rate.
CREATE OR REPLACE FUNCTION public.fn_dealer_normalize_retention_rate()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF COALESCE(NEW.is_tax_retention_agent, false) = false THEN
    NEW.tax_retention_rate := 0;
  ELSIF NEW.tax_retention_rate IS NULL OR NEW.tax_retention_rate <= 0 THEN
    -- Agent with no explicit rate: default to 50% of the ITBMS (Panama norm).
    NEW.tax_retention_rate := 0.5;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_dealer_normalize_retention_rate ON public."Dealers";
CREATE TRIGGER trg_dealer_normalize_retention_rate
BEFORE INSERT OR UPDATE OF is_tax_retention_agent, tax_retention_rate
ON public."Dealers"
FOR EACH ROW
EXECUTE FUNCTION public.fn_dealer_normalize_retention_rate();

-- 2) Reject any tax_retention credit note for a dealer that is not an agent,
--    even if inserted directly (bypassing the RPC). Defense in depth.
CREATE OR REPLACE FUNCTION public.fn_block_retention_for_non_agent()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_is_agent boolean;
BEGIN
  IF NEW.kind = 'tax_retention' AND COALESCE(NEW.deleted, false) = false THEN
    SELECT d.is_tax_retention_agent INTO v_is_agent
    FROM public."Dealers" d
    WHERE d.id = NEW.dealer_id;

    IF NOT COALESCE(v_is_agent, false) THEN
      RAISE EXCEPTION 'Cannot create a tax retention note: dealer % is not a tax retention agent (full 7%% ITBMS applies).', NEW.dealer_id
        USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_block_retention_for_non_agent ON public."DealerCreditNotes";
CREATE TRIGGER trg_block_retention_for_non_agent
BEFORE INSERT OR UPDATE ON public."DealerCreditNotes"
FOR EACH ROW
EXECUTE FUNCTION public.fn_block_retention_for_non_agent();

-- 3) Backfill: zero out any leftover rate on non-agent dealers (data hygiene).
UPDATE public."Dealers"
SET tax_retention_rate = 0
WHERE COALESCE(is_tax_retention_agent, false) = false
  AND COALESCE(tax_retention_rate, 0) <> 0;
