-- ====================================================
-- Force Trigger Test for QT-000026
-- ====================================================
-- This script tests the trigger manually with the specific quote
-- that should have a SaleOrder but doesn't
-- ====================================================

SET client_min_messages TO NOTICE;

-- ====================================================
-- STEP 1: Check Current State
-- ====================================================

SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.status AS quote_status,
    q.organization_id,
    q.customer_id,
    q.created_at,
    q.updated_at,
    so.id AS sale_order_id,
    so.sale_order_no,
    so.status AS sale_order_status
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000026'
AND q.deleted = false;

-- ====================================================
-- STEP 2: Verify Trigger Exists and is Enabled
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
WHERE c.relname = 'Quotes'
AND t.tgname = 'trg_on_quote_approved_create_operational_docs';

-- ====================================================
-- STEP 3: Test Trigger by Simulating Status Change
-- ====================================================

-- This will force the trigger to fire by changing status away and back
DO $$
DECLARE
    v_quote_id uuid := '3bd5b965-700a-4870-b5e5-94ef64eb7269'; -- QT-000026
    v_old_status text;
    v_sale_order_count_before integer;
    v_sale_order_count_after integer;
    v_sale_order_id uuid;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Testing Trigger for QT-000026';
    RAISE NOTICE '========================================';
    
    -- Get current status
    SELECT status INTO v_old_status
    FROM "Quotes"
    WHERE id = v_quote_id;
    
    RAISE NOTICE '📋 Current Quote Status: %', v_old_status;
    
    -- Count SaleOrders before
    SELECT COUNT(*) INTO v_sale_order_count_before
    FROM "SaleOrders"
    WHERE quote_id = v_quote_id
    AND deleted = false;
    
    RAISE NOTICE '📊 SaleOrders before trigger: %', v_sale_order_count_before;
    
    -- Step 1: Change status to something else (to allow trigger to fire)
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Step 1: Changing status to ''draft''...';
    UPDATE "Quotes"
    SET status = 'draft', updated_at = now()
    WHERE id = v_quote_id;
    
    -- Wait a moment
    PERFORM pg_sleep(0.5);
    
    -- Step 2: Change back to 'approved' (this should fire the trigger)
    RAISE NOTICE '🔄 Step 2: Changing status to ''approved'' (trigger should fire)...';
    UPDATE "Quotes"
    SET status = 'approved', updated_at = now()
    WHERE id = v_quote_id;
    
    -- Wait for trigger to execute
    RAISE NOTICE '⏳ Waiting for trigger to execute...';
    PERFORM pg_sleep(1);
    
    -- Count SaleOrders after
    SELECT COUNT(*) INTO v_sale_order_count_after
    FROM "SaleOrders"
    WHERE quote_id = v_quote_id
    AND deleted = false;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 SaleOrders after trigger: %', v_sale_order_count_after;
    
    IF v_sale_order_count_after > v_sale_order_count_before THEN
        RAISE NOTICE '✅ SUCCESS! SaleOrder was created by trigger';
        
        -- Get the new SaleOrder
        SELECT id, sale_order_no, status INTO v_sale_order_id, v_sale_order_no, v_sale_order_status
        FROM "SaleOrders"
        WHERE quote_id = v_quote_id
        AND deleted = false
        ORDER BY created_at DESC
        LIMIT 1;
        
        RAISE NOTICE '   SaleOrder ID: %', v_sale_order_id;
        RAISE NOTICE '   SaleOrder No: %', v_sale_order_no;
        RAISE NOTICE '   SaleOrder Status: %', v_sale_order_status;
    ELSE
        RAISE WARNING '❌ FAILED! SaleOrder was NOT created by trigger';
        RAISE NOTICE '';
        RAISE NOTICE 'Possible causes:';
        RAISE NOTICE '  1. Trigger is disabled';
        RAISE NOTICE '  2. Function has an error (check PostgreSQL logs)';
        RAISE NOTICE '  3. RLS policies are blocking the INSERT';
        RAISE NOTICE '  4. Function is missing SECURITY DEFINER';
    END IF;
    
    RAISE NOTICE '';
END;
$$;

-- ====================================================
-- STEP 4: Verify Result
-- ====================================================

SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.status AS quote_status,
    so.id AS sale_order_id,
    so.sale_order_no,
    so.status AS sale_order_status,
    so.order_progress_status,
    CASE 
        WHEN so.id IS NULL THEN '❌ No SaleOrder'
        ELSE '✅ SaleOrder exists'
    END AS result
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000026'
AND q.deleted = false;

-- ====================================================
-- STEP 5: Check PostgreSQL Logs (if accessible)
-- ====================================================

-- Note: In Supabase, you may need to check the logs in the dashboard
-- This query shows recent function calls (if logging is enabled)
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'If the trigger still did not work:';
    RAISE NOTICE '  1. Check Supabase Dashboard > Logs for errors';
    RAISE NOTICE '  2. Verify the function on_quote_approved_create_operational_docs exists';
    RAISE NOTICE '  3. Check RLS policies on SaleOrders table';
    RAISE NOTICE '  4. Verify organization_id is set correctly in the Quote';
    RAISE NOTICE '';
END;
$$;








