-- ====================================================
-- Migration: Add Pricing Tier Fields to DirectoryCustomers
-- ====================================================
-- Adds pricing_tier_code and discount_pct directly to DirectoryCustomers
-- No separate table needed - tier is always related to each customer
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Adding pricing tier fields to DirectoryCustomers';
  RAISE NOTICE '====================================================';

  -- Step 1: Remove pricing_tier_id column if it exists (old FK approach)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'DirectoryCustomers' 
      AND column_name = 'pricing_tier_id'
  ) THEN
    -- Drop FK constraint first if it exists
    IF EXISTS (
      SELECT 1 
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu 
        ON tc.constraint_name = kcu.constraint_name
      WHERE tc.table_schema = 'public'
        AND tc.table_name = 'DirectoryCustomers'
        AND tc.constraint_type = 'FOREIGN KEY'
        AND kcu.column_name = 'pricing_tier_id'
    ) THEN
      ALTER TABLE public."DirectoryCustomers"
        DROP CONSTRAINT IF EXISTS fk_directory_customers_pricing_tier;
      
      RAISE NOTICE '✅ Dropped old FK constraint';
    END IF;

    -- Drop the column
    ALTER TABLE public."DirectoryCustomers"
      DROP COLUMN pricing_tier_id;
    
    RAISE NOTICE '✅ Removed old pricing_tier_id column';
  END IF;

  -- Step 2: Add pricing_tier_code column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'DirectoryCustomers' 
      AND column_name = 'pricing_tier_code'
  ) THEN
    ALTER TABLE public."DirectoryCustomers"
      ADD COLUMN pricing_tier_code text;
    
    RAISE NOTICE '✅ Added pricing_tier_code column';
  ELSE
    RAISE NOTICE 'ℹ️  Column pricing_tier_code already exists';
  END IF;

  -- Step 3: Add discount_pct column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'DirectoryCustomers' 
      AND column_name = 'discount_pct'
  ) THEN
    ALTER TABLE public."DirectoryCustomers"
      ADD COLUMN discount_pct numeric(5,2) DEFAULT 0.00 
      CHECK (discount_pct >= 0 AND discount_pct <= 100);
    
    RAISE NOTICE '✅ Added discount_pct column';
  ELSE
    RAISE NOTICE 'ℹ️  Column discount_pct already exists';
  END IF;

  -- Step 4: Create index on pricing_tier_code if it doesn't exist
  CREATE INDEX IF NOT EXISTS idx_directory_customers_pricing_tier_code 
    ON public."DirectoryCustomers"(pricing_tier_code) 
    WHERE pricing_tier_code IS NOT NULL;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration complete';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
END $$;

