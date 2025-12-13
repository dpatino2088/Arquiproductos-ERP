-- ====================================================
-- Migration: Remove company_id from DirectoryContacts
-- ====================================================
-- This migration removes the old company_id column from DirectoryContacts
-- since we now use customer_id instead.
-- 
-- IMPORTANT: Execute this AFTER ensuring all contacts have customer_id
-- and the add_customer_id_to_directory_contacts.sql migration has been run.

-- Step 1: Check current state of columns
DO $$
DECLARE
  customer_id_exists BOOLEAN;
  company_id_exists BOOLEAN;
  contacts_without_customer_id INTEGER := 0;
BEGIN
  -- Check if customer_id column exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' 
    AND column_name = 'customer_id'
  ) INTO customer_id_exists;
  
  -- Check if company_id column exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' 
    AND column_name = 'company_id'
  ) INTO company_id_exists;
  
  RAISE NOTICE 'customer_id column exists: %', customer_id_exists;
  RAISE NOTICE 'company_id column exists: %', company_id_exists;
  
  -- If customer_id doesn't exist, we cannot proceed
  IF NOT customer_id_exists THEN
    RAISE EXCEPTION 'The customer_id column does not exist. Please run add_customer_id_to_directory_contacts.sql migration first.';
  END IF;
  
  -- If company_id doesn't exist, nothing to do
  IF NOT company_id_exists THEN
    RAISE NOTICE 'company_id column does not exist. Nothing to remove.';
    RETURN;
  END IF;
  
  -- Check how many contacts don't have customer_id (only if column exists)
  IF customer_id_exists THEN
    EXECUTE format('SELECT COUNT(*) FROM "DirectoryContacts" WHERE deleted = false AND customer_id IS NULL')
      INTO contacts_without_customer_id;
  END IF;
  
  -- Report findings
  RAISE NOTICE 'Contacts without customer_id: %', contacts_without_customer_id;
  
  -- Warn if there are contacts without customer_id
  IF contacts_without_customer_id > 0 THEN
    RAISE WARNING 'There are % contacts without customer_id. Please assign customer_id to all contacts before removing company_id.', contacts_without_customer_id;
  END IF;
END $$;

-- Step 2: Drop foreign key constraint if it exists
ALTER TABLE "DirectoryContacts" 
  DROP CONSTRAINT IF EXISTS "DirectoryContacts_company_id_fkey";

-- Step 3: Drop index if it exists
DROP INDEX IF EXISTS "idx_directory_contacts_company_id";

-- Step 4: Drop the company_id column (only if it exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' 
    AND column_name = 'company_id'
  ) THEN
    ALTER TABLE "DirectoryContacts" DROP COLUMN company_id;
    RAISE NOTICE 'Successfully removed company_id column from DirectoryContacts.';
  ELSE
    RAISE NOTICE 'company_id column does not exist. Nothing to remove.';
  END IF;
END $$;

-- Step 5: Verify final state
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' 
    AND column_name = 'company_id'
  ) THEN
    RAISE EXCEPTION 'The company_id column still exists. Check for dependencies.';
  ELSE
    RAISE NOTICE 'Verification complete: company_id column has been removed successfully.';
  END IF;
  
  -- Verify customer_id exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'DirectoryContacts' 
    AND column_name = 'customer_id'
  ) THEN
    RAISE WARNING 'customer_id column does not exist. Please ensure add_customer_id_to_directory_contacts.sql was executed.';
  ELSE
    RAISE NOTICE 'Verification complete: customer_id column exists.';
  END IF;
END $$;

-- ====================================================
-- Summary
-- ====================================================
-- After running this migration:
-- - DirectoryContacts no longer has company_id column
-- - All contacts should use customer_id instead
-- - Make sure customer_id is set to NOT NULL if needed:
--   ALTER TABLE "DirectoryContacts" ALTER COLUMN customer_id SET NOT NULL;
