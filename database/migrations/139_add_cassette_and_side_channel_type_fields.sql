-- ====================================================
-- Migration: Add cassette_type and side_channel_type to QuoteLines
-- ====================================================
-- This adds fields to store the type/configuration of cassette and side_channel
-- when they are selected
-- ====================================================

DO $$
DECLARE
  col_exists boolean;
BEGIN
  RAISE NOTICE '🔧 Adding cassette_type and side_channel_type to QuoteLines...';
  RAISE NOTICE '';

  -- cassette_type
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'cassette_type'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN cassette_type text;
    RAISE NOTICE '  ✅ Added cassette_type column to QuoteLines';
  ELSE
    RAISE NOTICE '  ℹ️  cassette_type column already exists';
  END IF;

  -- side_channel_type
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'side_channel_type'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN side_channel_type text;
    RAISE NOTICE '  ✅ Added side_channel_type column to QuoteLines';
  ELSE
    RAISE NOTICE '  ℹ️  side_channel_type column already exists';
  END IF;

  -- Add constraints
  ALTER TABLE public."QuoteLines"
    DROP CONSTRAINT IF EXISTS check_cassette_type_valid;
  
  ALTER TABLE public."QuoteLines"
    ADD CONSTRAINT check_cassette_type_valid 
    CHECK (
      cassette_type IS NULL 
      OR cassette_type IN ('standard', 'recessed', 'surface')
    );
  RAISE NOTICE '  ✅ Added check_cassette_type_valid constraint';

  ALTER TABLE public."QuoteLines"
    DROP CONSTRAINT IF EXISTS check_side_channel_type_valid;
  
  ALTER TABLE public."QuoteLines"
    ADD CONSTRAINT check_side_channel_type_valid 
    CHECK (
      side_channel_type IS NULL 
      OR side_channel_type IN ('left', 'right', 'both')
    );
  RAISE NOTICE '  ✅ Added check_side_channel_type_valid constraint';

  -- Add comments
  COMMENT ON COLUMN public."QuoteLines".cassette_type IS 
    'Type of cassette when cassette = true: standard, recessed, or surface mount';
  
  COMMENT ON COLUMN public."QuoteLines".side_channel_type IS 
    'Position of side channel when side_channel = true: left, right, or both';

  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration completed successfully!';

END $$;

