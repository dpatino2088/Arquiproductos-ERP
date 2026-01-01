-- ====================================================
-- Migration: Ensure CatalogItems columns exist
-- ====================================================
-- This migration ensures that collection_name, variant_name,
-- and default_margin_pct columns exist in CatalogItems
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Ensuring CatalogItems columns exist';
  RAISE NOTICE '====================================================';

  -- Check if CatalogItems table exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems'
  ) THEN
    RAISE EXCEPTION 'CatalogItems table does not exist. Please run migration 18 first.';
  END IF;

  -- Add collection_name column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'collection_name'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN collection_name text;
    
    RAISE NOTICE '✅ Added collection_name column';
    
    -- Create index on collection_name
    CREATE INDEX IF NOT EXISTS idx_catalogitems_collection_name 
      ON public."CatalogItems"(collection_name) 
      WHERE collection_name IS NOT NULL;
    
    RAISE NOTICE '✅ Created index on collection_name';
  ELSE
    RAISE NOTICE 'ℹ️  Column collection_name already exists';
  END IF;

  -- Add variant_name column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'variant_name'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN variant_name text;
    
    RAISE NOTICE '✅ Added variant_name column';
    
    -- Create index on variant_name
    CREATE INDEX IF NOT EXISTS idx_catalogitems_variant_name 
      ON public."CatalogItems"(variant_name) 
      WHERE variant_name IS NOT NULL;
    
    RAISE NOTICE '✅ Created index on variant_name';
  ELSE
    RAISE NOTICE 'ℹ️  Column variant_name already exists';
  END IF;

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

  -- Verify columns exist
  RAISE NOTICE '';
  RAISE NOTICE '📊 Verifying columns...';
  
  DO $$
  DECLARE
    col_count integer;
  BEGIN
    SELECT COUNT(*) INTO col_count
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name IN ('collection_name', 'variant_name', 'default_margin_pct', 'msrp');
    
    RAISE NOTICE '✅ Found % required columns', col_count;
    
    IF col_count < 4 THEN
      RAISE WARNING '⚠️  Some columns may be missing. Expected 4, found %', col_count;
    END IF;
  END $$;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Column verification completed';
  RAISE NOTICE '====================================================';
END $$;













