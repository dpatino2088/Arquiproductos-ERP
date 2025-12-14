-- ====================================================
-- COMPLETE DIAGNOSTIC: Check All Column Names
-- ====================================================
-- This script checks ALL tables and their column names
-- to identify any mismatches
-- ====================================================

-- 1. Check Organizations table
SELECT 
  'Organizations' as table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'Organizations'
ORDER BY ordinal_position;

-- 2. Check OrganizationUsers table
SELECT 
  'OrganizationUsers' as table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'OrganizationUsers'
ORDER BY ordinal_position;

-- 3. Check DirectoryCustomers table
SELECT 
  'DirectoryCustomers' as table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'DirectoryCustomers'
  AND column_name IN ('id', 'customer_name', 'company_name', 'organization_id', 'deleted')
ORDER BY column_name;

-- 4. Check DirectoryContacts table
SELECT 
  'DirectoryContacts' as table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'DirectoryContacts'
  AND column_name IN ('id', 'contact_name', 'customer_name', 'company_name', 'organization_id', 'deleted')
ORDER BY column_name;

-- 5. Check DirectoryVendors table
SELECT 
  'DirectoryVendors' as table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'DirectoryVendors'
  AND column_name IN ('id', 'vendor_name', 'name', 'organization_id', 'deleted')
ORDER BY column_name;

-- 6. Check for OLD column names (should return empty if migration was successful)
SELECT 
  '⚠️ OLD COLUMNS FOUND' as warning,
  table_name,
  column_name
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

-- 7. Check for NEW column names (should all exist)
SELECT 
  '✅ NEW COLUMNS CHECK' as status,
  table_name,
  column_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM information_schema.columns c2
      WHERE c2.table_schema = 'public'
      AND c2.table_name = c.table_name
      AND c2.column_name = c.column_name
    ) THEN 'EXISTS'
    ELSE 'MISSING'
  END as exists_status
FROM (
  SELECT 'Organizations' as table_name, 'organization_name' as column_name
  UNION ALL SELECT 'DirectoryCustomers', 'customer_name'
  UNION ALL SELECT 'DirectoryContacts', 'contact_name'
  UNION ALL SELECT 'DirectoryVendors', 'vendor_name'
  UNION ALL SELECT 'CustomerTypes', 'customer_type_name'
  UNION ALL SELECT 'VendorTypes', 'vendor_type_name'
  UNION ALL SELECT 'OrganizationUsers', 'user_name'
) c
ORDER BY table_name, column_name;

-- 8. Test query similar to OrganizationContext
-- This will show if the query structure works
SELECT 
  'Test Query Result' as info,
  ou.id as org_user_id,
  ou.organization_id,
  ou.role,
  ou.user_name,
  org.id as org_id,
  org.organization_name
FROM "OrganizationUsers" ou
LEFT JOIN "Organizations" org ON org.id = ou.organization_id
WHERE ou.deleted = false
LIMIT 5;

