-- Fix: make quote_no unique constraint partial (only non-deleted)
-- This allows reuse of quote numbers after soft-delete

ALTER TABLE public."Quotes" DROP CONSTRAINT IF EXISTS quotes_org_quote_no_unique;
DROP INDEX IF EXISTS quotes_org_quote_no_unique;
CREATE UNIQUE INDEX quotes_org_quote_no_unique
  ON public."Quotes" (organization_id, quote_no)
  WHERE (deleted = false);
