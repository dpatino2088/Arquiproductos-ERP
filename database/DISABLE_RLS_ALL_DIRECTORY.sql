-- ====================================================
-- TEMPORARY: Disable RLS on ALL Directory Tables
-- ====================================================
-- ⚠️ WARNING: This is TEMPORARY for testing
-- This helps identify if RLS is blocking access to Directory tables
-- ====================================================

-- Disable RLS on Directory tables
ALTER TABLE "DirectoryCustomers" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "DirectoryContacts" DISABLE ROW LEVEL SECURITY;
ALTER TABLE "DirectoryVendors" DISABLE ROW LEVEL SECURITY;

-- Verify RLS is disabled
SELECT 
  'RLS Status' as info,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('DirectoryCustomers', 'DirectoryContacts', 'DirectoryVendors')
ORDER BY tablename;

-- ====================================================
-- TO RE-ENABLE RLS later:
-- ====================================================
/*
ALTER TABLE "DirectoryCustomers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "DirectoryContacts" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "DirectoryVendors" ENABLE ROW LEVEL SECURITY;
*/

