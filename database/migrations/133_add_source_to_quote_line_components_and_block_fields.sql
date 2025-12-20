-- ====================================================
-- Migration: Add source to QuoteLineComponents and block fields to QuoteLines
-- ====================================================
-- This adds:
-- 1. source column to QuoteLineComponents to track component origin
-- 2. Block decision fields to QuoteLines to store customer choices
-- ====================================================

DO $$
DECLARE
  col_exists boolean;
BEGIN
  RAISE NOTICE '🔧 Adding source to QuoteLineComponents and block fields to QuoteLines...';
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 1: Add source to QuoteLineComponents
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLineComponents'
    AND column_name = 'source'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLineComponents" 
      ADD COLUMN source text DEFAULT 'bom_template';
    RAISE NOTICE '  ✅ Added source column to QuoteLineComponents';
  ELSE
    RAISE NOTICE '  ℹ️  source column already exists in QuoteLineComponents';
  END IF;

  -- Add constraint for source
  ALTER TABLE public."QuoteLineComponents"
    DROP CONSTRAINT IF EXISTS check_source_valid;
  
  ALTER TABLE public."QuoteLineComponents"
    ADD CONSTRAINT check_source_valid 
    CHECK (
      source IN ('bom_template', 'configured_component', 'manual')
    );
  RAISE NOTICE '  ✅ Added check_source_valid constraint';

  COMMENT ON COLUMN public."QuoteLineComponents".source IS 
    'Origin of component: bom_template (from BOMTemplate), configured_component (from block system), manual (manually added)';

  -- ====================================================
  -- STEP 2: Add block decision fields to QuoteLines
  -- ====================================================
  
  -- drive_type
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'drive_type'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN drive_type text;
    RAISE NOTICE '  ✅ Added drive_type column to QuoteLines';
  ELSE
    RAISE NOTICE '  ℹ️  drive_type column already exists';
  END IF;

  -- bottom_rail_type
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'bottom_rail_type'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN bottom_rail_type text;
    RAISE NOTICE '  ✅ Added bottom_rail_type column to QuoteLines';
  ELSE
    RAISE NOTICE '  ℹ️  bottom_rail_type column already exists';
  END IF;

  -- cassette
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'cassette'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN cassette boolean DEFAULT false;
    RAISE NOTICE '  ✅ Added cassette column to QuoteLines';
  ELSE
    RAISE NOTICE '  ℹ️  cassette column already exists';
  END IF;

  -- side_channel
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'side_channel'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN side_channel boolean DEFAULT false;
    RAISE NOTICE '  ✅ Added side_channel column to QuoteLines';
  ELSE
    RAISE NOTICE '  ℹ️  side_channel column already exists';
  END IF;

  -- hardware_color (if not exists, may already exist as operatingSystemColor)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'hardware_color'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN hardware_color text;
    RAISE NOTICE '  ✅ Added hardware_color column to QuoteLines';
  ELSE
    RAISE NOTICE '  ℹ️  hardware_color column already exists';
  END IF;

  -- ====================================================
  -- STEP 3: Add constraints
  -- ====================================================
  ALTER TABLE public."QuoteLines"
    DROP CONSTRAINT IF EXISTS check_drive_type_valid;
  
  ALTER TABLE public."QuoteLines"
    ADD CONSTRAINT check_drive_type_valid 
    CHECK (
      drive_type IS NULL 
      OR drive_type IN ('manual', 'motor')
    );
  RAISE NOTICE '  ✅ Added check_drive_type_valid constraint';

  ALTER TABLE public."QuoteLines"
    DROP CONSTRAINT IF EXISTS check_bottom_rail_type_valid;
  
  ALTER TABLE public."QuoteLines"
    ADD CONSTRAINT check_bottom_rail_type_valid 
    CHECK (
      bottom_rail_type IS NULL 
      OR bottom_rail_type IN ('standard', 'wrapped')
    );
  RAISE NOTICE '  ✅ Added check_bottom_rail_type_valid constraint';

  ALTER TABLE public."QuoteLines"
    DROP CONSTRAINT IF EXISTS check_hardware_color_valid_quote;
  
  ALTER TABLE public."QuoteLines"
    ADD CONSTRAINT check_hardware_color_valid_quote 
    CHECK (
      hardware_color IS NULL 
      OR hardware_color IN ('white', 'black', 'silver', 'bronze')
    );
  RAISE NOTICE '  ✅ Added check_hardware_color_valid constraint';

  -- ====================================================
  -- STEP 4: Add comments
  -- ====================================================
  COMMENT ON COLUMN public."QuoteLines".drive_type IS 
    'Drive type selection: manual or motor. Determines which drive block components are included.';
  
  COMMENT ON COLUMN public."QuoteLines".bottom_rail_type IS 
    'Bottom rail type: standard or wrapped. Determines which bottom rail block components are included.';
  
  COMMENT ON COLUMN public."QuoteLines".cassette IS 
    'Whether cassette block is included in the BOM.';
  
  COMMENT ON COLUMN public."QuoteLines".side_channel IS 
    'Whether side channel block is included in the BOM.';
  
  COMMENT ON COLUMN public."QuoteLines".hardware_color IS 
    'Hardware color selection (white, black, silver, bronze). Filters components with applies_color=true.';

  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration completed successfully!';
  RAISE NOTICE '📝 QuoteLineComponents now has source tracking.';
  RAISE NOTICE '📝 QuoteLines now stores block decision fields.';

END $$;

