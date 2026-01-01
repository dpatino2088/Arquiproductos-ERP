-- ====================================================
-- Diagnostic Script: Quote to Sale Order Creation Issue
-- ====================================================
-- This script helps diagnose why SaleOrders are not being created
-- ====================================================

-- 1. Check if trigger exists
SELECT 
    t.tgname AS trigger_name,
    c.relname AS table_name,
    t.tgtype::text AS trigger_type,
    t.tgenabled AS is_enabled,
    pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE c.relname = 'Quotes'
AND t.tgname = 'trg_on_quote_approved_create_operational_docs';

-- 2. Check if function exists
SELECT 
    routine_name,
    routine_type,
    data_type AS return_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'on_quote_approved_create_operational_docs';

-- 3. Check approved quotes without SaleOrders
SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.status,
    q.organization_id,
    q.customer_id,
    q.created_at AS quote_created_at,
    so.id AS sale_order_id,
    so.sale_order_no,
    so.status AS sale_order_status
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.created_at DESC;

-- 4. Check if number generation functions exist
SELECT 
    proname AS function_name,
    pronargs AS num_args
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
AND proname IN ('get_next_document_number', 'get_next_sequential_number', 'get_next_counter_value')
ORDER BY proname;

-- 5. Check recent quote status changes (if audit log exists)
-- This might not exist, so it's optional
SELECT 
    id,
    quote_no,
    status,
    updated_at,
    created_at
FROM "Quotes"
WHERE status = 'approved'
AND deleted = false
ORDER BY updated_at DESC
LIMIT 10;

-- 6. Check SaleOrders table structure for status column
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'SaleOrders'
AND column_name IN ('status', 'order_progress_status')
ORDER BY column_name;

-- 7. Check CHECK constraint on SaleOrders.status
SELECT
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = (SELECT oid FROM pg_class WHERE relname = 'SaleOrders')
AND conname LIKE '%status%';

