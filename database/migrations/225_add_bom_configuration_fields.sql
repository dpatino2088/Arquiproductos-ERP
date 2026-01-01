-- ====================================================
-- Migration 225: Add BOM Configuration Fields
-- ====================================================
-- This migration adds configuration fields to QuoteLines and SalesOrderLines
-- to enable deterministic BOM generation with proper SKU resolution
-- ====================================================

BEGIN;

-- STEP 1: Add configuration fields to QuoteLines
-- ====================================================
ALTER TABLE "QuoteLines"
  ADD COLUMN IF NOT EXISTS tube_type TEXT,
  ADD COLUMN IF NOT EXISTS operating_system_variant TEXT,
  ADD COLUMN IF NOT EXISTS top_rail_type TEXT;

COMMENT ON COLUMN "QuoteLines".tube_type IS 
    'Tube type variant: RTU-42, RTU-65, RTU-80, etc. Used for BOM SKU resolution.';

COMMENT ON COLUMN "QuoteLines".operating_system_variant IS 
    'Operating system variant: standard_m, standard_l, etc. Used for BOM SKU resolution.';

COMMENT ON COLUMN "QuoteLines".top_rail_type IS 
    'Top rail type: ONLY for Drapery (future use).';

-- STEP 2: Add configuration fields to SalesOrderLines
-- ====================================================
ALTER TABLE "SalesOrderLines"
  ADD COLUMN IF NOT EXISTS tube_type TEXT,
  ADD COLUMN IF NOT EXISTS operating_system_variant TEXT,
  ADD COLUMN IF NOT EXISTS top_rail_type TEXT,
  ADD COLUMN IF NOT EXISTS bottom_rail_type TEXT,
  ADD COLUMN IF NOT EXISTS side_channel BOOLEAN,
  ADD COLUMN IF NOT EXISTS side_channel_type TEXT;

COMMENT ON COLUMN "SalesOrderLines".tube_type IS 
    'Tube type variant copied from QuoteLine for traceability.';

COMMENT ON COLUMN "SalesOrderLines".operating_system_variant IS 
    'Operating system variant copied from QuoteLine for traceability.';

COMMENT ON COLUMN "SalesOrderLines".top_rail_type IS 
    'Top rail type copied from QuoteLine for traceability.';

COMMENT ON COLUMN "SalesOrderLines".bottom_rail_type IS 
    'Bottom rail type copied from QuoteLine for traceability.';

COMMENT ON COLUMN "SalesOrderLines".side_channel IS 
    'Side channel enabled flag copied from QuoteLine for traceability.';

COMMENT ON COLUMN "SalesOrderLines".side_channel_type IS 
    'Side channel type copied from QuoteLine for traceability.';

COMMIT;



