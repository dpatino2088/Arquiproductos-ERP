-- ====================================================
-- Migration: Update discount_source Constraint
-- ====================================================
-- Updates the discount_source check constraint to include new values:
-- 'customer_type' | 'manual_customer' | 'manual_line'
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Updating discount_source constraint';
  RAISE NOTICE '====================================================';

  -- Drop existing constraint if it exists
  IF EXISTS (
    SELECT 1 
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu 
      ON tc.constraint_name = ccu.constraint_name
    WHERE tc.table_schema = 'public'
      AND tc.table_name = 'QuoteLines'
      AND tc.constraint_type = 'CHECK'
      AND tc.constraint_name = 'check_discount_source_valid'
  ) THEN
    ALTER TABLE "QuoteLines"
      DROP CONSTRAINT check_discount_source_valid;
    
    RAISE NOTICE '✅ Dropped old discount_source constraint';
  END IF;

  -- Add new constraint with updated values
  ALTER TABLE "QuoteLines"
    ADD CONSTRAINT check_discount_source_valid
    CHECK (
      discount_source IS NULL 
      OR discount_source IN ('customer_type', 'manual_customer', 'manual_line')
    );
  
  RAISE NOTICE '✅ Added new discount_source constraint';
  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration complete';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
END $$;





