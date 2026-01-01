-- ====================================================
-- Fix All Triggers - Complete Diagnostic and Fix
-- ====================================================
-- This script:
-- 1. Verifies trigger functions exist and are correct
-- 2. Verifies triggers exist and are enabled
-- 3. Recreates triggers if needed
-- 4. Tests the triggers
-- ====================================================

-- ====================================================
-- STEP 1: Verify Quote -> SaleOrder Trigger
-- ====================================================

DO $$
DECLARE
    v_func_exists boolean;
    v_trigger_exists boolean;
    v_trigger_enabled text;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'STEP 1: Quote -> SaleOrder Trigger';
    RAISE NOTICE '========================================';
    
    -- Check function
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_quote_approved_create_operational_docs'
    ) INTO v_func_exists;
    
    IF v_func_exists THEN
        RAISE NOTICE '✅ Function on_quote_approved_create_operational_docs exists';
    ELSE
        RAISE WARNING '❌ Function on_quote_approved_create_operational_docs does NOT exist!';
        RAISE NOTICE '⚠️  Please run migration 197: database/migrations/197_ensure_quote_approved_trigger_works.sql';
    END IF;
    
    -- Check trigger
    SELECT 
        EXISTS (
            SELECT 1 FROM pg_trigger t
            JOIN pg_class c ON t.tgrelid = c.oid
            WHERE c.relname = 'Quotes'
            AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
        ),
        CASE t.tgenabled
            WHEN 'O' THEN 'Enabled'
            WHEN 'D' THEN 'Disabled'
            ELSE 'Unknown'
        END
    INTO v_trigger_exists, v_trigger_enabled
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE c.relname = 'Quotes'
    AND t.tgname = 'trg_on_quote_approved_create_operational_docs'
    LIMIT 1;
    
    IF v_trigger_exists THEN
        RAISE NOTICE '✅ Trigger trg_on_quote_approved_create_operational_docs exists and is %', v_trigger_enabled;
        IF v_trigger_enabled = 'Disabled' THEN
            RAISE WARNING '⚠️  Trigger is DISABLED! Enabling...';
            ALTER TABLE "Quotes" ENABLE TRIGGER trg_on_quote_approved_create_operational_docs;
            RAISE NOTICE '✅ Trigger enabled';
        END IF;
    ELSE
        RAISE WARNING '❌ Trigger trg_on_quote_approved_create_operational_docs does NOT exist!';
        RAISE NOTICE '🔧 Creating trigger...';
    END IF;
END;
$$;

-- Recreate trigger if function exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_quote_approved_create_operational_docs'
    ) THEN
        DROP TRIGGER IF EXISTS trg_on_quote_approved_create_operational_docs ON "Quotes";
        
        CREATE TRIGGER trg_on_quote_approved_create_operational_docs
            AFTER UPDATE OF status ON "Quotes"
            FOR EACH ROW
            WHEN (NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved')
            EXECUTE FUNCTION public.on_quote_approved_create_operational_docs();
        
        RAISE NOTICE '✅ Trigger trg_on_quote_approved_create_operational_docs created/recreated';
    END IF;
END;
$$;

-- ====================================================
-- STEP 2: Verify SaleOrder -> ManufacturingOrder Trigger
-- ====================================================

DO $$
DECLARE
    v_func_exists boolean;
    v_trigger_exists boolean;
    v_trigger_enabled text;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'STEP 2: SaleOrder -> ManufacturingOrder Trigger';
    RAISE NOTICE '========================================';
    
    -- Check function
    SELECT EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_sale_order_confirmed_create_manufacturing_order'
    ) INTO v_func_exists;
    
    IF v_func_exists THEN
        RAISE NOTICE '✅ Function on_sale_order_confirmed_create_manufacturing_order exists';
    ELSE
        RAISE WARNING '❌ Function on_sale_order_confirmed_create_manufacturing_order does NOT exist!';
        RAISE NOTICE '⚠️  Please run migration 194: database/migrations/194_complete_quote_to_manufacturing_flow.sql';
    END IF;
    
    -- Check trigger
    SELECT 
        EXISTS (
            SELECT 1 FROM pg_trigger t
            JOIN pg_class c ON t.tgrelid = c.oid
            WHERE c.relname = 'SaleOrders'
            AND t.tgname = 'trg_sale_order_confirmed_create_mo'
        ),
        CASE t.tgenabled
            WHEN 'O' THEN 'Enabled'
            WHEN 'D' THEN 'Disabled'
            ELSE 'Unknown'
        END
    INTO v_trigger_exists, v_trigger_enabled
    FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    WHERE c.relname = 'SaleOrders'
    AND t.tgname = 'trg_sale_order_confirmed_create_mo'
    LIMIT 1;
    
    IF v_trigger_exists THEN
        RAISE NOTICE '✅ Trigger trg_sale_order_confirmed_create_mo exists and is %', v_trigger_enabled;
        IF v_trigger_enabled = 'Disabled' THEN
            RAISE WARNING '⚠️  Trigger is DISABLED! Enabling...';
            ALTER TABLE "SaleOrders" ENABLE TRIGGER trg_sale_order_confirmed_create_mo;
            RAISE NOTICE '✅ Trigger enabled';
        END IF;
    ELSE
        RAISE WARNING '❌ Trigger trg_sale_order_confirmed_create_mo does NOT exist!';
        RAISE NOTICE '🔧 Creating trigger...';
    END IF;
END;
$$;

-- Recreate trigger if function exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_sale_order_confirmed_create_manufacturing_order'
    ) THEN
        DROP TRIGGER IF EXISTS trg_sale_order_confirmed_create_mo ON "SaleOrders";
        
        CREATE TRIGGER trg_sale_order_confirmed_create_mo
            AFTER UPDATE OF status ON "SaleOrders"
            FOR EACH ROW
            WHEN (NEW.status = 'Confirmed' AND OLD.status IS DISTINCT FROM 'Confirmed')
            EXECUTE FUNCTION public.on_sale_order_confirmed_create_manufacturing_order();
        
        RAISE NOTICE '✅ Trigger trg_sale_order_confirmed_create_mo created/recreated';
    END IF;
END;
$$;

-- ====================================================
-- STEP 3: Verify Functions have SECURITY DEFINER
-- ====================================================

DO $$
DECLARE
    v_func_security text;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'STEP 3: Verify Function Security';
    RAISE NOTICE '========================================';
    
    -- Check on_quote_approved_create_operational_docs
    SELECT prosecdef::text INTO v_func_security
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
    AND p.proname = 'on_quote_approved_create_operational_docs'
    LIMIT 1;
    
    IF v_func_security = 't' THEN
        RAISE NOTICE '✅ Function on_quote_approved_create_operational_docs has SECURITY DEFINER';
    ELSE
        RAISE WARNING '⚠️  Function does NOT have SECURITY DEFINER! Updating...';
        ALTER FUNCTION public.on_quote_approved_create_operational_docs() SECURITY DEFINER;
        RAISE NOTICE '✅ Function updated to SECURITY DEFINER';
    END IF;
    
    -- Check on_sale_order_confirmed_create_manufacturing_order
    SELECT prosecdef::text INTO v_func_security
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
    AND p.proname = 'on_sale_order_confirmed_create_manufacturing_order'
    LIMIT 1;
    
    IF v_func_security = 't' THEN
        RAISE NOTICE '✅ Function on_sale_order_confirmed_create_manufacturing_order has SECURITY DEFINER';
    ELSE
        RAISE WARNING '⚠️  Function does NOT have SECURITY DEFINER! Updating...';
        ALTER FUNCTION public.on_sale_order_confirmed_create_manufacturing_order() SECURITY DEFINER;
        RAISE NOTICE '✅ Function updated to SECURITY DEFINER';
    END IF;
END;
$$;

-- ====================================================
-- STEP 4: Show All Trigger Details
-- ====================================================

SELECT 
    t.tgname AS trigger_name,
    c.relname AS table_name,
    CASE t.tgenabled
        WHEN 'O' THEN 'Enabled ✅'
        WHEN 'D' THEN 'Disabled ❌'
        ELSE 'Unknown'
    END AS trigger_status,
    pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname IN ('Quotes', 'SaleOrders')
AND t.tgname IN ('trg_on_quote_approved_create_operational_docs', 'trg_sale_order_confirmed_create_mo')
ORDER BY c.relname, t.tgname;

-- ====================================================
-- STEP 5: Test Query - Find Quotes Ready for Testing
-- ====================================================

-- Find approved quotes without SaleOrders (for testing trigger 1)
SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.status AS quote_status,
    q.organization_id,
    so.id AS sale_order_id,
    so.sale_order_no,
    CASE 
        WHEN so.id IS NULL THEN '❌ No SaleOrder (trigger should create one)'
        ELSE '✅ SaleOrder exists'
    END AS trigger_status
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.created_at DESC
LIMIT 10;

-- Find confirmed SaleOrders without ManufacturingOrders (for testing trigger 2)
SELECT 
    so.id AS sale_order_id,
    so.sale_order_no,
    so.status AS sale_order_status,
    so.organization_id,
    mo.id AS manufacturing_order_id,
    mo.manufacturing_order_no,
    CASE 
        WHEN mo.id IS NULL THEN '❌ No ManufacturingOrder (trigger should create one)'
        ELSE '✅ ManufacturingOrder exists'
    END AS trigger_status
FROM "SaleOrders" so
LEFT JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id AND mo.deleted = false
WHERE so.status = 'Confirmed'
AND so.deleted = false
ORDER BY so.created_at DESC
LIMIT 10;

-- ====================================================
-- STEP 6: Enable Logging for Trigger Debugging
-- ====================================================

-- Enable client_min_messages to see RAISE NOTICE messages
SET client_min_messages TO NOTICE;

-- ====================================================
-- STEP 7: Manual Test Query (Uncomment to test)
-- ====================================================

/*
-- TEST TRIGGER 1: Quote -> SaleOrder
-- Step 1: Find a quote that is NOT approved
SELECT 
    id,
    quote_no,
    status,
    organization_id
FROM "Quotes"
WHERE status != 'approved'
AND deleted = false
ORDER BY created_at DESC
LIMIT 1;

-- Step 2: Update the quote to approved (replace <QUOTE_ID> with actual ID)
-- UPDATE "Quotes" 
-- SET status = 'approved', updated_at = now()
-- WHERE id = '<QUOTE_ID>';

-- Step 3: Check if SaleOrder was created
-- SELECT 
--     so.id,
--     so.sale_order_no,
--     so.status,
--     so.order_progress_status,
--     so.quote_id
-- FROM "SaleOrders" so
-- WHERE so.quote_id = '<QUOTE_ID>'
-- AND so.deleted = false;

-- TEST TRIGGER 2: SaleOrder -> ManufacturingOrder
-- Step 1: Find a SaleOrder that is NOT Confirmed
-- SELECT 
--     id,
--     sale_order_no,
--     status,
--     organization_id
-- FROM "SaleOrders"
-- WHERE status != 'Confirmed'
-- AND deleted = false
-- ORDER BY created_at DESC
-- LIMIT 1;

-- Step 2: Update the SaleOrder to Confirmed (replace <SO_ID> with actual ID)
-- UPDATE "SaleOrders" 
-- SET status = 'Confirmed', updated_at = now()
-- WHERE id = '<SO_ID>';

-- Step 3: Check if ManufacturingOrder was created
-- SELECT 
--     mo.id,
--     mo.manufacturing_order_no,
--     mo.status,
--     mo.sale_order_id
-- FROM "ManufacturingOrders" mo
-- WHERE mo.sale_order_id = '<SO_ID>'
-- AND mo.deleted = false;
*/

-- ====================================================
-- STEP 8: Summary and Instructions
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Trigger Verification Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Triggers Status:';
    RAISE NOTICE '  ✅ Quote -> SaleOrder: Check results above';
    RAISE NOTICE '  ✅ SaleOrder -> ManufacturingOrder: Check results above';
    RAISE NOTICE '';
    RAISE NOTICE 'To test Trigger 1 (Quote -> SaleOrder):';
    RAISE NOTICE '  1. Find a Quote with status != ''approved''';
    RAISE NOTICE '  2. UPDATE "Quotes" SET status = ''approved'' WHERE id = ''<quote_id>'';';
    RAISE NOTICE '  3. Check if SaleOrder was created: SELECT * FROM "SaleOrders" WHERE quote_id = ''<quote_id>'';';
    RAISE NOTICE '';
    RAISE NOTICE 'To test Trigger 2 (SaleOrder -> ManufacturingOrder):';
    RAISE NOTICE '  1. Find a SaleOrder with status != ''Confirmed''';
    RAISE NOTICE '  2. UPDATE "SaleOrders" SET status = ''Confirmed'' WHERE id = ''<so_id>'';';
    RAISE NOTICE '  3. Check if ManufacturingOrder was created: SELECT * FROM "ManufacturingOrders" WHERE sale_order_id = ''<so_id>'';';
    RAISE NOTICE '';
    RAISE NOTICE 'If triggers still don''t work:';
    RAISE NOTICE '  - Check the PostgreSQL logs for RAISE NOTICE/WARNING messages';
    RAISE NOTICE '  - Verify RLS policies allow the trigger functions to work';
    RAISE NOTICE '  - Check if functions have proper error handling';
    RAISE NOTICE '  - Ensure organization_id is set correctly in Quotes/SaleOrders';
    RAISE NOTICE '';
END;
$$;

