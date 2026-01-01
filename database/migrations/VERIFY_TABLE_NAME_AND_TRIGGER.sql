-- ====================================================
-- Verify table name and trigger status
-- ====================================================
-- Check if the function is using the correct table name
-- ====================================================

-- 1. Check actual table name in database
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
AND (tablename = 'SalesOrders' OR tablename = 'SaleOrders' OR LOWER(tablename) LIKE '%sale%order%')
ORDER BY tablename;

-- 2. Check what table name the function uses
SELECT 
    proname as function_name,
    CASE 
        WHEN pg_get_functiondef(oid) LIKE '%"SalesOrders"%' THEN 'Uses "SalesOrders" (correct)'
        WHEN pg_get_functiondef(oid) LIKE '%"SaleOrders"%' THEN 'Uses "SaleOrders" (WRONG - missing s)'
        ELSE 'Cannot determine table name'
    END as table_name_check
FROM pg_proc p
INNER JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
AND p.proname = 'on_quote_approved_create_operational_docs';

-- 3. Get a snippet of the function to see INSERT statement
SELECT 
    substring(pg_get_functiondef(oid) FROM 'INSERT INTO.*SalesOrders.*\(' FOR 200) as insert_statement_snippet
FROM pg_proc p
INNER JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
AND p.proname = 'on_quote_approved_create_operational_docs';



