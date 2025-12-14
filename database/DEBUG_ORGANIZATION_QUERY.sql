-- ====================================================
-- DEBUG: Test OrganizationContext Query
-- ====================================================
-- This script tests the exact query that OrganizationContext uses
-- Replace YOUR_USER_ID_HERE with an actual user_id from auth.users
-- ====================================================

-- Step 1: Get a user_id to test with
SELECT 
  'Available users' as info,
  id as user_id,
  email
FROM auth.users
LIMIT 5;

-- Step 2: Test the exact query from OrganizationContext
-- Replace 'YOUR_USER_ID_HERE' with one of the user_ids from above
/*
SELECT 
  ou.organization_id,
  ou.role,
  org.id,
  org.organization_name
FROM "OrganizationUsers" ou
LEFT JOIN "Organizations" org ON org.id = ou.organization_id
WHERE ou.user_id = 'YOUR_USER_ID_HERE'::uuid
  AND ou.deleted = false
LIMIT 10;
*/

-- Step 3: Test with nested select (the way OrganizationContext does it)
-- Replace 'YOUR_USER_ID_HERE' with one of the user_ids from above
/*
SELECT 
  organization_id,
  role,
  organization_id (
    id,
    organization_name
  )
FROM "OrganizationUsers"
WHERE user_id = 'YOUR_USER_ID_HERE'::uuid
  AND deleted = false
LIMIT 10;
*/

-- Step 4: Check if OrganizationUsers has the correct columns
SELECT 
  'OrganizationUsers columns' as info,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'OrganizationUsers'
  AND column_name IN ('id', 'user_id', 'organization_id', 'role', 'deleted', 'user_name')
ORDER BY column_name;

-- Step 5: Check if Organizations has the correct columns
SELECT 
  'Organizations columns' as info,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'Organizations'
  AND column_name IN ('id', 'organization_name', 'name', 'deleted')
ORDER BY column_name;

-- Step 6: Check sample data
SELECT 
  'Sample OrganizationUsers' as info,
  id,
  user_id,
  organization_id,
  role,
  deleted
FROM "OrganizationUsers"
WHERE deleted = false
LIMIT 5;

SELECT 
  'Sample Organizations' as info,
  id,
  organization_name,
  name,  -- Check if old column still exists
  deleted
FROM "Organizations"
WHERE deleted = false
LIMIT 5;

