-- ====================================================
-- CHECK RLS Status on Directory Tables
-- ====================================================
-- This checks if RLS is enabled on Directory tables
-- and what policies exist
-- ====================================================

-- Check RLS status
SELECT 
  'RLS Status' as info,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('DirectoryCustomers', 'DirectoryContacts', 'DirectoryVendors')
ORDER BY tablename;

-- Check DirectoryCustomers policies
SELECT 
  'DirectoryCustomers policies' as table_name,
  policyname,
  cmd as command,
  qual as using_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'DirectoryCustomers'
ORDER BY policyname;

-- Check DirectoryContacts policies
SELECT 
  'DirectoryContacts policies' as table_name,
  policyname,
  cmd as command,
  qual as using_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'DirectoryContacts'
ORDER BY policyname;

-- Check DirectoryVendors policies
SELECT 
  'DirectoryVendors policies' as table_name,
  policyname,
  cmd as command,
  qual as using_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'DirectoryVendors'
ORDER BY policyname;

-- Test query: Can we access DirectoryCustomers?
-- This simulates what useCustomers does
SELECT 
  'Test DirectoryCustomers access' as test,
  COUNT(*) as customer_count
FROM "DirectoryCustomers"
WHERE deleted = false;

