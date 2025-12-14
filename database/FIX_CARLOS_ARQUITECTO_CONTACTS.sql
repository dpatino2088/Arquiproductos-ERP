-- ====================================================
-- FIX: Carlos Arquitecto Customer Contacts
-- ====================================================
-- This fixes the contacts for Carlos Arquitecto customer
-- ====================================================

-- STEP 1: Find Carlos Arquitecto customer
SELECT 
  '1. Carlos Arquitecto customer' as step,
  id as customer_id,
  customer_name,
  primary_contact_id,
  organization_id
FROM "DirectoryCustomers"
WHERE customer_name ILIKE '%Carlos%Arquitecto%'
  AND deleted = false;

-- STEP 2: Check contacts that should belong to Carlos Arquitecto
SELECT 
  '2. Potential contacts for Carlos Arquitecto' as step,
  dcon.id as contact_id,
  dcon.contact_name,
  dcon.email,
  dcon.customer_id,
  CASE 
    WHEN dcon.customer_id IS NULL THEN '⚠️ No customer assigned'
    WHEN dcon.customer_id = (SELECT id FROM "DirectoryCustomers" WHERE customer_name ILIKE '%Carlos%Arquitecto%' AND deleted = false LIMIT 1)
      THEN '✅ Correctly assigned to Carlos Arquitecto'
    ELSE '⚠️ Assigned to different customer'
  END as status
FROM "DirectoryContacts" dcon
WHERE dcon.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
  AND dcon.deleted = false
  AND (
    dcon.contact_name ILIKE '%Carlos%Diaz%'
    OR dcon.id = (SELECT primary_contact_id FROM "DirectoryCustomers" WHERE customer_name ILIKE '%Carlos%Arquitecto%' AND deleted = false LIMIT 1)
  );

-- STEP 3: FIX - Link Carlos Diaz contact to Carlos Arquitecto customer
DO $$ 
DECLARE
    v_customer_id uuid;
    v_contact_id uuid;
    v_count integer := 0;
BEGIN
    -- Get Carlos Arquitecto customer ID
    SELECT id INTO v_customer_id
    FROM "DirectoryCustomers"
    WHERE customer_name ILIKE '%Carlos%Arquitecto%'
      AND deleted = false
      AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    LIMIT 1;
    
    IF v_customer_id IS NULL THEN
        RAISE NOTICE '❌ Carlos Arquitecto customer not found';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Found Carlos Arquitecto customer: %', v_customer_id;
    
    -- Get Carlos Diaz contact ID (or the primary contact)
    SELECT COALESCE(
      (SELECT id FROM "DirectoryContacts" 
       WHERE contact_name ILIKE '%Carlos%Diaz%' 
       AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
       AND deleted = false LIMIT 1),
      (SELECT primary_contact_id FROM "DirectoryCustomers" 
       WHERE id = v_customer_id)
    ) INTO v_contact_id;
    
    IF v_contact_id IS NULL THEN
        RAISE NOTICE '⚠️ No contact found for Carlos Arquitecto';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Found contact: %', v_contact_id;
    
    -- Link the contact to the customer
    UPDATE "DirectoryContacts"
    SET customer_id = v_customer_id,
        updated_at = NOW()
    WHERE id = v_contact_id
      AND (customer_id IS NULL OR customer_id != v_customer_id);
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    IF v_count > 0 THEN
        RAISE NOTICE '✅ Linked contact to Carlos Arquitecto customer';
    ELSE
        RAISE NOTICE 'ℹ️ Contact already linked correctly';
    END IF;
    
    -- Also ensure primary_contact_id is set
    UPDATE "DirectoryCustomers"
    SET primary_contact_id = v_contact_id
    WHERE id = v_customer_id
      AND (primary_contact_id IS NULL OR primary_contact_id != v_contact_id);
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    IF v_count > 0 THEN
        RAISE NOTICE '✅ Updated primary_contact_id for Carlos Arquitecto';
    END IF;
END $$;

-- STEP 4: Verify the fix
SELECT 
  '4. Verification' as step,
  dc.id as customer_id,
  dc.customer_name,
  dc.primary_contact_id,
  dcon.id as contact_id,
  dcon.contact_name,
  dcon.customer_id as contact_customer_id,
  CASE 
    WHEN dcon.customer_id = dc.id THEN '✅ Linked correctly'
    WHEN dcon.customer_id IS NULL THEN '⚠️ Contact has no customer_id'
    ELSE '⚠️ Contact belongs to different customer'
  END as status
FROM "DirectoryCustomers" dc
LEFT JOIN "DirectoryContacts" dcon ON dcon.customer_id = dc.id AND dcon.deleted = false
WHERE dc.customer_name ILIKE '%Carlos%Arquitecto%'
  AND dc.deleted = false;

