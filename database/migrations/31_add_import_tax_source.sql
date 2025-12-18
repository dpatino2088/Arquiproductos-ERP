-- ====================================================
-- Migration: Add import_tax_source to QuoteLineCosts
-- ====================================================
-- Track whether import_tax_cost is auto-calculated or manually overridden
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Adding import_tax_source to QuoteLineCosts';
  RAISE NOTICE '====================================================';

  -- Add import_tax_source column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLineCosts' 
    AND column_name = 'import_tax_source'
  ) THEN
    ALTER TABLE "QuoteLineCosts" 
    ADD COLUMN import_tax_source text NOT NULL DEFAULT 'auto';
    
    RAISE NOTICE '✅ Added import_tax_source column (default: auto)';
  ELSE
    RAISE NOTICE 'ℹ️  Column import_tax_source already exists';
  END IF;

  -- Add check constraint for source values
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_import_tax_source_valid'
  ) THEN
    ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_import_tax_source_valid 
    CHECK (import_tax_source IN ('auto', 'manual'));
    
    RAISE NOTICE '✅ Added constraint: import_tax_source IN (auto, manual)';
  ELSE
    RAISE NOTICE 'ℹ️  Constraint check_import_tax_source_valid already exists';
  END IF;

  -- Update existing QuoteLineCosts to use 'auto' if source is NULL
  UPDATE "QuoteLineCosts"
  SET import_tax_source = 'auto'
  WHERE import_tax_source IS NULL;

  RAISE NOTICE '✅ Updated existing QuoteLineCosts with default source';

  -- Add comment
  COMMENT ON COLUMN "QuoteLineCosts".import_tax_source IS 'Source of import_tax_cost: auto (calculated from components) or manual (user override)';

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration completed successfully';
  RAISE NOTICE '====================================================';
END $$;

