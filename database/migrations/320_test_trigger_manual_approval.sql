-- ====================================================
-- Migration 320: Test Trigger with Manual Approval
-- ====================================================
-- This script tests the trigger by manually updating a quote status
-- Replace <QUOTE_ID> with an actual quote_id that is NOT approved
-- ====================================================

-- Step 1: Find a quote that is NOT approved to test with
SELECT 
    q.id,
    q.quote_no,
    q.status,
    q.deleted,
    so.id as existing_sales_order_id,
    so.sale_order_no as existing_sale_order_no
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.deleted = false
AND (q.status::text ILIKE 'approved' = false OR q.status IS NULL)
ORDER BY q.created_at DESC
LIMIT 5;

-- Step 2: Test the trigger manually (REPLACE <QUOTE_ID> with actual ID from Step 1)
/*
DO $$
DECLARE
    v_test_quote_id uuid := '<QUOTE_ID>'::uuid;  -- ⚠️ REPLACE WITH ACTUAL QUOTE_ID
    v_old_status text;
    v_new_status text := 'Approved';
    v_sales_order_id uuid;
BEGIN
    -- Get current status
    SELECT status::text INTO v_old_status
    FROM "Quotes"
    WHERE id = v_test_quote_id
    AND deleted = false;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Quote % not found or deleted', v_test_quote_id;
    END IF;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE '🧪 Testing trigger with Quote %', v_test_quote_id;
    RAISE NOTICE '  Old status: %', v_old_status;
    RAISE NOTICE '  New status: %', v_new_status;
    RAISE NOTICE '========================================';
    
    -- Check if SalesOrder already exists
    SELECT so.id INTO v_sales_order_id
    FROM "SalesOrders" so
    WHERE so.quote_id = v_test_quote_id
    AND so.deleted = false
    LIMIT 1;
    
    IF v_sales_order_id IS NOT NULL THEN
        RAISE NOTICE '⚠️  SalesOrder already exists: %', v_sales_order_id;
    ELSE
        RAISE NOTICE '✅ No SalesOrder exists (expected)';
    END IF;
    
    -- Update status to trigger
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Updating quote status to Approved...';
    UPDATE "Quotes"
    SET status = v_new_status::quote_status,
        updated_at = now()
    WHERE id = v_test_quote_id;
    
    RAISE NOTICE '✅ Update completed. Trigger should have fired.';
    RAISE NOTICE '';
    
    -- Wait a moment for trigger to complete
    PERFORM pg_sleep(0.5);
    
    -- Check if SalesOrder was created
    SELECT so.id INTO v_sales_order_id
    FROM "SalesOrders" so
    WHERE so.quote_id = v_test_quote_id
    AND so.deleted = false
    LIMIT 1;
    
    IF v_sales_order_id IS NOT NULL THEN
        RAISE NOTICE '✅ SUCCESS! SalesOrder created: %', v_sales_order_id;
        
        -- Get SalesOrder details
        DECLARE
            v_so_record RECORD;
        BEGIN
            SELECT so.* INTO v_so_record
            FROM "SalesOrders" so
            WHERE so.id = v_sales_order_id;
            
            RAISE NOTICE '  SalesOrder No: %', v_so_record.sale_order_no;
            RAISE NOTICE '  Status: %', v_so_record.status;
            RAISE NOTICE '  Created: %', v_so_record.created_at;
        END;
    ELSE
        RAISE WARNING '❌ FAILED! No SalesOrder was created.';
        RAISE WARNING '   Check trigger logs for errors.';
        RAISE WARNING '   Verify trigger is enabled: SELECT tgenabled FROM pg_trigger WHERE tgname = ''trg_on_quote_approved_create_operational_docs'';';
    END IF;
    
    RAISE NOTICE '========================================';
END $$;
*/

-- Step 3: Verify trigger is enabled and ready
SELECT 
    tgname,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        ELSE '⚠️ ' || tgenabled::text
    END as status,
    CASE 
        WHEN tgtype & 2 = 2 THEN '✅ AFTER trigger'
        ELSE '❌ Not AFTER'
    END as trigger_type,
    CASE 
        WHEN tgtype & 4 = 4 THEN '✅ Row-level trigger'
        ELSE '❌ Not row-level'
    END as row_level
FROM pg_trigger 
WHERE tgname = 'trg_on_quote_approved_create_operational_docs';


