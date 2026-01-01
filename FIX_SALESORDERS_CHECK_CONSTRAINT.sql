-- ====================================================
-- FIX: SalesOrders_status_check Constraint Violation
-- ====================================================
-- Error: "new row for relation "SalesOrders" violates check constraint "SalesOrders_status_check""
-- This script fixes the CHECK constraint to include all valid statuses
-- ====================================================

-- ====================================================
-- STEP 1: Check current constraint definition
-- ====================================================

DO $$
DECLARE
    v_constraint_def text;
    v_constraint_name text;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '🔍 Checking current CHECK constraint...';
    RAISE NOTICE '====================================================';
    
    -- Check for both possible names (plural and singular)
    SELECT constraint_name, check_clause INTO v_constraint_name, v_constraint_def
    FROM information_schema.check_constraints
    WHERE constraint_name IN ('SalesOrders_status_check', 'SaleOrders_status_check')
    LIMIT 1;
    
    IF v_constraint_def IS NOT NULL THEN
        RAISE NOTICE 'Found constraint: %', v_constraint_name;
        RAISE NOTICE 'Current definition:';
        RAISE NOTICE '%', v_constraint_def;
    ELSE
        RAISE WARNING '⚠️ CHECK constraint does not exist (checked both names)';
    END IF;
    
    RAISE NOTICE '';
END;
$$;

-- ====================================================
-- STEP 2: Drop existing constraints (both possible names)
-- ====================================================

ALTER TABLE "SalesOrders" 
DROP CONSTRAINT IF EXISTS "SalesOrders_status_check";

ALTER TABLE "SalesOrders" 
DROP CONSTRAINT IF EXISTS "SaleOrders_status_check";

-- ====================================================
-- STEP 3: Add correct CHECK constraint with ALL valid statuses
-- ====================================================

ALTER TABLE "SalesOrders"
ADD CONSTRAINT "SalesOrders_status_check" 
CHECK (status IN (
    'Draft',
    'Confirmed', 
    'Scheduled for Production',
    'In Production', 
    'Ready for Delivery',
    'Delivered',
    'Cancelled'
));

-- ====================================================
-- STEP 4: Verify constraint was created correctly
-- ====================================================

DO $$
DECLARE
    v_constraint_exists boolean;
    v_allows_scheduled boolean;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✅ CHECK Constraint Fixed';
    RAISE NOTICE '====================================================';
    
    -- Verify constraint exists (check both possible names)
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints tc
        JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
        WHERE tc.table_name = 'SalesOrders'
        AND tc.constraint_name IN ('SalesOrders_status_check', 'SaleOrders_status_check')
    ) INTO v_constraint_exists;
    
    IF v_constraint_exists THEN
        RAISE NOTICE '✅ CHECK constraint exists';
    ELSE
        RAISE WARNING '❌ CHECK constraint does NOT exist';
    END IF;
    
    -- Verify it allows "Scheduled for Production"
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.check_constraints
        WHERE constraint_name IN ('SalesOrders_status_check', 'SaleOrders_status_check')
        AND check_clause LIKE '%Scheduled for Production%'
    ) INTO v_allows_scheduled;
    
    IF v_allows_scheduled THEN
        RAISE NOTICE '✅ CHECK constraint allows "Scheduled for Production"';
    ELSE
        RAISE WARNING '⚠️ CHECK constraint may NOT allow "Scheduled for Production"';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 Allowed statuses:';
    RAISE NOTICE '   - Draft';
    RAISE NOTICE '   - Confirmed';
    RAISE NOTICE '   - Scheduled for Production';
    RAISE NOTICE '   - In Production';
    RAISE NOTICE '   - Ready for Delivery';
    RAISE NOTICE '   - Delivered';
    RAISE NOTICE '   - Cancelled';
    RAISE NOTICE '';
END;
$$;

