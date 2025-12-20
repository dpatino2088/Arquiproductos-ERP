-- ====================================================
-- Migration: Add Pricing Fields to CatalogItems
-- ====================================================
-- This migration adds MSRP and margin fields to CatalogItems
-- to support pricing tiers and customer discounts
-- ====================================================

DO $$
DECLARE
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Adding pricing fields to CatalogItems';
  RAISE NOTICE '====================================================';

  -- Add default_margin_pct column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'default_margin_pct'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN default_margin_pct numeric(5,2) DEFAULT 35.00;
    
    RAISE NOTICE '✅ Added default_margin_pct column (default: 35.00%%)';
  ELSE
    RAISE NOTICE 'ℹ️  Column default_margin_pct already exists';
  END IF;

  -- Add msrp column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'msrp'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN msrp numeric(12,2);
    
    RAISE NOTICE '✅ Added msrp column';
  ELSE
    RAISE NOTICE 'ℹ️  Column msrp already exists';
  END IF;

  -- Calculate MSRP for existing items where cost_exw exists but msrp is null
  RAISE NOTICE '';
  RAISE NOTICE '📊 Calculating MSRP for existing items...';
  
  UPDATE public."CatalogItems"
  SET msrp = ROUND(
    cost_exw * (1 + COALESCE(default_margin_pct, 35.00) / 100),
    2
  )
  WHERE cost_exw IS NOT NULL 
    AND cost_exw > 0
    AND (msrp IS NULL OR msrp = 0)
    AND organization_id = target_org_id;

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RAISE NOTICE '✅ Updated MSRP for % items', updated_count;

  -- Create index on msrp for faster pricing queries
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' 
    AND tablename = 'CatalogItems' 
    AND indexname = 'idx_catalogitems_msrp'
  ) THEN
    CREATE INDEX idx_catalogitems_msrp ON public."CatalogItems"(msrp) 
    WHERE msrp IS NOT NULL;
    
    RAISE NOTICE '✅ Created index on msrp';
  ELSE
    RAISE NOTICE 'ℹ️  Index on msrp already exists';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Pricing fields migration completed successfully';
  RAISE NOTICE '====================================================';
END $$;





