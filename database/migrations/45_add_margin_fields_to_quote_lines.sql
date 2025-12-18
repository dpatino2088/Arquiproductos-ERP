-- ====================================================
-- Migration: Add Margin Fields to QuoteLines
-- ====================================================
-- Adds fields to track margin percentage and source
-- for price calculation using Category Margins
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Adding margin fields to QuoteLines';
  RAISE NOTICE '====================================================';

  -- Step 1: Add margin_percentage_used to QuoteLines
  -- This stores the actual margin percentage used for price calculation
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'QuoteLines' 
      AND column_name = 'margin_percentage_used'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD COLUMN margin_percentage_used numeric(8,4) NULL;
    
    RAISE NOTICE '✅ Added margin_percentage_used to QuoteLines';
  ELSE
    RAISE NOTICE '⚠️  margin_percentage_used already exists in QuoteLines';
  END IF;

  -- Step 2: Add margin_source to QuoteLines
  -- This indicates where the margin came from: 'category', 'item', or 'default'
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'QuoteLines' 
      AND column_name = 'margin_source'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD COLUMN margin_source text NULL
      CHECK (margin_source IS NULL OR margin_source IN ('category', 'item', 'default'));
    
    RAISE NOTICE '✅ Added margin_source to QuoteLines';
  ELSE
    RAISE NOTICE '⚠️  margin_source already exists in QuoteLines';
  END IF;

  -- Step 3: Add index for margin_percentage_used (for reporting/analysis)
  CREATE INDEX IF NOT EXISTS idx_quote_lines_margin_percentage_used 
    ON public."QuoteLines"(margin_percentage_used) 
    WHERE margin_percentage_used IS NOT NULL;

  -- Step 4: Add index for margin_source (for filtering)
  CREATE INDEX IF NOT EXISTS idx_quote_lines_margin_source 
    ON public."QuoteLines"(margin_source) 
    WHERE margin_source IS NOT NULL;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration complete';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Fields added:';
  RAISE NOTICE '  - QuoteLines.margin_percentage_used (numeric)';
  RAISE NOTICE '  - QuoteLines.margin_source (text: category|item|default)';
  RAISE NOTICE '';
END $$;

