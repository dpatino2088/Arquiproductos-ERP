-- ====================================================
-- Migration: Update Cost Engine to v1 (Percentage-based)
-- ====================================================
-- Cost Engine v1: Simple percentage-based labor and shipping
-- Labor default = 10% of base material cost
-- Shipping default = 15% of base material cost
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Updating Cost Engine to v1 (Percentage-based)';
  RAISE NOTICE '====================================================';

  -- ====================================================
  -- STEP 1: Update CostSettings table
  -- ====================================================

  -- Add labor_percentage column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CostSettings' 
    AND column_name = 'labor_percentage'
  ) THEN
    ALTER TABLE "CostSettings" 
    ADD COLUMN labor_percentage numeric(8,4) NOT NULL DEFAULT 10.0000;
    
    RAISE NOTICE '✅ Added labor_percentage column (default: 10.0000%%)';
  ELSE
    RAISE NOTICE 'ℹ️  Column labor_percentage already exists';
  END IF;

  -- Add shipping_percentage column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CostSettings' 
    AND column_name = 'shipping_percentage'
  ) THEN
    ALTER TABLE "CostSettings" 
    ADD COLUMN shipping_percentage numeric(8,4) NOT NULL DEFAULT 15.0000;
    
    RAISE NOTICE '✅ Added shipping_percentage column (default: 15.0000%%)';
  ELSE
    RAISE NOTICE 'ℹ️  Column shipping_percentage already exists';
  END IF;

  -- Add constraints for percentages (>= 0)
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_labor_percentage_non_negative'
  ) THEN
    ALTER TABLE "CostSettings"
    ADD CONSTRAINT check_labor_percentage_non_negative 
    CHECK (labor_percentage >= 0);
    
    RAISE NOTICE '✅ Added constraint: labor_percentage >= 0';
  ELSE
    RAISE NOTICE 'ℹ️  Constraint check_labor_percentage_non_negative already exists';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_shipping_percentage_non_negative'
  ) THEN
    ALTER TABLE "CostSettings"
    ADD CONSTRAINT check_shipping_percentage_non_negative 
    CHECK (shipping_percentage >= 0);
    
    RAISE NOTICE '✅ Added constraint: shipping_percentage >= 0';
  ELSE
    RAISE NOTICE 'ℹ️  Constraint check_shipping_percentage_non_negative already exists';
  END IF;

  -- Update existing CostSettings to use defaults if percentages are NULL
  UPDATE "CostSettings"
  SET labor_percentage = 10.0000
  WHERE labor_percentage IS NULL;

  UPDATE "CostSettings"
  SET shipping_percentage = 15.0000
  WHERE shipping_percentage IS NULL;

  RAISE NOTICE '✅ Updated existing CostSettings with default percentages';

  -- ====================================================
  -- STEP 2: Update QuoteLineCosts table
  -- ====================================================

  -- Add labor_source column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLineCosts' 
    AND column_name = 'labor_source'
  ) THEN
    ALTER TABLE "QuoteLineCosts" 
    ADD COLUMN labor_source text NOT NULL DEFAULT 'auto';
    
    RAISE NOTICE '✅ Added labor_source column (default: auto)';
  ELSE
    RAISE NOTICE 'ℹ️  Column labor_source already exists';
  END IF;

  -- Add shipping_source column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLineCosts' 
    AND column_name = 'shipping_source'
  ) THEN
    ALTER TABLE "QuoteLineCosts" 
    ADD COLUMN shipping_source text NOT NULL DEFAULT 'auto';
    
    RAISE NOTICE '✅ Added shipping_source column (default: auto)';
  ELSE
    RAISE NOTICE 'ℹ️  Column shipping_source already exists';
  END IF;

  -- Add check constraints for source values
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_labor_source_valid'
  ) THEN
    ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_labor_source_valid 
    CHECK (labor_source IN ('auto', 'manual'));
    
    RAISE NOTICE '✅ Added constraint: labor_source IN (auto, manual)';
  ELSE
    RAISE NOTICE 'ℹ️  Constraint check_labor_source_valid already exists';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_shipping_source_valid'
  ) THEN
    ALTER TABLE "QuoteLineCosts"
    ADD CONSTRAINT check_shipping_source_valid 
    CHECK (shipping_source IN ('auto', 'manual'));
    
    RAISE NOTICE '✅ Added constraint: shipping_source IN (auto, manual)';
  ELSE
    RAISE NOTICE 'ℹ️  Constraint check_shipping_source_valid already exists';
  END IF;

  -- Update existing QuoteLineCosts to use 'auto' if source is NULL
  UPDATE "QuoteLineCosts"
  SET labor_source = 'auto'
  WHERE labor_source IS NULL;

  UPDATE "QuoteLineCosts"
  SET shipping_source = 'auto'
  WHERE shipping_source IS NULL;

  RAISE NOTICE '✅ Updated existing QuoteLineCosts with default sources';

  -- ====================================================
  -- STEP 3: Add comments
  -- ====================================================

  COMMENT ON COLUMN "CostSettings".labor_percentage IS 'Default labor cost as percentage of base material cost (e.g., 10.0000 for 10%%)';
  COMMENT ON COLUMN "CostSettings".shipping_percentage IS 'Default shipping cost as percentage of base material cost (e.g., 15.0000 for 15%%)';
  COMMENT ON COLUMN "QuoteLineCosts".labor_source IS 'Source of labor_cost: auto (calculated from percentage) or manual (user override)';
  COMMENT ON COLUMN "QuoteLineCosts".shipping_source IS 'Source of shipping_cost: auto (calculated from percentage) or manual (user override)';

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Cost Engine v1 migration completed successfully';
  RAISE NOTICE '====================================================';
END $$;

