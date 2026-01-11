-- ============================================================
-- Migration: Remove email column from CompanyPortalUsers
-- ============================================================
-- OBJECTIVE:
-- Remove legacy 'email' column from CompanyPortalUsers table
-- The table now uses 'portal_user_email' exclusively
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Migrate any remaining data from email to portal_user_email
-- ============================================================

DO $$
BEGIN
  -- If email column exists and portal_user_email is NULL, copy data
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'CompanyPortalUsers' 
    AND column_name = 'email'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'CompanyPortalUsers' 
    AND column_name = 'portal_user_email'
  ) THEN
    -- Migrate data from email to portal_user_email where portal_user_email is NULL
    UPDATE public."CompanyPortalUsers"
    SET portal_user_email = email
    WHERE portal_user_email IS NULL 
      AND email IS NOT NULL;
    
    RAISE NOTICE 'Migrated data from email to portal_user_email';
  END IF;
END $$;

-- ============================================================
-- 2) Drop RLS policies that might depend on email column
-- ============================================================

-- Drop any policies that reference email (if they exist)
DROP POLICY IF EXISTS companyportalusers_email_check ON public."CompanyPortalUsers";

-- ============================================================
-- 3) Drop indexes on email column if they exist
-- ============================================================

DROP INDEX IF EXISTS idx_companyportalusers_email;
DROP INDEX IF EXISTS idx_companyportalusers_email_unique;

-- ============================================================
-- 4) Drop foreign key constraints on email if they exist
-- ============================================================

DO $$
DECLARE
  constraint_name text;
BEGIN
  -- Find and drop all constraints related to email
  FOR constraint_name IN (
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public."CompanyPortalUsers"'::regclass
      AND conname LIKE '%email%'
  ) LOOP
    EXECUTE 'ALTER TABLE public."CompanyPortalUsers" DROP CONSTRAINT IF EXISTS ' || quote_ident(constraint_name);
  END LOOP;
END $$;

-- ============================================================
-- 5) Remove email column if it exists
-- ============================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'CompanyPortalUsers' 
    AND column_name = 'email'
  ) THEN
    ALTER TABLE public."CompanyPortalUsers" 
    DROP COLUMN email CASCADE;
    
    RAISE NOTICE 'Dropped email column from CompanyPortalUsers';
  ELSE
    RAISE NOTICE 'email column does not exist in CompanyPortalUsers (already removed)';
  END IF;
END $$;

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Migrated any remaining data from email to portal_user_email
-- 2. Dropped RLS policies that depend on email (if any)
-- 3. Dropped indexes on email (if any)
-- 4. Dropped foreign key constraints on email (if any)
-- 5. Dropped email column from CompanyPortalUsers
-- 
-- The table now uses only portal_user_email for email addresses
-- ============================================================
