-- ====================================================
-- Check if Quote approval is creating SalesOrders
-- ====================================================
-- Run this after approving a quote to see what happened
-- ====================================================

-- 1. Check recent Quotes and their status
SELECT 
    quote_no,
    status,
    organization_id,
    customer_id,
    created_at,
    updated_at
FROM "Quotes"
WHERE deleted = false
ORDER BY updated_at DESC
LIMIT 10;

-- 2. Check if SalesOrders were created for these Quotes
SELECT 
    q.quote_no,
    q.status as quote_status,
    so.id as sale_order_id,
    so.sale_order_no,
    so.status as so_status,
    so.deleted as so_deleted,
    so.created_at as so_created_at
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id
WHERE q.deleted = false
ORDER BY q.updated_at DESC
LIMIT 10;

-- 3. Check if the trigger exists and is enabled
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    tgenabled as enabled,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgname LIKE '%quote%approved%'
   OR tgname LIKE '%quote%status%'
ORDER BY tgname;

-- 4. Check if the function exists
SELECT 
    proname as function_name,
    prorettype::regtype as return_type
FROM pg_proc p
INNER JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
AND p.proname = 'on_quote_approved_create_operational_docs';



