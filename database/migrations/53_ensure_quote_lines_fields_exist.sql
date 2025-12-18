-- Migration: Ensure all QuoteLines fields exist for accessories support
-- This migration ensures that collection_id, variant_id, collection_name, variant_name, 
-- product_type, area, and position exist in QuoteLines table

DO $$
DECLARE
  col_exists boolean;
  target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
  rec RECORD;
BEGIN
  RAISE NOTICE '🔧 Ensuring QuoteLines fields exist...';

  -- Check if QuoteLines table exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
  ) INTO col_exists;

  IF NOT col_exists THEN
    RAISE EXCEPTION 'QuoteLines table does not exist. Please run create_catalog_and_quotes_tables.sql first.';
  END IF;

  -- ====================================================
  -- STEP 1: Add collection_id (uuid, nullable) if it doesn't exist
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'collection_id'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN collection_id uuid;
    
    RAISE NOTICE '✅ Added collection_id column to QuoteLines';
  ELSE
    RAISE NOTICE 'ℹ️  Column collection_id already exists';
  END IF;

  -- ====================================================
  -- STEP 2: Add variant_id (uuid, nullable) if it doesn't exist
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'variant_id'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN variant_id uuid;
    
    RAISE NOTICE '✅ Added variant_id column to QuoteLines';
  ELSE
    RAISE NOTICE 'ℹ️  Column variant_id already exists';
  END IF;

  -- ====================================================
  -- STEP 3: Add collection_name (text, nullable) if it doesn't exist
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'collection_name'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN collection_name text;
    
    RAISE NOTICE '✅ Added collection_name column to QuoteLines';
  ELSE
    RAISE NOTICE 'ℹ️  Column collection_name already exists';
  END IF;

  -- ====================================================
  -- STEP 4: Add variant_name (text, nullable) if it doesn't exist
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'variant_name'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN variant_name text;
    
    RAISE NOTICE '✅ Added variant_name column to QuoteLines';
  ELSE
    RAISE NOTICE 'ℹ️  Column variant_name already exists';
  END IF;

  -- ====================================================
  -- STEP 5: Add product_type (text, nullable) if it doesn't exist
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'product_type'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN product_type text;
    
    RAISE NOTICE '✅ Added product_type column to QuoteLines';
  ELSE
    RAISE NOTICE 'ℹ️  Column product_type already exists';
  END IF;

  -- ====================================================
  -- STEP 6: Add area (text, nullable) if it doesn't exist
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'area'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN area text;
    
    RAISE NOTICE '✅ Added area column to QuoteLines';
  ELSE
    RAISE NOTICE 'ℹ️  Column area already exists';
  END IF;

  -- ====================================================
  -- STEP 7: Add position (text, nullable) if it doesn't exist
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'position'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN position text;
    
    RAISE NOTICE '✅ Added position column to QuoteLines';
  ELSE
    RAISE NOTICE 'ℹ️  Column position already exists';
  END IF;

  -- ====================================================
  -- STEP 8: Create indexes for new columns (if needed)
  -- ====================================================
  CREATE INDEX IF NOT EXISTS idx_quote_lines_collection_id 
    ON public."QuoteLines"(collection_id) 
    WHERE collection_id IS NOT NULL;

  CREATE INDEX IF NOT EXISTS idx_quote_lines_variant_id 
    ON public."QuoteLines"(variant_id) 
    WHERE variant_id IS NOT NULL;

  CREATE INDEX IF NOT EXISTS idx_quote_lines_product_type 
    ON public."QuoteLines"(product_type) 
    WHERE product_type IS NOT NULL;

  RAISE NOTICE '✅ Created indexes for QuoteLines fields';

  -- ====================================================
  -- STEP 9: Verify all columns exist
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '📋 Verifying QuoteLines columns:';
  
  FOR rec IN 
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'QuoteLines'
      AND column_name IN ('collection_id', 'variant_id', 'collection_name', 'variant_name', 'product_type', 'area', 'position')
    ORDER BY column_name
  LOOP
    RAISE NOTICE '   ✅ % - Type: %, Nullable: %', rec.column_name, rec.data_type, rec.is_nullable;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration completed successfully!';
  RAISE NOTICE '📝 All QuoteLines fields are ready for accessories support.';

END $$;

