-- ====================================================
-- Debug: Why is the trigger not creating SalesOrders?
-- ====================================================
-- Run this to check everything step by step
-- ====================================================

-- 1. Check if the Quote exists and is approved
SELECT 
    id,
    quote_no,
    status,
    organization_id,
    customer_id,
    updated_at,
    deleted
FROM "Quotes"
WHERE deleted = false
ORDER BY updated_at DESC
LIMIT 5;

-- 2. Check if SalesOrder was created for the most recent approved quote
SELECT 
    q.id as quote_id,
    q.quote_no,
    q.status as quote_status,
    q.updated_at as quote_updated_at,
    so.id as sale_order_id,
    so.sale_order_no,
    so.status as so_status,
    so.deleted as so_deleted,
    so.created_at as so_created_at
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id
WHERE q.deleted = false
ORDER BY q.updated_at DESC
LIMIT 5;

-- 3. Check if trigger exists and is enabled
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    CASE tgenabled
        WHEN 'O' THEN 'origin'
        WHEN 'D' THEN 'disabled'
        WHEN 'R' THEN 'replica'
        WHEN 'A' THEN 'always'
        ELSE 'unknown'
    END as trigger_status,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgname = 'trg_on_quote_approved_create_operational_docs'
   OR tgrelid::regclass::text = 'Quotes';

-- 4. Check if function exists
SELECT 
    p.proname as function_name,
    CASE 
        WHEN pg_get_functiondef(p.oid) LIKE '%"SalesOrders"%' THEN '✅ Uses correct table name'
        WHEN pg_get_functiondef(p.oid) LIKE '%"SaleOrders"%' THEN '❌ Uses wrong table name (missing s)'
        ELSE '❓ Cannot determine'
    END as table_name_check
FROM pg_proc p
INNER JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
AND p.proname = 'on_quote_approved_create_operational_docs';

-- 5. Try to manually trigger the function (TEST - replace quote_id with actual ID)
-- SELECT public.on_quote_approved_create_operational_docs()
-- FROM (SELECT id, status FROM "Quotes" WHERE quote_no = 'QT-000001' LIMIT 1) q;

-- 6. Check recent logs for errors (if you have access to pg_stat_statements or logs)
-- This might not work depending on your setup, but worth trying

