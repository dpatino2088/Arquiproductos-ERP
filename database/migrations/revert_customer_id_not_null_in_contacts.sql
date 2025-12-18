-- ====================================================
-- Migration: Revert customer_id NOT NULL in DirectoryContacts
-- ====================================================
-- This makes customer_id optional again to allow creating contacts without customers
-- Customer will only be required when creating an OrganizationUser
--
-- Business Rules:
-- 1. A Customer must be related to a Contact (via primary_contact_id) - STILL REQUIRED
-- 2. A Customer can have multiple Contacts
-- 3. A Contact can exist WITHOUT a customer (standalone contact)
-- 4. To create an OrganizationUser, you need Contact + Customer (validated in OrganizationUserNew)
-- 5. Contact email must match OrganizationUser email when creating OrganizationUser

-- ====================================================
-- Step 1: Make customer_id nullable again
-- ====================================================
ALTER TABLE "DirectoryContacts"
  ALTER COLUMN customer_id DROP NOT NULL;

-- ====================================================
-- Step 2: Add comment for documentation
-- ====================================================
COMMENT ON COLUMN "DirectoryContacts".customer_id IS 
'Optional: Links contact to a customer. Required only when creating an OrganizationUser.';

-- ====================================================
-- Verification
-- ====================================================
-- Run this query to verify the change:
-- SELECT 
--   column_name, 
--   is_nullable, 
--   data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'DirectoryContacts' 
--   AND column_name = 'customer_id';
-- 
-- is_nullable should be 'YES'

