-- ====================================================
-- Verification Script: Check Column Names After Migration
-- ====================================================
-- This script verifies that all column names are correct after migration
-- Run this to ensure the migration was applied successfully
-- ====================================================

-- Check Organizations table
SELECT 
  'Organizations' as table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'Organizations'
  AND column_name IN ('id', 'organization_name', 'name', 'deleted', 'archived')
ORDER BY column_name;

-- Check if Organizations has old 'name' column (should not exist after migration)
SELECT 
  '⚠️ Organizations.name found - should be organization_name!' as warning,
  table_name,
  column_name
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'Organizations'
  AND column_name = 'name';

-- Check DirectoryCustomers table
SELECT 
  'DirectoryCustomers' as table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'DirectoryCustomers'
  AND column_name IN ('id', 'customer_name', 'organization_id', 'deleted', 'archived')
ORDER BY column_name;

-- Check DirectoryContacts table
SELECT 
  'DirectoryContacts' as table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'DirectoryContacts'
  AND column_name IN ('id', 'contact_name', 'organization_id', 'customer_id', 'deleted', 'archived')
ORDER BY column_name;

-- Check DirectoryVendors table
SELECT 
  'DirectoryVendors' as table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'DirectoryVendors'
  AND column_name IN ('id', 'vendor_name', 'organization_id', 'deleted', 'archived')
ORDER BY column_name;

-- Check OrganizationUsers table
SELECT 
  'OrganizationUsers' as table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'OrganizationUsers'
  AND column_name IN ('id', 'user_name', 'email', 'organization_id', 'user_id', 'role', 'deleted')
ORDER BY column_name;

-- Check CustomerTypes table (if exists)
SELECT 
  'CustomerTypes' as table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'CustomerTypes'
  AND column_name IN ('id', 'customer_type_name', 'organization_id', 'deleted', 'archived')
ORDER BY column_name;

-- Check VendorTypes table (if exists)
SELECT 
  'VendorTypes' as table_name,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'VendorTypes'
  AND column_name IN ('id', 'vendor_type_name', 'organization_id', 'deleted', 'archived')
ORDER BY column_name;

-- ====================================================
-- Summary: Check for old column names (should return empty)
-- ====================================================
SELECT 
  table_name,
  column_name,
  '⚠️ OLD COLUMN NAME FOUND - Migration may not be complete!' as warning
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND (
    (table_name = 'Organizations' AND column_name = 'name') OR
    (table_name = 'DirectoryCustomers' AND column_name = 'company_name') OR
    (table_name = 'DirectoryContacts' AND column_name = 'customer_name') OR
    (table_name = 'DirectoryVendors' AND column_name = 'name') OR
    (table_name = 'CustomerTypes' AND column_name = 'name') OR
    (table_name = 'VendorTypes' AND column_name = 'name') OR
    (table_name = 'OrganizationUsers' AND column_name = 'name')
  )
ORDER BY table_name, column_name;

-- ====================================================
-- Test Query: Try to query OrganizationUsers with Organizations
-- ====================================================
-- This simulates what OrganizationContext does
-- Replace 'YOUR_USER_ID_HERE' with an actual user_id from auth.users
/*
SELECT 
  ou.id,
  ou.organization_id,
  ou.role,
  ou.user_name,
  ou.email,
  org.id as org_id,
  org.organization_name
FROM "OrganizationUsers" ou
LEFT JOIN "Organizations" org ON org.id = ou.organization_id
WHERE ou.user_id = 'YOUR_USER_ID_HERE'::uuid
  AND ou.deleted = false
LIMIT 5;
*/

