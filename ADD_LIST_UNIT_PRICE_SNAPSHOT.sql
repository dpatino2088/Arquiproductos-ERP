-- Add list_unit_price_snapshot column to QuoteLines if missing
-- This stores the MSRP (list price) separately from unit_price_snapshot (net price after discounts)

DO $$
BEGIN
  -- Check if column exists
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'QuoteLines' 
      AND column_name = 'list_unit_price_snapshot'
  ) THEN
    -- Add column
    ALTER TABLE "QuoteLines"
      ADD COLUMN "list_unit_price_snapshot" numeric(10, 2);
    
    RAISE NOTICE '✅ Added list_unit_price_snapshot column to QuoteLines';
  ELSE
    RAISE NOTICE '✅ Column list_unit_price_snapshot already exists';
  END IF;
END $$;

-- Add comment
COMMENT ON COLUMN "QuoteLines"."list_unit_price_snapshot" IS 
  'MSRP list price (precio de lista público) before any discounts. Source: CatalogItems.msrp';





