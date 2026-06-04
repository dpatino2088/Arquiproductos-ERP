-- Ensure QuoteLines always have a deterministic sort_order.
-- Root cause of "lines move randomly": many lines had sort_order = NULL and
-- identical created_at (batch clone), so ORDER BY sort_order NULLS LAST,
-- created_at returns a non-deterministic order across refetches.

-- 1) Auto-assign sort_order on insert when not provided (covers all insert paths)
CREATE OR REPLACE FUNCTION public.quote_lines_set_sort_order()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.sort_order IS NULL THEN
    SELECT COALESCE(MAX(ql.sort_order), -1) + 1
    INTO NEW.sort_order
    FROM public."QuoteLines" ql
    WHERE ql.quote_id = NEW.quote_id;
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_quote_lines_set_sort_order ON public."QuoteLines";
CREATE TRIGGER trg_quote_lines_set_sort_order
  BEFORE INSERT ON public."QuoteLines"
  FOR EACH ROW
  EXECUTE FUNCTION public.quote_lines_set_sort_order();

-- 2) Backfill existing rows: assign a stable order per quote.
--    Tiebreaker id keeps it deterministic when created_at ties.
WITH ranked AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY quote_id
      ORDER BY sort_order ASC NULLS LAST, created_at ASC, id ASC
    ) - 1 AS new_sort
  FROM public."QuoteLines"
)
UPDATE public."QuoteLines" ql
SET sort_order = r.new_sort
FROM ranked r
WHERE ql.id = r.id
  AND (ql.sort_order IS DISTINCT FROM r.new_sort);
