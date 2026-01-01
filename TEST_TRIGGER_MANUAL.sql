-- ====================================================
-- Test Trigger Manually - Diagnostic Script
-- ====================================================
-- This script tests the trigger manually to see what's happening
-- ====================================================

-- Enable logging to see RAISE NOTICE messages
SET client_min_messages TO NOTICE;

-- ====================================================
-- STEP 1: Find a Quote to Test
-- ====================================================

-- Find approved quotes without SaleOrders
SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.status,
    q.organization_id,
    q.customer_id,
    q.currency,
    q.totals,
    so.id AS sale_order_id,
    so.sale_order_no
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
AND so.id IS NULL
ORDER BY q.created_at DESC
LIMIT 5;

-- ====================================================
-- STEP 2: Test the Trigger Function Directly
-- ====================================================

-- First, let's test if we can call the function manually
-- (This will help us see if there are any errors)

DO $$
DECLARE
    v_test_quote_id uuid;
    v_test_quote_record RECORD;
BEGIN
    -- Get a test quote
    SELECT id INTO v_test_quote_id
    FROM "Quotes"
    WHERE status = 'approved'
    AND deleted = false
    AND NOT EXISTS (
        SELECT 1 FROM "SaleOrders" 
        WHERE quote_id = "Quotes".id 
        AND deleted = false
    )
    LIMIT 1;
    
    IF v_test_quote_id IS NULL THEN
        RAISE NOTICE '⚠️  No approved quotes without SaleOrders found for testing';
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Testing with Quote ID: %', v_test_quote_id;
    
    -- Get the quote record
    SELECT * INTO v_test_quote_record
    FROM "Quotes"
    WHERE id = v_test_quote_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '❌ Quote not found';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Quote found: % (Status: %)', v_test_quote_record.quote_no, v_test_quote_record.status;
    RAISE NOTICE '   Organization ID: %', v_test_quote_record.organization_id;
    RAISE NOTICE '   Customer ID: %', v_test_quote_record.customer_id;
    
    -- Check if SaleOrder already exists
    IF EXISTS (
        SELECT 1 FROM "SaleOrders"
        WHERE quote_id = v_test_quote_id
        AND deleted = false
    ) THEN
        RAISE NOTICE '⚠️  SaleOrder already exists for this quote';
    ELSE
        RAISE NOTICE '✅ No SaleOrder exists - trigger should create one';
    END IF;
END;
$$;

-- ====================================================
-- STEP 3: Simulate Trigger Execution
-- ====================================================

-- This simulates what the trigger should do
-- Replace <QUOTE_ID> with an actual quote ID from STEP 1

/*
DO $$
DECLARE
    v_quote_id uuid := '3bd5b965-700a-4870-b5e5-94ef64eb7269'; -- QT-000026 from the image
    v_old_status text := 'draft';
    v_new_status text := 'approved';
    v_quote_record RECORD;
    v_sale_order_id uuid;
BEGIN
    RAISE NOTICE '🧪 Simulating trigger execution for Quote %', v_quote_id;
    
    -- Get quote record
    SELECT * INTO v_quote_record
    FROM "Quotes"
    WHERE id = v_quote_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE WARNING '❌ Quote not found';
        RETURN;
    END IF;
    
    RAISE NOTICE '✅ Quote found: %', v_quote_record.quote_no;
    
    -- Check if function exists and can be called
    IF EXISTS (
        SELECT 1 FROM information_schema.routines
        WHERE routine_schema = 'public'
        AND routine_name = 'on_quote_approved_create_operational_docs'
    ) THEN
        RAISE NOTICE '✅ Function exists';
        
        -- Try to call the function logic manually
        -- (We can't call the trigger function directly, but we can test the logic)
        RAISE NOTICE '⚠️  Cannot call trigger function directly, but we can check if it would work';
    ELSE
        RAISE WARNING '❌ Function does not exist!';
    END IF;
END;
$$;
*/

-- ====================================================
-- STEP 4: Check Trigger Status
-- ====================================================

SELECT 
    t.tgname AS trigger_name,
    c.relname AS table_name,
    CASE t.tgenabled
        WHEN 'O' THEN 'Enabled ✅'
        WHEN 'D' THEN 'Disabled ❌'
        WHEN 'R' THEN 'Replica'
        WHEN 'A' THEN 'Always'
        ELSE 'Unknown'
    END AS trigger_status,
    t.tgtype::text AS trigger_type,
    pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'Quotes'
AND t.tgname = 'trg_on_quote_approved_create_operational_docs';

-- ====================================================
-- STEP 5: Test Manual Update (Uncomment to test)
-- ====================================================

/*
-- WARNING: This will actually update the quote status!
-- Only uncomment if you want to test the trigger

-- Test with QT-000026 (from the image)
DO $$
DECLARE
    v_quote_id uuid := '3bd5b965-700a-4870-b5e5-94ef64eb7269';
    v_old_status text;
    v_sale_order_count_before integer;
    v_sale_order_count_after integer;
BEGIN
    -- Get current status
    SELECT status INTO v_old_status
    FROM "Quotes"
    WHERE id = v_quote_id;
    
    RAISE NOTICE '📋 Current status: %', v_old_status;
    
    -- Count SaleOrders before
    SELECT COUNT(*) INTO v_sale_order_count_before
    FROM "SaleOrders"
    WHERE quote_id = v_quote_id
    AND deleted = false;
    
    RAISE NOTICE '📊 SaleOrders before: %', v_sale_order_count_before;
    
    -- Update quote status (this should trigger the function)
    -- First, set it to something else, then back to approved
    UPDATE "Quotes"
    SET status = 'draft', updated_at = now()
    WHERE id = v_quote_id;
    
    RAISE NOTICE '🔄 Changed status to draft';
    
    -- Now change to approved (this should fire the trigger)
    UPDATE "Quotes"
    SET status = 'approved', updated_at = now()
    WHERE id = v_quote_id;
    
    RAISE NOTICE '✅ Changed status to approved - trigger should fire now';
    
    -- Wait a moment for trigger to execute
    PERFORM pg_sleep(1);
    
    -- Count SaleOrders after
    SELECT COUNT(*) INTO v_sale_order_count_after
    FROM "SaleOrders"
    WHERE quote_id = v_quote_id
    AND deleted = false;
    
    RAISE NOTICE '📊 SaleOrders after: %', v_sale_order_count_after;
    
    IF v_sale_order_count_after > v_sale_order_count_before THEN
        RAISE NOTICE '✅ SUCCESS! SaleOrder was created by trigger';
    ELSE
        RAISE WARNING '❌ FAILED! SaleOrder was NOT created by trigger';
    END IF;
    
    -- Restore original status if needed
    -- UPDATE "Quotes" SET status = v_old_status WHERE id = v_quote_id;
END;
$$;
*/

-- ====================================================
-- STEP 6: Check Function Definition
-- ====================================================

-- Show the function definition to verify it's correct
SELECT 
    p.proname AS function_name,
    pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname = 'on_quote_approved_create_operational_docs';

-- ====================================================
-- STEP 7: Check for Errors in Function
-- ====================================================

-- Verify function can be compiled/validated
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = 'on_quote_approved_create_operational_docs'
    ) THEN
        RAISE NOTICE '✅ Function exists and can be queried';
        
        -- Check if function has SECURITY DEFINER
        IF EXISTS (
            SELECT 1 FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public'
            AND p.proname = 'on_quote_approved_create_operational_docs'
            AND p.prosecdef = true
        ) THEN
            RAISE NOTICE '✅ Function has SECURITY DEFINER';
        ELSE
            RAISE WARNING '⚠️  Function does NOT have SECURITY DEFINER!';
        END IF;
    ELSE
        RAISE WARNING '❌ Function does not exist!';
    END IF;
END;
$$;








