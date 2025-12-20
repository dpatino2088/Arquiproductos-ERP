-- ====================================================
-- Migration: Add component_role to QuoteLineComponents
-- ====================================================
-- This migration adds component_role column to QuoteLineComponents
-- to identify which BOM component each QuoteLineComponent represents.
-- This allows us to identify the operating system drive and other components
-- that come from the BOM Template (ConfiguratedProduct).
-- ====================================================

DO $$
DECLARE
  col_exists boolean;
BEGIN
  RAISE NOTICE '🔧 Adding component_role to QuoteLineComponents...';

  -- ====================================================
  -- STEP 1: Check if column already exists
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLineComponents'
    AND column_name = 'component_role'
  ) INTO col_exists;

  IF col_exists THEN
    RAISE NOTICE 'ℹ️  Column component_role already exists in QuoteLineComponents';
    
    -- Check if column has NOT NULL constraint and remove it if needed
    -- We need component_role to be nullable for legacy data
    BEGIN
      ALTER TABLE public."QuoteLineComponents" 
        ALTER COLUMN component_role DROP NOT NULL;
      RAISE NOTICE '✅ Removed NOT NULL constraint from component_role (if it existed)';
    EXCEPTION
      WHEN OTHERS THEN
        -- If there's no NOT NULL constraint, that's fine
        RAISE NOTICE 'ℹ️  No NOT NULL constraint to remove (or already removed)';
    END;
  ELSE
    -- ====================================================
    -- STEP 2: Add component_role column
    -- ====================================================
    ALTER TABLE public."QuoteLineComponents" 
      ADD COLUMN component_role text;
    
    RAISE NOTICE '✅ Added component_role column to QuoteLineComponents';
  END IF;

  -- ====================================================
  -- STEP 3: Clean existing data (set invalid values to NULL)
  -- ====================================================
  -- First, set any invalid component_role values to NULL
  -- This handles legacy data that might have invalid values
  UPDATE public."QuoteLineComponents"
  SET component_role = NULL
  WHERE component_role IS NOT NULL
    AND component_role NOT IN (
      'fabric',
      'tube',
      'bracket',
      'cassette',
      'bottom_bar',
      'operating_system_drive'
    );

  RAISE NOTICE '✅ Cleaned invalid component_role values (set to NULL)';

  -- ====================================================
  -- STEP 4: Add CHECK constraint for valid values
  -- ====================================================
  -- Drop existing constraint if it exists
  ALTER TABLE public."QuoteLineComponents"
    DROP CONSTRAINT IF EXISTS check_component_role_valid;

  -- Add constraint with valid component roles
  ALTER TABLE public."QuoteLineComponents"
    ADD CONSTRAINT check_component_role_valid 
    CHECK (
      component_role IS NULL 
      OR component_role IN (
        'fabric',           -- Fabric/tela
        'tube',             -- Tube/tubo
        'bracket',          -- Bracket/soporte
        'cassette',         -- Cassette
        'bottom_bar',       -- Bottom bar/barra inferior
        'operating_system_drive'  -- Operating system drive (motor/manual)
      )
    );

  RAISE NOTICE '✅ Added CHECK constraint for component_role';

  -- ====================================================
  -- STEP 5: Create index for efficient queries
  -- ====================================================
  CREATE INDEX IF NOT EXISTS idx_quote_line_components_role 
    ON public."QuoteLineComponents"(quote_line_id, component_role) 
    WHERE component_role IS NOT NULL;

  RAISE NOTICE '✅ Created index for component_role';

  -- ====================================================
  -- STEP 6: Add comment
  -- ====================================================
  COMMENT ON COLUMN public."QuoteLineComponents".component_role IS 
    'Role of this component in the BOM (fabric, tube, bracket, cassette, bottom_bar, operating_system_drive). NULL for legacy components or non-BOM items.';

  RAISE NOTICE '✅ Added comment to component_role column';

  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration completed successfully!';
  RAISE NOTICE '📝 QuoteLineComponents now supports component_role to identify BOM components.';
  RAISE NOTICE '   Valid values: fabric, tube, bracket, cassette, bottom_bar, operating_system_drive';

END $$;

