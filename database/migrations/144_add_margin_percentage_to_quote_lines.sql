-- ====================================================
-- Migration: Add margin_percentage column to QuoteLines
-- ====================================================
-- The function calculate_quote_line_price tries to update margin_percentage
-- but the column doesn't exist (only margin_percentage_used exists from migration 45)
-- This migration adds margin_percentage to match what the function expects
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Adding margin_percentage to QuoteLines';
  RAISE NOTICE '====================================================';

  -- Add margin_percentage column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'QuoteLines' 
      AND column_name = 'margin_percentage'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD COLUMN margin_percentage numeric(8,4) NULL;
    
    RAISE NOTICE '✅ Added margin_percentage column to QuoteLines';
  ELSE
    RAISE NOTICE '⚠️  margin_percentage already exists in QuoteLines';
  END IF;

  -- Add index for margin_percentage (for reporting/analysis)
  CREATE INDEX IF NOT EXISTS idx_quote_lines_margin_percentage 
    ON public."QuoteLines"(margin_percentage) 
    WHERE margin_percentage IS NOT NULL;

  RAISE NOTICE '✅ Created index for margin_percentage';

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration completed successfully';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Summary:';
  RAISE NOTICE '   - Added margin_percentage column to QuoteLines';
  RAISE NOTICE '   - Created index for margin_percentage';
  RAISE NOTICE '';
  RAISE NOTICE 'Note: margin_percentage_used (from migration 45) and margin_percentage';
  RAISE NOTICE 'are both present. The function calculate_quote_line_price uses margin_percentage.';
  RAISE NOTICE '';
END $$;

