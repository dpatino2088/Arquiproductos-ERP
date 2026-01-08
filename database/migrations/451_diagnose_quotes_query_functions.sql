-- ====================================================
-- Migration 451: Diagnose which function causes SET error in Quotes query
-- ====================================================
-- This script finds all functions that might be called when querying Quotes
-- and checks if they have search_path in proconfig
-- ====================================================

-- Find all functions that might be involved in Quotes queries
-- (triggers, RLS policies, computed columns, etc.)

-- STEP 1: List all STABLE/IMMUTABLE functions with search_path in proconfig
SELECT 
  'Function with search_path in proconfig' as issue_type,
  p.oid::regprocedure::text as function_signature,
  CASE 
    WHEN p.provolatile = 's' THEN 'STABLE'
    WHEN p.provolatile = 'i' THEN 'IMMUTABLE'
    WHEN p.provolatile = 'v' THEN 'VOLATILE'
  END as volatility,
  p.proconfig as config_array,
  array_to_string(p.proconfig, ' | ') as config_string
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.provolatile IN ('s', 'i')  -- STABLE or IMMUTABLE
  AND p.proconfig IS NOT NULL
  AND array_to_string(p.proconfig, '|') LIKE '%search_path%'
ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);

-- STEP 2: Find triggers on Quotes table that might call functions
SELECT 
  'Trigger on Quotes table' as issue_type,
  t.tgname as trigger_name,
  p.proname as function_name,
  p.oid::regprocedure::text as function_signature,
  CASE 
    WHEN p.provolatile = 's' THEN 'STABLE'
    WHEN p.provolatile = 'i' THEN 'IMMUTABLE'
    WHEN p.provolatile = 'v' THEN 'VOLATILE'
  END as function_volatility,
  CASE 
    WHEN p.proconfig IS NOT NULL AND array_to_string(p.proconfig, '|') LIKE '%search_path%' 
    THEN 'YES' 
    ELSE 'NO' 
  END as has_search_path_in_proconfig
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND c.relname = 'Quotes'
  AND NOT t.tgisinternal
ORDER BY t.tgname;

-- STEP 3: Find triggers on QuoteLines table
SELECT 
  'Trigger on QuoteLines table' as issue_type,
  t.tgname as trigger_name,
  p.proname as function_name,
  p.oid::regprocedure::text as function_signature,
  CASE 
    WHEN p.provolatile = 's' THEN 'STABLE'
    WHEN p.provolatile = 'i' THEN 'IMMUTABLE'
    WHEN p.provolatile = 'v' THEN 'VOLATILE'
  END as function_volatility,
  CASE 
    WHEN p.proconfig IS NOT NULL AND array_to_string(p.proconfig, '|') LIKE '%search_path%' 
    THEN 'YES' 
    ELSE 'NO' 
  END as has_search_path_in_proconfig
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND c.relname = 'QuoteLines'
  AND NOT t.tgisinternal
ORDER BY t.tgname;

-- STEP 4: Find triggers on DirectoryCustomers table (used in JOIN)
SELECT 
  'Trigger on DirectoryCustomers table' as issue_type,
  t.tgname as trigger_name,
  p.proname as function_name,
  p.oid::regprocedure::text as function_signature,
  CASE 
    WHEN p.provolatile = 's' THEN 'STABLE'
    WHEN p.provolatile = 'i' THEN 'IMMUTABLE'
    WHEN p.provolatile = 'v' THEN 'VOLATILE'
  END as function_volatility,
  CASE 
    WHEN p.proconfig IS NOT NULL AND array_to_string(p.proconfig, '|') LIKE '%search_path%' 
    THEN 'YES' 
    ELSE 'NO' 
  END as has_search_path_in_proconfig
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND c.relname = 'DirectoryCustomers'
  AND NOT t.tgisinternal
ORDER BY t.tgname;

-- STEP 5: Find RLS policies on Quotes that might use functions
SELECT 
  'RLS Policy on Quotes' as issue_type,
  pol.polname as policy_name,
  pol.polcmd as command_type,
  pg_get_expr(pol.polqual, pol.polrelid) as using_expression,
  pg_get_expr(pol.polwithcheck, pol.polrelid) as with_check_expression
FROM pg_policy pol
JOIN pg_class c ON pol.polrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
  AND c.relname = 'Quotes'
ORDER BY pol.polname;

