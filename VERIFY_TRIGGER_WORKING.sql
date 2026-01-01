-- ====================================================
-- Verify Trigger is Working Correctly
-- ====================================================
-- This script verifies that:
-- 1. The trigger function uses "SalesOrders" (plural)
-- 2. The trigger exists and is active
-- 3. Shows existing SalesOrders for approved Quotes
-- ====================================================

-- 1. Check if trigger exists
SELECT 
    'Trigger Status' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_trigger 
            WHERE tgname = 'trg_on_quote_approved_create_operational_docs'
            AND tgrelid = '"Quotes"'::regclass
        ) THEN '✅ EXISTS'
        ELSE '❌ NOT FOUND'
    END as status,
    '' as details
UNION ALL
-- 2. Check function uses correct table name
SELECT 
    'Function Table Reference' as check_type,
    CASE 
        WHEN pg_get_functiondef(oid) LIKE '%"SalesOrders"%' THEN '✅ Uses "SalesOrders" (plural)'
        WHEN pg_get_functiondef(oid) LIKE '%"SaleOrders"%' THEN '❌ Uses "SaleOrders" (singular - WRONG!)'
        ELSE '⚠️ Cannot verify'
    END as status,
    '' as details
FROM pg_proc 
WHERE proname = 'on_quote_approved_create_operational_docs'
AND pronamespace = 'public'::regnamespace
UNION ALL
-- 3. Count approved Quotes
SELECT 
    'Approved Quotes' as check_type,
    COUNT(*)::text as status,
    'Total approved quotes' as details
FROM "Quotes"
WHERE status = 'approved' AND deleted = false
UNION ALL
-- 4. Count SalesOrders for approved Quotes
SELECT 
    'SalesOrders for Approved Quotes' as check_type,
    COUNT(DISTINCT so.id)::text as status,
    'SalesOrders linked to approved quotes' as details
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved' AND q.deleted = false
UNION ALL
-- 5. Show approved Quotes without SalesOrders (should trigger create them)
SELECT 
    'Quotes Missing SalesOrders' as check_type,
    COUNT(*)::text as status,
    'Approved quotes without SalesOrders (trigger should create)' as details
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved' 
AND q.deleted = false
AND so.id IS NULL;

-- Show detailed list of approved Quotes and their SalesOrders
SELECT 
    q.quote_no,
    q.status as quote_status,
    so.sale_order_no,
    so.status as sales_order_status,
    so.order_progress_status,
    CASE 
        WHEN so.id IS NULL THEN '❌ Missing SalesOrder'
        ELSE '✅ Has SalesOrder'
    END as status_check
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved' AND q.deleted = false
ORDER BY q.created_at DESC;






