-- ====================================================
-- Verify that on_quote_approved_create_operational_docs still works
-- ====================================================
-- This checks if the trigger function exists and is correct after migration 222
-- ====================================================

-- 1. Check if the function exists
SELECT 
    proname as function_name,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc p
INNER JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
AND p.proname = 'on_quote_approved_create_operational_docs';

-- 2. Check if the trigger exists
SELECT 
    tgname as trigger_name,
    tgrelid::regclass as table_name,
    tgenabled as enabled,
    pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgname = 'trg_on_quote_status_changed_create_operational_docs'
OR tgname LIKE '%quote%approved%';

-- 3. Quick check: Does the function call apply_engineering_rules_and_convert_linear_uom?
-- (It should, after migration 222)
SELECT 
    CASE 
        WHEN pg_get_functiondef(p.oid) LIKE '%apply_engineering_rules_and_convert_linear_uom%' 
        THEN '✅ Function calls wrapper (correct after migration 222)'
        WHEN pg_get_functiondef(p.oid) LIKE '%apply_engineering_rules_to_bom_instance%'
        THEN '⚠️ Function still calls old function (migration 222 may have failed)'
        ELSE '❓ Cannot determine which function is called'
    END as function_call_status
FROM pg_proc p
INNER JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
AND p.proname = 'on_quote_approved_create_operational_docs';



