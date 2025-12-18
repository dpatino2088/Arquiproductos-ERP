-- ====================================================
-- Migration: Add Uniqueness Constraints for Directory
-- ====================================================
-- Ensures: Name + Email + Customer + Organization is unique
-- This prevents duplicate contacts and ensures traceability
--
-- Business Rules:
-- 1. A Customer must be related to a Contact (via primary_contact_id)
-- 2. A Customer can have multiple Contacts
-- 3. To create an OrganizationUser, you need Contact + Customer
-- 4. Contact email must be related to Customer and OrganizationUser and Organization
-- 5. Name + Email + Customer must be unique for traceability and no data duplication

-- ====================================================
-- Step 1: Optionally link Contacts to Customers (only if they are primary_contact)
-- ====================================================
-- NOTE: customer_id is optional in DirectoryContacts to allow standalone contacts
-- This step only links contacts that are primary_contact of a customer
-- Other contacts can remain without customer_id
--
-- Link contacts that are primary_contact of a customer (if not already linked)
UPDATE "DirectoryContacts" dc
SET customer_id = dcu.id
FROM "DirectoryCustomers" dcu
WHERE dcu.primary_contact_id = dc.id
  AND dc.customer_id IS NULL
  AND dc.deleted = false
  AND dcu.deleted = false
  AND dc.organization_id = dcu.organization_id;

-- ====================================================
-- Step 2: customer_id is OPTIONAL in DirectoryContacts
-- ====================================================
-- NOTE: customer_id is optional to allow standalone contacts
-- Customer is only required when creating an OrganizationUser
-- This prevents the circular dependency: Customer requires PrimaryContact, Contact requires Customer
--
-- Business Rule: A Contact can exist without a Customer, but to create an OrganizationUser,
-- the Contact must have a Customer (validated in OrganizationUserNew component)
--
-- No action needed - customer_id remains nullable

-- ====================================================
-- Step 3: Create unique constraint for Contacts
-- ====================================================
-- Unique constraint: contact_name + email + customer_id + organization_id
-- This ensures no duplicate contacts per customer per organization
-- Note: Using LOWER() for case-insensitive comparison

-- For contacts WITH email: name + email + customer + organization must be unique
CREATE UNIQUE INDEX IF NOT EXISTS idx_directory_contacts_name_email_customer_org_unique
ON "DirectoryContacts" (
  organization_id, 
  customer_id, 
  LOWER(contact_name), 
  LOWER(email)
)
WHERE deleted = false 
  AND email IS NOT NULL 
  AND email != '';

-- For contacts WITHOUT email: name + phone + customer + organization must be unique
CREATE UNIQUE INDEX IF NOT EXISTS idx_directory_contacts_name_phone_customer_org_unique
ON "DirectoryContacts" (
  organization_id, 
  customer_id, 
  LOWER(contact_name), 
  COALESCE(primary_phone, '')
)
WHERE deleted = false 
  AND (email IS NULL OR email = '');

-- ====================================================
-- Step 4: Ensure OrganizationUsers email matches Contact email
-- ====================================================
-- Add function to validate email consistency between OrganizationUsers and DirectoryContacts
CREATE OR REPLACE FUNCTION validate_organization_user_email_consistency()
RETURNS TRIGGER AS $$
BEGIN
  -- If contact_id and email are provided, validate they match
  IF NEW.contact_id IS NOT NULL AND NEW.email IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 
      FROM "DirectoryContacts" dc
      WHERE dc.id = NEW.contact_id
        AND dc.organization_id = NEW.organization_id
        AND LOWER(TRIM(dc.email)) = LOWER(TRIM(NEW.email))
        AND dc.deleted = false
    ) THEN
      RAISE EXCEPTION 'OrganizationUser email (%) must match the Contact email (contact_id: %)', NEW.email, NEW.contact_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to enforce email consistency
DROP TRIGGER IF EXISTS check_organization_user_email_consistency ON "OrganizationUsers";
CREATE TRIGGER check_organization_user_email_consistency
  BEFORE INSERT OR UPDATE ON "OrganizationUsers"
  FOR EACH ROW
  EXECUTE FUNCTION validate_organization_user_email_consistency();

-- ====================================================
-- Step 4.5: Clean up duplicate OrganizationUsers before creating unique index
-- ====================================================
-- First, identify and handle duplicates based on contact_id + customer_id + organization_id
-- We'll keep the most recent record (highest created_at) and mark others as deleted
DO $$
DECLARE
  duplicate_count INTEGER;
BEGIN
  -- Check if contact_id and customer_id columns exist
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'OrganizationUsers' 
      AND column_name = 'contact_id'
  ) OR NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'OrganizationUsers' 
      AND column_name = 'customer_id'
  ) THEN
    RAISE NOTICE 'Skipping duplicate cleanup: contact_id or customer_id columns do not exist.';
    RETURN;
  END IF;
  
  -- Count duplicates
  SELECT COUNT(*) INTO duplicate_count
  FROM (
    SELECT organization_id, customer_id, contact_id, COUNT(*) as cnt
    FROM "OrganizationUsers"
    WHERE deleted = false 
      AND contact_id IS NOT NULL 
      AND customer_id IS NOT NULL
    GROUP BY organization_id, customer_id, contact_id
    HAVING COUNT(*) > 1
  ) duplicates;
  
  IF duplicate_count > 0 THEN
    RAISE NOTICE 'Found % duplicate OrganizationUsers. Cleaning up...', duplicate_count;
    
    -- Mark duplicates as deleted, keeping only the most recent one (highest created_at)
    -- If created_at is the same, keep the one with the highest id (UUID comparison)
    WITH ranked_users AS (
      SELECT 
        id,
        ROW_NUMBER() OVER (
          PARTITION BY organization_id, customer_id, contact_id 
          ORDER BY created_at DESC, id DESC
        ) as rn
      FROM "OrganizationUsers"
      WHERE deleted = false 
        AND contact_id IS NOT NULL 
        AND customer_id IS NOT NULL
    )
    UPDATE "OrganizationUsers" ou
    SET deleted = true,
        updated_at = now()
    FROM ranked_users ru
    WHERE ou.id = ru.id 
      AND ru.rn > 1; -- Keep first (most recent), delete the rest
    
    RAISE NOTICE 'Marked duplicate OrganizationUsers as deleted.';
  ELSE
    RAISE NOTICE 'No duplicate OrganizationUsers found.';
  END IF;
END $$;

-- ====================================================
-- Step 5: Add unique constraint for OrganizationUsers
-- ====================================================
-- Unique constraint: contact_id + customer_id + organization_id
-- This ensures no duplicate organization users per contact per customer per organization
-- IMPORTANT: We use contact_id (from DirectoryContacts) instead of name to avoid duplication
-- The name should come from DirectoryContacts.contact_name, not be duplicated here
DO $$
DECLARE
  remaining_duplicates INTEGER;
BEGIN
  -- Check if contact_id and customer_id columns exist
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'OrganizationUsers' 
      AND column_name = 'contact_id'
  ) OR NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'OrganizationUsers' 
      AND column_name = 'customer_id'
  ) THEN
    RAISE NOTICE 'Skipping OrganizationUsers unique index: contact_id or customer_id columns do not exist. Run add_contact_customer_to_organization_users.sql first.';
    RETURN;
  END IF;
  
  -- Check for remaining duplicates (should be 0 after cleanup)
  SELECT COUNT(*) INTO remaining_duplicates
  FROM (
    SELECT organization_id, customer_id, contact_id, COUNT(*) as cnt
    FROM "OrganizationUsers"
    WHERE deleted = false 
      AND contact_id IS NOT NULL 
      AND customer_id IS NOT NULL
    GROUP BY organization_id, customer_id, contact_id
    HAVING COUNT(*) > 1
  ) duplicates;
  
  IF remaining_duplicates > 0 THEN
    RAISE WARNING 'There are still % duplicate OrganizationUsers. Please review and clean them manually before creating the unique index.', remaining_duplicates;
    RAISE NOTICE 'Run this query to see duplicates:';
    RAISE NOTICE 'SELECT organization_id, customer_id, contact_id, COUNT(*) as cnt, array_agg(id) as ids FROM "OrganizationUsers" WHERE deleted = false AND contact_id IS NOT NULL AND customer_id IS NOT NULL GROUP BY organization_id, customer_id, contact_id HAVING COUNT(*) > 1;';
  ELSE
    -- Create unique index only if no duplicates exist
    CREATE UNIQUE INDEX IF NOT EXISTS idx_organization_users_contact_customer_org_unique
    ON "OrganizationUsers" (
      organization_id, 
      customer_id,
      contact_id
    )
    WHERE deleted = false 
      AND contact_id IS NOT NULL
      AND customer_id IS NOT NULL;
    
    RAISE NOTICE 'Successfully created unique index for OrganizationUsers (contact_id + customer_id + organization_id)';
  END IF;
END $$;

-- ====================================================
-- Step 6: Add comments for documentation
-- ====================================================
COMMENT ON INDEX idx_directory_contacts_name_email_customer_org_unique IS 
'Ensures contact_name + email + customer_id + organization_id is unique (for contacts with email)';

COMMENT ON INDEX idx_directory_contacts_name_phone_customer_org_unique IS 
'Ensures contact_name + phone + customer_id + organization_id is unique (for contacts without email)';

COMMENT ON INDEX idx_organization_users_contact_customer_org_unique IS 
'Ensures contact_id + customer_id + organization_id is unique for OrganizationUsers. The name comes from DirectoryContacts.contact_name, avoiding duplication.';

COMMENT ON FUNCTION validate_organization_user_email_consistency() IS 
'Validates that OrganizationUser email matches the associated Contact email';

-- ====================================================
-- Verification Queries
-- ====================================================
-- Run these queries to verify the migration:

-- 1. Check contacts without customer_id (should be 0 after migration)
-- SELECT COUNT(*) as contacts_without_customer
-- FROM "DirectoryContacts"
-- WHERE customer_id IS NULL AND deleted = false;

-- 2. Check for duplicate contacts (should be 0)
-- SELECT organization_id, customer_id, LOWER(contact_name), LOWER(email), COUNT(*) as duplicates
-- FROM "DirectoryContacts"
-- WHERE deleted = false AND email IS NOT NULL
-- GROUP BY organization_id, customer_id, LOWER(contact_name), LOWER(email)
-- HAVING COUNT(*) > 1;

-- 3. Check for duplicate organization users (should be 0)
-- SELECT organization_id, customer_id, contact_id, COUNT(*) as duplicates, array_agg(id) as ids
-- FROM "OrganizationUsers"
-- WHERE deleted = false AND contact_id IS NOT NULL AND customer_id IS NOT NULL
-- GROUP BY organization_id, customer_id, contact_id
-- HAVING COUNT(*) > 1;

