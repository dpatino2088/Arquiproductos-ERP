-- ====================================================
-- Migration 316: Verify Trigger is Enabled
-- ====================================================

-- Query 1: Verify trigger status (with proper type casting)
SELECT 
    tgname,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        WHEN 'R' THEN '⚠️ Replica'
        WHEN 'A' THEN '⚠️ Always'
        ELSE '⚠️ Unknown (' || tgenabled::text || ')'
    END as status,
    tgenabled as raw_value
FROM pg_trigger 
WHERE tgname = 'trg_on_quote_approved_create_operational_docs';

-- Query 2: Verify SalesOrder for QT-000004
SELECT 
    q.quote_no,
    q.status as quote_status,
    so.sale_order_no,
    so.status as so_status,
    CASE 
        WHEN so.id IS NULL THEN '❌ Missing SalesOrder'
        ELSE '✅ Has SalesOrder'
    END as status_check
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000004';

-- Query 3: All approved quotes without SalesOrder (should be empty after fix)
SELECT 
    q.id,
    q.quote_no,
    q.status,
    q.organization_id,
    CASE 
        WHEN so.id IS NULL THEN '❌ Missing SalesOrder'
        ELSE '✅ Has SalesOrder'
    END as status_check
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status IS NOT NULL
AND (q.status::text ILIKE 'approved' OR q.status::text = 'Approved')
AND q.deleted = false
AND so.id IS NULL
ORDER BY q.created_at DESC;


