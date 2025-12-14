-- ====================================================
-- CHECK RLS POLICIES
-- ====================================================
-- This script checks RLS policies for Organizations and OrganizationUsers
-- ====================================================

-- Check OrganizationUsers policies
SELECT 
  'OrganizationUsers policies' as info,
  policyname,
  permissive,
  roles,
  cmd as command,
  qual as using_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'OrganizationUsers'
ORDER BY policyname;

-- Check Organizations policies  
SELECT 
  'Organizations policies' as info,
  policyname,
  permissive,
  roles,
  cmd as command,
  qual as using_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'Organizations'
ORDER BY policyname;

-- Check if user can access their OrganizationUsers records
-- Replace 'YOUR_USER_ID' with actual user_id
/*
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub": "YOUR_USER_ID"}';

SELECT 
  'Can access OrganizationUsers?' as test,
  COUNT(*) as record_count
FROM "OrganizationUsers"
WHERE user_id = 'YOUR_USER_ID'::uuid
  AND deleted = false;

RESET ROLE;
*/

