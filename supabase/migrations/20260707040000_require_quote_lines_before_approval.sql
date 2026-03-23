-- ============================================================================
-- Enforce quote integrity before approval
-- - A Quote cannot transition to status='approved' without at least one QuoteLine.
-- ============================================================================

SET search_path = public;

CREATE OR REPLACE FUNCTION public.tg_require_quote_lines_before_approval()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_line_count integer;
BEGIN
  -- Only validate real transition to approved on active (non-deleted) quotes.
  IF COALESCE(NEW.deleted, false) = false
     AND lower(COALESCE(NEW.status, '')) = 'approved'
     AND lower(COALESCE(OLD.status, '')) IS DISTINCT FROM 'approved' THEN

    SELECT COUNT(*)
      INTO v_line_count
    FROM public."QuoteLines" ql
    WHERE ql.quote_id = NEW.id;

    IF COALESCE(v_line_count, 0) <= 0 THEN
      RAISE EXCEPTION 'Cannot approve quote without lines. Add at least one quote line before approval.'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_require_quote_lines_before_approval ON public."Quotes";

CREATE TRIGGER trg_require_quote_lines_before_approval
BEFORE UPDATE OF status ON public."Quotes"
FOR EACH ROW
EXECUTE FUNCTION public.tg_require_quote_lines_before_approval();

