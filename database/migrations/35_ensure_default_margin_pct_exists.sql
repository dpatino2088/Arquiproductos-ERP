-- ====================================================
-- Migration: Ensure default_margin_pct and msrp exist in CatalogItems
-- ====================================================
-- This migration ensures these columns exist and refreshes Supabase schema cache
-- ====================================================

DO $$
DECLARE
  col_count integer;
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Ensuring default_margin_pct and msrp columns exist';
  RAISE NOTICE '====================================================';

  -- Check if CatalogItems table exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems'
  ) THEN
    RAISE EXCEPTION 'CatalogItems table does not exist. Please create it first.';
  END IF;

  -- Add default_margin_pct column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'default_margin_pct'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN default_margin_pct numeric(8,4) DEFAULT 35.00;
    
    RAISE NOTICE '✅ Added default_margin_pct column (default: 35.00%%)';
    
    -- Update existing rows to have default value
    UPDATE public."CatalogItems"
    SET default_margin_pct = 35.00
    WHERE default_margin_pct IS NULL;
    
    RAISE NOTICE '✅ Updated existing rows with default value';
  ELSE
    RAISE NOTICE 'ℹ️  Column default_margin_pct already exists';
    
    -- Ensure it's not null and has default
    ALTER TABLE public."CatalogItems"
    ALTER COLUMN default_margin_pct SET DEFAULT 35.00;
    
    -- Update NULL values
    UPDATE public."CatalogItems"
    SET default_margin_pct = 35.00
    WHERE default_margin_pct IS NULL;
  END IF;

  -- Add msrp column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'msrp'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN msrp numeric(12,4);
    
    RAISE NOTICE '✅ Added msrp column';
  ELSE
    RAISE NOTICE 'ℹ️  Column msrp already exists';
  END IF;

  -- Verify columns exist
  RAISE NOTICE '';
  RAISE NOTICE '📊 Verifying columns...';
  
  SELECT COUNT(*) INTO col_count
  FROM information_schema.columns 
  WHERE table_schema = 'public' 
  AND table_name = 'CatalogItems' 
  AND column_name IN ('default_margin_pct', 'msrp');
  
  RAISE NOTICE '✅ Found % required columns (expected 2)', col_count;
  
  IF col_count < 2 THEN
    RAISE WARNING '⚠️  Some columns may be missing. Expected 2, found %', col_count;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration completed successfully';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  IMPORTANT: After running this migration,';
  RAISE NOTICE '   you may need to refresh Supabase schema cache:';
  RAISE NOTICE '   1. Go to Supabase Dashboard';
  RAISE NOTICE '   2. Settings → API → Rebuild Schema Cache';
  RAISE NOTICE '   OR wait a few minutes for auto-refresh';
  RAISE NOTICE '';
END $$;

