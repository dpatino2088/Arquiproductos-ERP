-- ====================================================
-- Migration: Add product_type_id to QuoteLines
-- ====================================================
-- This allows QuoteLines to directly reference ProductTypes
-- for BOM lookup and product type display
-- ====================================================

DO $$
DECLARE
  col_exists boolean;
BEGIN
  RAISE NOTICE '🔧 Adding product_type_id to QuoteLines...';

  -- ====================================================
  -- STEP 1: Check if column already exists
  -- ====================================================
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'QuoteLines'
    AND column_name = 'product_type_id'
  ) INTO col_exists;

  IF col_exists THEN
    RAISE NOTICE 'ℹ️  Column product_type_id already exists in QuoteLines';
  ELSE
    -- ====================================================
    -- STEP 2: Add product_type_id column
    -- ====================================================
    ALTER TABLE public."QuoteLines" 
      ADD COLUMN product_type_id uuid;
    
    RAISE NOTICE '✅ Added product_type_id column to QuoteLines';
  END IF;

  -- ====================================================
  -- STEP 3: Create foreign key to ProductTypes
  -- ====================================================
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_schema = 'public' 
    AND constraint_name = 'fk_quote_lines_product_type'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD CONSTRAINT fk_quote_lines_product_type
      FOREIGN KEY (product_type_id)
      REFERENCES public."ProductTypes"(id)
      ON DELETE SET NULL;
    
    RAISE NOTICE '✅ Created foreign key to ProductTypes';
  ELSE
    RAISE NOTICE 'ℹ️  Foreign key fk_quote_lines_product_type already exists';
  END IF;

  -- ====================================================
  -- STEP 4: Create index for efficient queries
  -- ====================================================
  CREATE INDEX IF NOT EXISTS idx_quote_lines_product_type_id 
    ON public."QuoteLines"(product_type_id) 
    WHERE product_type_id IS NOT NULL;

  RAISE NOTICE '✅ Created index for product_type_id';

  -- ====================================================
  -- STEP 5: Add comment
  -- ====================================================
  COMMENT ON COLUMN public."QuoteLines".product_type_id IS 
    'Foreign key to ProductTypes. Used for BOM lookup and product type display.';

  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration completed successfully!';
  RAISE NOTICE '📝 QuoteLines now supports product_type_id for BOM lookup.';

END $$;

