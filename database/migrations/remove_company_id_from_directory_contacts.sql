-- ====================================================
-- Migration: Remove company_id from DirectoryContacts
-- ====================================================
-- This migration removes the old company_id column from DirectoryContacts
-- since we now use customer_id instead.
-- 
-- IMPORTANT: Execute this AFTER ensuring all contacts have customer_id
-- and the add_customer_id_to_directory_contacts.sql migration has been run.

-- Step 1: Verify that customer_id exists and has data
DO $$
DECLARE
  contacts_without_customer_id INTEGER;
  contacts_with_company_id INTEGER;
BEGIN
  -- Check how many contacts don't have customer_id
  SELECT COUNT(*) INTO contacts_without_customer_id
  FROM "DirectoryContacts"
  WHERE deleted = false
    AND customer_id IS NULL;
  
  -- Check how many contacts still have company_id
  SELECT COUNT(*) INTO contacts_with_company_id
  FROM "DirectoryContacts"
  WHERE company_id IS NOT NULL;
  
  -- Report findings
  RAISE NOTICE 'Contacts without customer_id: %', contacts_without_customer_id;
  RAISE NOTICE 'Contacts with company_id: %', contacts_with_company_id;
  
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

-- Step 4: Drop the company_id column
ALTER TABLE "DirectoryContacts" 
  DROP COLUMN IF EXISTS company_id;

-- Step 5: Verify the column was removed
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'DirectoryContacts' 
      AND column_name = 'company_id'
  ) THEN
    RAISE EXCEPTION 'The company_id column still exists. Check for dependencies.';
  ELSE
    RAISE NOTICE 'Successfully removed company_id column from DirectoryContacts.';
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

