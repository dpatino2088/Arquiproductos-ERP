-- ====================================================
-- Migration: Add Discount Fields to QuoteLines
-- ====================================================
-- Adds fields to track discount percentage and source
-- for price calculation using Customer Pricing Tiers
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Adding discount fields to QuoteLines';
  RAISE NOTICE '====================================================';

  -- Step 1: Add discount_percentage to QuoteLines
  -- This stores the actual discount percentage applied
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'QuoteLines' 
      AND column_name = 'discount_percentage'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD COLUMN discount_percentage numeric(8,4) NULL
      CHECK (discount_percentage IS NULL OR (discount_percentage >= 0 AND discount_percentage <= 100));
    
    RAISE NOTICE '✅ Added discount_percentage to QuoteLines';
  ELSE
    RAISE NOTICE '⚠️  discount_percentage already exists in QuoteLines';
  END IF;

  -- Step 2: Add discount_amount to QuoteLines
  -- This stores the calculated discount amount (unit_price * discount_percentage / 100)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'QuoteLines' 
      AND column_name = 'discount_amount'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD COLUMN discount_amount numeric(12,4) NULL
      CHECK (discount_amount IS NULL OR discount_amount >= 0);
    
    RAISE NOTICE '✅ Added discount_amount to QuoteLines';
  ELSE
    RAISE NOTICE '⚠️  discount_amount already exists in QuoteLines';
  END IF;

  -- Step 3: Add discount_source to QuoteLines
  -- This indicates where the discount came from: 'tier', 'manual', or NULL
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'QuoteLines' 
      AND column_name = 'discount_source'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD COLUMN discount_source text NULL
      CHECK (discount_source IS NULL OR discount_source IN ('tier', 'manual'));
    
    RAISE NOTICE '✅ Added discount_source to QuoteLines';
  ELSE
    RAISE NOTICE '⚠️  discount_source already exists in QuoteLines';
  END IF;

  -- Step 4: Add final_unit_price to QuoteLines
  -- This stores the final unit price after discount (unit_price - discount_amount)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'QuoteLines' 
      AND column_name = 'final_unit_price'
  ) THEN
    ALTER TABLE public."QuoteLines"
      ADD COLUMN final_unit_price numeric(12,4) NULL
      CHECK (final_unit_price IS NULL OR final_unit_price >= 0);
    
    RAISE NOTICE '✅ Added final_unit_price to QuoteLines';
  ELSE
    RAISE NOTICE '⚠️  final_unit_price already exists in QuoteLines';
  END IF;

  -- Step 5: Add indexes for reporting
  CREATE INDEX IF NOT EXISTS idx_quote_lines_discount_percentage 
    ON public."QuoteLines"(discount_percentage) 
    WHERE discount_percentage IS NOT NULL;

  CREATE INDEX IF NOT EXISTS idx_quote_lines_discount_source 
    ON public."QuoteLines"(discount_source) 
    WHERE discount_source IS NOT NULL;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration complete';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Fields added:';
  RAISE NOTICE '  - QuoteLines.discount_percentage (numeric)';
  RAISE NOTICE '  - QuoteLines.discount_amount (numeric)';
  RAISE NOTICE '  - QuoteLines.discount_source (text: tier|manual)';
  RAISE NOTICE '  - QuoteLines.final_unit_price (numeric)';
  RAISE NOTICE '';
END $$;





