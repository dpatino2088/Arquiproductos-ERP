-- ====================================================
-- CHECK USER DATA
-- ====================================================
-- This script checks if there's a user logged in and their organizations
-- ====================================================

-- Step 1: Check auth.users
SELECT 
  'auth.users' as table_name,
  id as user_id,
  email,
  created_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 10;

-- Step 2: Check OrganizationUsers for all users
SELECT 
  'OrganizationUsers' as table_name,
  ou.id,
  ou.user_id,
  ou.organization_id,
  ou.role,
  ou.user_name,
  ou.email,
  ou.deleted,
  au.email as auth_email
FROM "OrganizationUsers" ou
LEFT JOIN auth.users au ON au.id = ou.user_id
ORDER BY ou.created_at DESC
LIMIT 20;

-- Step 3: Check Organizations
SELECT 
  'Organizations' as table_name,
  id,
  organization_name,
  deleted,
  archived,
  created_at
FROM "Organizations"
WHERE deleted = false
ORDER BY created_at DESC;

-- Step 4: Check if there are OrganizationUsers without matching Organizations
SELECT 
  'Orphaned OrganizationUsers' as warning,
  ou.id,
  ou.user_id,
  ou.organization_id,
  ou.role,
  CASE 
    WHEN org.id IS NULL THEN '❌ Organization NOT FOUND'
    ELSE '✅ Organization EXISTS'
  END as status
FROM "OrganizationUsers" ou
LEFT JOIN "Organizations" org ON org.id = ou.organization_id
WHERE ou.deleted = false;

-- Step 5: Test the exact query that OrganizationContext uses
-- For a specific user (replace USER_ID)
/*
SELECT 
  ou.organization_id,
  ou.role,
  org.id as org_id,
  org.organization_name,
  org.deleted as org_deleted
FROM "OrganizationUsers" ou
LEFT JOIN "Organizations" org ON org.id = ou.organization_id
WHERE ou.user_id = 'USER_ID_HERE'::uuid
  AND ou.deleted = false;
*/

