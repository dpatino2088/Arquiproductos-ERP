-- Fix discount_source constraint to accept 'customer_type'
-- This should match migration 51, but ensures it works regardless of constraint name

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Fixing discount_source constraint';
  RAISE NOTICE '====================================================';

  -- Drop all possible constraint names related to discount_source
  -- Common constraint names PostgreSQL might use
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE table_schema = 'public'
      AND table_name = 'QuoteLines'
      AND constraint_type = 'CHECK'
      AND constraint_name LIKE '%discount_source%'
  ) THEN
    -- Get constraint name and drop it
    DECLARE
      constraint_name_var text;
    BEGIN
      SELECT constraint_name INTO constraint_name_var
      FROM information_schema.table_constraints
      WHERE table_schema = 'public'
        AND table_name = 'QuoteLines'
        AND constraint_type = 'CHECK'
        AND constraint_name LIKE '%discount_source%'
      LIMIT 1;
      
      IF constraint_name_var IS NOT NULL THEN
        EXECUTE format('ALTER TABLE "QuoteLines" DROP CONSTRAINT IF EXISTS %I', constraint_name_var);
        RAISE NOTICE '✅ Dropped constraint: %', constraint_name_var;
      END IF;
    END;
  END IF;

  -- Drop specific known constraint names
  ALTER TABLE "QuoteLines" DROP CONSTRAINT IF EXISTS "QuoteLines_discount_source_check";
  ALTER TABLE "QuoteLines" DROP CONSTRAINT IF EXISTS "check_discount_source_valid";
  ALTER TABLE "QuoteLines" DROP CONSTRAINT IF EXISTS "QuoteLines_discount_source_check1";

  -- Add new constraint with correct values
  ALTER TABLE "QuoteLines"
    ADD CONSTRAINT "check_discount_source_valid"
    CHECK (
      discount_source IS NULL 
      OR discount_source IN ('customer_type', 'manual_customer', 'manual_line', 'tier', 'manual')
    );
  
  RAISE NOTICE '✅ Added new discount_source constraint';
  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration complete';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
END $$;





