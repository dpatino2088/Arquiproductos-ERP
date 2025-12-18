-- ====================================================
-- Migration: Add default_value fields to CategoryMargins and ImportTaxRules
-- ====================================================
-- Adds fields to track if a rule uses the default value
-- and to store the default value for reference
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Adding default_value fields';
  RAISE NOTICE '====================================================';

  -- Step 1: Add default_value_percentage to CategoryMargins
  -- This will store the default margin percentage from CostSettings
  -- when the rule was created/updated
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'CategoryMargins' 
      AND column_name = 'default_value_percentage'
  ) THEN
    ALTER TABLE public."CategoryMargins"
      ADD COLUMN default_value_percentage numeric(8,4) NULL;
    
    RAISE NOTICE '✅ Added default_value_percentage to CategoryMargins';
  ELSE
    RAISE NOTICE '⚠️  default_value_percentage already exists in CategoryMargins';
  END IF;

  -- Step 2: Add is_using_default to CategoryMargins
  -- This indicates if the rule is using the default value
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'CategoryMargins' 
      AND column_name = 'is_using_default'
  ) THEN
    ALTER TABLE public."CategoryMargins"
      ADD COLUMN is_using_default boolean NOT NULL DEFAULT false;
    
    RAISE NOTICE '✅ Added is_using_default to CategoryMargins';
  ELSE
    RAISE NOTICE '⚠️  is_using_default already exists in CategoryMargins';
  END IF;

  -- Step 3: Add default_value_percentage to ImportTaxRules
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'ImportTaxRules' 
      AND column_name = 'default_value_percentage'
  ) THEN
    ALTER TABLE public."ImportTaxRules"
      ADD COLUMN default_value_percentage numeric(8,4) NULL;
    
    RAISE NOTICE '✅ Added default_value_percentage to ImportTaxRules';
  ELSE
    RAISE NOTICE '⚠️  default_value_percentage already exists in ImportTaxRules';
  END IF;

  -- Step 4: Add is_using_default to ImportTaxRules
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'ImportTaxRules' 
      AND column_name = 'is_using_default'
  ) THEN
    ALTER TABLE public."ImportTaxRules"
      ADD COLUMN is_using_default boolean NOT NULL DEFAULT false;
    
    RAISE NOTICE '✅ Added is_using_default to ImportTaxRules';
  ELSE
    RAISE NOTICE '⚠️  is_using_default already exists in ImportTaxRules';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration complete';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Fields added:';
  RAISE NOTICE '  - CategoryMargins.default_value_percentage (numeric)';
  RAISE NOTICE '  - CategoryMargins.is_using_default (boolean)';
  RAISE NOTICE '  - ImportTaxRules.default_value_percentage (numeric)';
  RAISE NOTICE '  - ImportTaxRules.is_using_default (boolean)';
  RAISE NOTICE '';
END $$;

