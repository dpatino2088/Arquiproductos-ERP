-- ====================================================
-- Migration: Add block-based structure to BOMComponents
-- ====================================================
-- This adds fields needed for the configured component block system
-- where each customer choice activates a BOM block
-- ====================================================

DO $$
DECLARE
  col_exists boolean;
BEGIN
  RAISE NOTICE '🔧 Adding block structure to BOMComponents...';
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 1: Add block_type column
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
    AND column_name = 'block_type'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."BOMComponents" 
      ADD COLUMN block_type text;
    RAISE NOTICE '  ✅ Added block_type column';
  ELSE
    RAISE NOTICE '  ℹ️  block_type column already exists';
  END IF;

  -- ====================================================
  -- STEP 2: Add block_condition column (JSONB)
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
    AND column_name = 'block_condition'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."BOMComponents" 
      ADD COLUMN block_condition jsonb;
    RAISE NOTICE '  ✅ Added block_condition column';
  ELSE
    RAISE NOTICE '  ℹ️  block_condition column already exists';
  END IF;

  -- ====================================================
  -- STEP 3: Add applies_color column
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
    AND column_name = 'applies_color'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."BOMComponents" 
      ADD COLUMN applies_color boolean DEFAULT false;
    RAISE NOTICE '  ✅ Added applies_color column';
  ELSE
    RAISE NOTICE '  ℹ️  applies_color column already exists';
  END IF;

  -- ====================================================
  -- STEP 4: Add hardware_color column
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
    AND column_name = 'hardware_color'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."BOMComponents" 
      ADD COLUMN hardware_color text;
    RAISE NOTICE '  ✅ Added hardware_color column';
  ELSE
    RAISE NOTICE '  ℹ️  hardware_color column already exists';
  END IF;

  -- ====================================================
  -- STEP 5: Add sku_resolution_rule column
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
    AND column_name = 'sku_resolution_rule'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."BOMComponents" 
      ADD COLUMN sku_resolution_rule text;
    RAISE NOTICE '  ✅ Added sku_resolution_rule column';
  ELSE
    RAISE NOTICE '  ℹ️  sku_resolution_rule column already exists';
  END IF;

  -- ====================================================
  -- STEP 6: Verify component_role and auto_select exist
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
    AND column_name = 'component_role'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."BOMComponents" 
      ADD COLUMN component_role text;
    RAISE NOTICE '  ✅ Added component_role column';
  ELSE
    RAISE NOTICE '  ℹ️  component_role column already exists';
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents'
    AND column_name = 'auto_select'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public."BOMComponents" 
      ADD COLUMN auto_select boolean DEFAULT false;
    RAISE NOTICE '  ✅ Added auto_select column';
  ELSE
    RAISE NOTICE '  ℹ️  auto_select column already exists';
  END IF;

  -- ====================================================
  -- STEP 7: Add constraints
  -- ====================================================
  -- Drop existing constraints if they exist
  ALTER TABLE public."BOMComponents"
    DROP CONSTRAINT IF EXISTS check_block_type_valid;
  
  ALTER TABLE public."BOMComponents"
    ADD CONSTRAINT check_block_type_valid 
    CHECK (
      block_type IS NULL 
      OR block_type IN ('drive', 'brackets', 'bottom_rail', 'cassette', 'side_channel')
    );
  RAISE NOTICE '  ✅ Added check_block_type_valid constraint';

  ALTER TABLE public."BOMComponents"
    DROP CONSTRAINT IF EXISTS check_hardware_color_valid_bom;
  
  ALTER TABLE public."BOMComponents"
    ADD CONSTRAINT check_hardware_color_valid_bom 
    CHECK (
      hardware_color IS NULL 
      OR hardware_color IN ('white', 'black', 'silver', 'bronze')
    );
  RAISE NOTICE '  ✅ Added check_hardware_color_valid constraint';

  -- ====================================================
  -- STEP 8: Create indexes
  -- ====================================================
  CREATE INDEX IF NOT EXISTS idx_bomcomponents_block_type 
    ON public."BOMComponents"(bom_template_id, block_type) 
    WHERE deleted = false;

  CREATE INDEX IF NOT EXISTS idx_bomcomponents_hardware_color 
    ON public."BOMComponents"(bom_template_id, hardware_color, applies_color) 
    WHERE deleted = false AND applies_color = true;

  RAISE NOTICE '  ✅ Created indexes';

  -- ====================================================
  -- STEP 9: Add comments
  -- ====================================================
  COMMENT ON COLUMN public."BOMComponents".block_type IS 
    'Type of BOM block: drive, brackets, bottom_rail, cassette, side_channel';
  
  COMMENT ON COLUMN public."BOMComponents".block_condition IS 
    'JSONB condition for block activation. NULL = always active. Example: {"drive_type": "motor"}, {"cassette": true}';
  
  COMMENT ON COLUMN public."BOMComponents".applies_color IS 
    'Whether this component color depends on hardware_color selection';
  
  COMMENT ON COLUMN public."BOMComponents".hardware_color IS 
    'Hardware color for this component (white, black, silver, bronze). NULL if applies_color = false';
  
  COMMENT ON COLUMN public."BOMComponents".sku_resolution_rule IS 
    'Rule for resolving SKU: direct, width_rule_42_65_80, etc.';

  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration completed successfully!';
  RAISE NOTICE '📝 BOMComponents now supports block-based structure with multiple components per color.';

END $$;

