-- ====================================================
-- Migration: Add metadata column to QuoteLines
-- ====================================================
-- This migration adds a JSONB metadata column to QuoteLines
-- to store panel configuration and other flexible data.

-- Step 1: Add metadata column as JSONB (nullable)
ALTER TABLE "QuoteLines"
  ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT NULL;

-- Step 2: Add comment for documentation
COMMENT ON COLUMN "QuoteLines".metadata IS 'JSONB field for storing flexible data like panel configurations (panel_index, total_panels, panels array with widths).';

-- Step 3: Create an index on metadata for better query performance (optional, but recommended)
CREATE INDEX IF NOT EXISTS idx_quote_lines_metadata ON "QuoteLines" USING GIN (metadata);

-- ====================================================
-- Verification
-- ====================================================
-- Run this query to verify the column was added:
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'QuoteLines' AND column_name = 'metadata';
-- Expected: data_type = 'jsonb', is_nullable = 'YES'





