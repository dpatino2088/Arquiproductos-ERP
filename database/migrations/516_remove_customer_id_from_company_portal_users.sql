-- ============================================================
-- Migration: Remove customer_id from CompanyPortalUsers
-- ============================================================
-- OBJECTIVE:
-- Remove customer_id column from CompanyPortalUsers table
-- The table now uses company_id exclusively
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Drop RLS policies that depend on customer_id
-- ============================================================

-- Drop old policies that reference customer_id
DROP POLICY IF EXISTS portalusers_select ON public."CompanyPortalUsers";
DROP POLICY IF EXISTS portalusers_write_internal ON public."CompanyPortalUsers";
DROP POLICY IF EXISTS portalusers_insert ON public."CompanyPortalUsers";
DROP POLICY IF EXISTS portalusers_update ON public."CompanyPortalUsers";
DROP POLICY IF EXISTS portalusers_delete ON public."CompanyPortalUsers";
DROP POLICY IF EXISTS companyportalusers_select_customer ON public."CompanyPortalUsers";
DROP POLICY IF EXISTS companyportalusers_insert_customer ON public."CompanyPortalUsers";
DROP POLICY IF EXISTS companyportalusers_update_customer ON public."CompanyPortalUsers";
DROP POLICY IF EXISTS companyportalusers_delete_customer ON public."CompanyPortalUsers";

-- ============================================================
-- 2) Remove customer_id constraint and column if exists
-- ============================================================

-- First, drop any foreign key constraints on customer_id
DO $$
BEGIN
  -- Drop foreign key constraint if exists
  IF EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname LIKE '%companyportalusers_customer_id%'
    AND conrelid = 'public."CompanyPortalUsers"'::regclass
  ) THEN
    ALTER TABLE public."CompanyPortalUsers" 
    DROP CONSTRAINT IF EXISTS companyportalusers_customer_id_fkey;
  END IF;
END $$;

-- Drop any indexes on customer_id
DROP INDEX IF EXISTS idx_companyportalusers_customer;
DROP INDEX IF EXISTS idx_companyportalusers_customer_id;

-- Remove customer_id column if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' 
    AND table_name = 'CompanyPortalUsers' 
    AND column_name = 'customer_id'
  ) THEN
    ALTER TABLE public."CompanyPortalUsers" 
    DROP COLUMN customer_id CASCADE;
    
    RAISE NOTICE 'Dropped customer_id column from CompanyPortalUsers';
  ELSE
    RAISE NOTICE 'customer_id column does not exist in CompanyPortalUsers (already removed)';
  END IF;
END $$;

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Dropped foreign key constraint on customer_id (if exists)
-- 2. Dropped indexes on customer_id (if exist)
-- 3. Dropped customer_id column from CompanyPortalUsers
-- 
-- The table now uses only company_id for relationships
-- ============================================================
