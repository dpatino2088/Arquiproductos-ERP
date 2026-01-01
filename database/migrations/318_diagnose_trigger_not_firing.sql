-- ====================================================
-- Migration 318: Diagnose Why Trigger is Not Firing
-- ====================================================

-- Query 1: Check trigger status and definition
SELECT 
    tgname,
    CASE tgenabled
        WHEN 'O' THEN '✅ Enabled'
        WHEN 'D' THEN '❌ Disabled'
        WHEN 'R' THEN '⚠️ Replica'
        WHEN 'A' THEN '⚠️ Always'
        ELSE '⚠️ Unknown (' || tgenabled::text || ')'
    END as trigger_status,
    tgtype::text as trigger_type,
    tgenabled as raw_enabled,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger 
WHERE tgname = 'trg_on_quote_approved_create_operational_docs';

-- Query 2: Check the trigger function
SELECT 
    proname,
    prosrc
FROM pg_proc
WHERE proname = 'on_quote_approved_create_operational_docs';

-- Query 3: Check recent quote status changes (last 10)
SELECT 
    q.id,
    q.quote_no,
    q.status,
    q.updated_at,
    so.id as sales_order_id,
    so.sale_order_no,
    CASE 
        WHEN q.status IS NOT NULL 
        AND (q.status::text ILIKE 'approved' OR q.status::text = 'Approved')
        AND so.id IS NULL THEN '❌ PROBLEM: Approved but no SO'
        WHEN q.status IS NOT NULL 
        AND (q.status::text ILIKE 'approved' OR q.status::text = 'Approved')
        AND so.id IS NOT NULL THEN '✅ OK'
        ELSE 'ℹ️ Not approved'
    END as status_check
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.deleted = false
ORDER BY q.updated_at DESC
LIMIT 10;

-- Query 4: Check if there are any quotes that were recently updated to approved
SELECT 
    q.id,
    q.quote_no,
    q.status,
    q.created_at,
    q.updated_at,
    so.id as sales_order_id,
    so.sale_order_no,
    so.created_at as so_created_at
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status IS NOT NULL
AND (q.status::text ILIKE 'approved' OR q.status::text = 'Approved')
AND q.deleted = false
AND q.updated_at > NOW() - INTERVAL '1 hour'  -- Last hour
ORDER BY q.updated_at DESC;


