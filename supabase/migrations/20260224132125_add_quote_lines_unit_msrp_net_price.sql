-- Add unit_msrp and net_price to QuoteLines for frontend persistence (accessories line and pricing).
-- These columns are referenced by the app; the schema cache error is resolved by adding them.
ALTER TABLE "QuoteLines"
  ADD COLUMN IF NOT EXISTS unit_msrp numeric NULL,
  ADD COLUMN IF NOT EXISTS net_price numeric NULL;

COMMENT ON COLUMN "QuoteLines".unit_msrp IS 'Unit MSRP (price per unit); used by UI and accessories line insert.';
COMMENT ON COLUMN "QuoteLines".net_price IS 'Net price for the line; used by UI when different from msrp.';;
