-- ====================================================
-- FIX: Usuario dpatino@grupo927.com
-- ====================================================
-- Este script diagnostica y corrige el acceso a organizaciones
-- para el usuario dpatino@grupo927.com
-- ====================================================

-- STEP 1: Verificar si el usuario existe en auth.users
SELECT 
  '1. User in auth.users' as step,
  id as user_id,
  email,
  created_at
FROM auth.users
WHERE email = 'dpatino@grupo927.com';

-- STEP 2: Verificar si tiene registros en OrganizationUsers
SELECT 
  '2. User in OrganizationUsers' as step,
  ou.id,
  ou.user_id,
  ou.organization_id,
  ou.role,
  ou.user_name,
  ou.email,
  ou.deleted,
  ou.is_system,
  au.email as auth_email
FROM "OrganizationUsers" ou
LEFT JOIN auth.users au ON au.id = ou.user_id
WHERE au.email = 'dpatino@grupo927.com';

-- STEP 3: Verificar la organización asociada
SELECT 
  '3. Associated Organization' as step,
  org.id,
  org.organization_name,
  org.deleted,
  org.archived
FROM "OrganizationUsers" ou
LEFT JOIN auth.users au ON au.id = ou.user_id
LEFT JOIN "Organizations" org ON org.id = ou.organization_id
WHERE au.email = 'dpatino@grupo927.com';

-- STEP 4: Diagnóstico de problemas
SELECT 
  '4. Diagnosis' as step,
  CASE 
    WHEN NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'dpatino@grupo927.com') 
      THEN '❌ User NOT found in auth.users'
    WHEN NOT EXISTS (
      SELECT 1 FROM "OrganizationUsers" ou
      JOIN auth.users au ON au.id = ou.user_id
      WHERE au.email = 'dpatino@grupo927.com'
    ) THEN '❌ User NOT found in OrganizationUsers'
    WHEN EXISTS (
      SELECT 1 FROM "OrganizationUsers" ou
      JOIN auth.users au ON au.id = ou.user_id
      WHERE au.email = 'dpatino@grupo927.com'
      AND ou.deleted = true
    ) THEN '⚠️ OrganizationUser record is DELETED'
    WHEN EXISTS (
      SELECT 1 FROM "OrganizationUsers" ou
      JOIN auth.users au ON au.id = ou.user_id
      LEFT JOIN "Organizations" org ON org.id = ou.organization_id
      WHERE au.email = 'dpatino@grupo927.com'
      AND (org.id IS NULL OR org.deleted = true OR org.archived = true)
    ) THEN '⚠️ Associated Organization is deleted/archived or does not exist'
    ELSE '✅ User and Organization look OK - may be code issue'
  END as diagnosis;

-- STEP 5: FIX - Ensure user has access to Arquiproductos organization
-- This will add/update the user in OrganizationUsers if needed
DO $$ 
DECLARE
    v_user_id uuid;
    v_org_id uuid;
    v_existing_record_id uuid;
    v_contact_id uuid;
    v_customer_id uuid;
BEGIN
    -- Get user_id
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE email = 'dpatino@grupo927.com';
    
    IF v_user_id IS NULL THEN
        RAISE NOTICE '❌ User dpatino@grupo927.com not found in auth.users';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Found user_id: %', v_user_id;
    
    -- Get Arquiproductos organization_id
    SELECT id INTO v_org_id
    FROM "Organizations"
    WHERE organization_name = 'Arquiproductos'
      AND deleted = false
      AND archived = false
    LIMIT 1;
    
    IF v_org_id IS NULL THEN
        RAISE NOTICE '❌ Organization Arquiproductos not found';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Found organization_id: %', v_org_id;
    
    -- Try to find a contact for this user in DirectoryContacts
    -- Look for a contact with matching email
    SELECT id, customer_id INTO v_contact_id, v_customer_id
    FROM "DirectoryContacts"
    WHERE organization_id = v_org_id
      AND email = 'dpatino@grupo927.com'
      AND deleted = false
    LIMIT 1;
    
    IF v_contact_id IS NULL THEN
        -- If no matching email, try to get any contact from the organization
        SELECT id, customer_id INTO v_contact_id, v_customer_id
        FROM "DirectoryContacts"
        WHERE organization_id = v_org_id
          AND deleted = false
        ORDER BY created_at ASC
        LIMIT 1;
    END IF;
    
    IF v_contact_id IS NOT NULL THEN
        RAISE NOTICE 'Found contact_id: %, customer_id: %', v_contact_id, v_customer_id;
    ELSE
        RAISE NOTICE '⚠️ No contact found - contact_id and customer_id will be NULL (may cause constraint error if NOT NULL)';
    END IF;
    
    -- Check if OrganizationUser record exists
    SELECT id INTO v_existing_record_id
    FROM "OrganizationUsers"
    WHERE user_id = v_user_id
      AND organization_id = v_org_id;
    
    IF v_existing_record_id IS NOT NULL THEN
        -- Record exists - ensure it's not deleted and update contact/customer if available
        UPDATE "OrganizationUsers"
        SET 
          deleted = false,
          role = COALESCE(role, 'member'),
          user_name = COALESCE(user_name, 'Dio Patiño'),
          email = COALESCE(email, 'dpatino@grupo927.com'),
          contact_id = COALESCE(contact_id, v_contact_id),
          customer_id = COALESCE(customer_id, v_customer_id),
          updated_at = NOW()
        WHERE id = v_existing_record_id;
        
        RAISE NOTICE '✅ Updated existing OrganizationUser record (id: %)', v_existing_record_id;
    ELSE
        -- Record doesn't exist - create it
        -- Only insert if we have contact_id (if it's required)
        IF v_contact_id IS NOT NULL THEN
            INSERT INTO "OrganizationUsers" (
              organization_id,
              user_id,
              role,
              user_name,
              email,
              contact_id,
              customer_id,
              deleted,
              is_system
            ) VALUES (
              v_org_id,
              v_user_id,
              'member',
              'Dio Patiño',
              'dpatino@grupo927.com',
              v_contact_id,
              v_customer_id,
              false,
              false
            );
            
            RAISE NOTICE '✅ Created new OrganizationUser record with contact_id';
        ELSE
            RAISE EXCEPTION '❌ Cannot create OrganizationUser: contact_id is required but no contacts found. Please create a contact first in DirectoryContacts for this organization.';
        END IF;
    END IF;
END $$;

-- STEP 6: Verify fix
SELECT 
  '6. Verification after fix' as step,
  ou.id,
  ou.organization_id,
  ou.role,
  ou.user_name,
  ou.deleted,
  org.organization_name,
  au.email
FROM "OrganizationUsers" ou
JOIN auth.users au ON au.id = ou.user_id
LEFT JOIN "Organizations" org ON org.id = ou.organization_id
WHERE au.email = 'dpatino@grupo927.com';

