-- ====================================================
-- FIX: Contacts-Customer Relationship
-- ====================================================
-- This script checks and fixes the relationship between
-- DirectoryContacts and DirectoryCustomers
-- ====================================================

-- STEP 1: Check customers without contacts
SELECT 
  '1. Customers without contacts' as step,
  dc.id,
  dc.customer_name,
  dc.primary_contact_id,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM "DirectoryContacts" dcon
      WHERE dcon.customer_id = dc.id
      AND dcon.deleted = false
    ) THEN 'Has contacts'
    ELSE '❌ NO CONTACTS'
  END as has_contacts
FROM "DirectoryCustomers" dc
WHERE dc.deleted = false
  AND dc.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
ORDER BY dc.customer_name;

-- STEP 2: Check contacts without customer_id
SELECT 
  '2. Contacts without customer_id' as step,
  id,
  contact_name,
  email,
  customer_id,
  CASE 
    WHEN customer_id IS NULL THEN '⚠️ No customer assigned'
    ELSE 'Has customer'
  END as status
FROM "DirectoryContacts"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
  AND deleted = false
ORDER BY contact_name;

-- STEP 3: Check if primary_contact_id points to valid contacts
SELECT 
  '3. Customers with invalid primary_contact_id' as step,
  dc.id as customer_id,
  dc.customer_name,
  dc.primary_contact_id,
  CASE 
    WHEN dc.primary_contact_id IS NULL THEN '⚠️ No primary contact'
    WHEN dcon.id IS NULL THEN '❌ Primary contact NOT FOUND'
    WHEN dcon.customer_id IS NULL THEN '⚠️ Primary contact has no customer_id'
    WHEN dcon.customer_id != dc.id THEN '⚠️ Primary contact belongs to different customer'
    ELSE '✅ OK'
  END as status,
  dcon.contact_name as primary_contact_name,
  dcon.customer_id as contact_customer_id
FROM "DirectoryCustomers" dc
LEFT JOIN "DirectoryContacts" dcon ON dcon.id = dc.primary_contact_id
WHERE dc.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
  AND dc.deleted = false
ORDER BY dc.customer_name;

-- STEP 4: FIX - Link primary contacts to their customers
DO $$ 
DECLARE
    v_count integer := 0;
BEGIN
    -- Update DirectoryContacts.customer_id based on DirectoryCustomers.primary_contact_id
    UPDATE "DirectoryContacts" dcon
    SET customer_id = dc.id,
        updated_at = NOW()
    FROM "DirectoryCustomers" dc
    WHERE dc.primary_contact_id = dcon.id
      AND dc.deleted = false
      AND dcon.deleted = false
      AND (dcon.customer_id IS NULL OR dcon.customer_id != dc.id);
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE '✅ Linked % primary contacts to their customers', v_count;
END $$;

-- STEP 5: Verification - Check again
SELECT 
  '5. Verification - Customers with contacts' as step,
  dc.id as customer_id,
  dc.customer_name,
  dc.primary_contact_id,
  dcon.id as contact_id,
  dcon.contact_name,
  dcon.customer_id as contact_customer_id,
  CASE 
    WHEN dc.primary_contact_id IS NULL THEN '⚠️ No primary contact set'
    WHEN dcon.id IS NULL THEN '❌ Primary contact NOT FOUND'
    WHEN dcon.customer_id IS NULL THEN '⚠️ Contact has no customer_id'
    WHEN dcon.customer_id = dc.id THEN '✅ Linked correctly'
    ELSE '⚠️ Contact belongs to different customer'
  END as status
FROM "DirectoryCustomers" dc
LEFT JOIN "DirectoryContacts" dcon ON dcon.id = dc.primary_contact_id
WHERE dc.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
  AND dc.deleted = false
ORDER BY dc.customer_name;

-- STEP 6: Count contacts per customer
SELECT 
  '6. Contacts per customer' as step,
  dc.id as customer_id,
  dc.customer_name,
  COUNT(dcon.id) as contact_count,
  STRING_AGG(dcon.contact_name, ', ') as contact_names
FROM "DirectoryCustomers" dc
LEFT JOIN "DirectoryContacts" dcon ON dcon.customer_id = dc.id AND dcon.deleted = false
WHERE dc.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
  AND dc.deleted = false
GROUP BY dc.id, dc.customer_name
ORDER BY dc.customer_name;

