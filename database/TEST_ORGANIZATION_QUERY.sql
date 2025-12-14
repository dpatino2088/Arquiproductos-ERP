-- ====================================================
-- TEST: Simulate OrganizationContext Query
-- ====================================================
-- This tests the exact query that OrganizationContext uses
-- ====================================================

-- Step 1: Get users who have organizations
SELECT 
  'Users with organizations' as info,
  au.id as user_id,
  au.email,
  COUNT(ou.id) as org_count
FROM auth.users au
LEFT JOIN "OrganizationUsers" ou ON ou.user_id = au.id AND ou.deleted = false
GROUP BY au.id, au.email
HAVING COUNT(ou.id) > 0
LIMIT 10;

-- Step 2: Pick one user_id from above and test the query
-- Replace 'USER_ID_HERE' with an actual user_id from Step 1
/*
-- Test the exact OrganizationContext query
SELECT 
  organization_id,
  role,
  organization_id,  -- This should become an object in the nested select
  (SELECT row_to_json(org.*) FROM "Organizations" org WHERE org.id = ou.organization_id) as org_data
FROM "OrganizationUsers" ou
WHERE user_id = 'USER_ID_HERE'::uuid
  AND deleted = false;

-- Alternative: Test with explicit JOIN
SELECT 
  ou.organization_id,
  ou.role,
  org.id as org_id,
  org.organization_name
FROM "OrganizationUsers" ou
LEFT JOIN "Organizations" org ON org.id = ou.organization_id
WHERE ou.user_id = 'USER_ID_HERE'::uuid
  AND ou.deleted = false;
*/

-- Step 3: Check RLS policies on OrganizationUsers
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'OrganizationUsers'
ORDER BY policyname;

-- Step 4: Check RLS policies on Organizations
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'Organizations'
ORDER BY policyname;

-- Step 5: Check if RLS is enabled
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename IN ('Organizations', 'OrganizationUsers')
ORDER BY tablename;

