-- ====================================================
-- TEMPORARY: Disable RLS for Testing
-- ====================================================
-- ⚠️ WARNING: This disables RLS temporarily for testing
-- DO NOT use in production
-- This helps identify if RLS is blocking access
-- ====================================================

-- Disable RLS on Organizations
ALTER TABLE "Organizations" DISABLE ROW LEVEL SECURITY;

-- Disable RLS on OrganizationUsers  
ALTER TABLE "OrganizationUsers" DISABLE ROW LEVEL SECURITY;

-- Verify RLS is disabled
SELECT 
  'RLS Status' as info,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename IN ('Organizations', 'OrganizationUsers')
ORDER BY tablename;

-- ====================================================
-- TO RE-ENABLE RLS (run this after testing):
-- ====================================================
/*
ALTER TABLE "Organizations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "OrganizationUsers" ENABLE ROW LEVEL SECURITY;
*/

