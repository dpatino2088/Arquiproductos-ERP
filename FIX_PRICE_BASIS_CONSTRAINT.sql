-- Fix price_basis constraint to accept correct enum values
-- Values: 'MSRP_TIER', 'MARGIN_FLOOR', 'MANUAL', NULL
-- Also ensures discount_source constraint is properly set

DO $$
DECLARE
  constraint_rec record;
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Fixing price_basis and discount_source constraints';
  RAISE NOTICE '====================================================';

  -- ====================================================
  -- Step 1: Fix price_basis constraint
  -- ====================================================
  
  -- Drop existing price_basis constraints
  FOR constraint_rec IN
    SELECT constraint_name
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name = 'QuoteLines'
      AND constraint_type = 'CHECK'
      AND constraint_name LIKE '%price_basis%'
  LOOP
    EXECUTE format('ALTER TABLE "QuoteLines" DROP CONSTRAINT IF EXISTS %I', constraint_rec.constraint_name);
    RAISE NOTICE '✅ Dropped price_basis constraint: %', constraint_rec.constraint_name;
  END LOOP;

  -- Also try to drop by specific known names
  ALTER TABLE "QuoteLines" DROP CONSTRAINT IF EXISTS "QuoteLines_price_basis_check";
  ALTER TABLE "QuoteLines" DROP CONSTRAINT IF EXISTS "check_price_basis_valid";

  -- Add new price_basis constraint with correct enum values
  ALTER TABLE "QuoteLines"
    ADD CONSTRAINT "check_price_basis_valid"
    CHECK (
      price_basis IS NULL 
      OR price_basis IN ('MSRP_TIER', 'MARGIN_FLOOR', 'MANUAL')
    );
  
  RAISE NOTICE '✅ Added new price_basis constraint';

  -- ====================================================
  -- Step 2: Fix discount_source constraint (if exists)
  -- ====================================================
  
  -- Drop existing discount_source constraints
  FOR constraint_rec IN
    SELECT constraint_name
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name = 'QuoteLines'
      AND constraint_type = 'CHECK'
      AND constraint_name LIKE '%discount_source%'
  LOOP
    EXECUTE format('ALTER TABLE "QuoteLines" DROP CONSTRAINT IF EXISTS %I', constraint_rec.constraint_name);
    RAISE NOTICE '✅ Dropped discount_source constraint: %', constraint_rec.constraint_name;
  END LOOP;

  -- Also try to drop by specific known names
  ALTER TABLE "QuoteLines" DROP CONSTRAINT IF EXISTS "QuoteLines_discount_source_check";
  ALTER TABLE "QuoteLines" DROP CONSTRAINT IF EXISTS "check_discount_source_valid";

  -- Add new discount_source constraint (allows NULL or legacy values)
  -- This ensures backward compatibility
  ALTER TABLE "QuoteLines"
    ADD CONSTRAINT "check_discount_source_valid"
    CHECK (
      discount_source IS NULL 
      OR discount_source IN ('tier', 'manual', 'customer_type', 'manual_customer', 'manual_line')
    );
  
  RAISE NOTICE '✅ Added new discount_source constraint';
  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration complete';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Constraints updated:';
  RAISE NOTICE '  - price_basis: NULL | MSRP_TIER | MARGIN_FLOOR | MANUAL';
  RAISE NOTICE '  - discount_source: NULL | tier | manual | customer_type | manual_customer | manual_line';
  RAISE NOTICE '';
END $$;
