-- Migration: Add temp password flow columns
-- Date: 2026-01-12
-- Description: Adds must_change_password and temp_password_set_at columns to OrganizationUsers and CompanyPortalUsers

BEGIN;

-- ============================================================
-- 1) Add columns to OrganizationUsers
-- ============================================================
DO $$
BEGIN
  -- Add must_change_password column
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'OrganizationUsers'
      AND column_name = 'must_change_password'
  ) THEN
    ALTER TABLE public."OrganizationUsers"
    ADD COLUMN must_change_password boolean NOT NULL DEFAULT false;
  END IF;

  -- Add temp_password_set_at column
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'OrganizationUsers'
      AND column_name = 'temp_password_set_at'
  ) THEN
    ALTER TABLE public."OrganizationUsers"
    ADD COLUMN temp_password_set_at timestamptz NULL;
  END IF;
END $$;

-- ============================================================
-- 2) Add columns to CompanyPortalUsers
-- ============================================================
DO $$
BEGIN
  -- Add must_change_password column
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'CompanyPortalUsers'
      AND column_name = 'must_change_password'
  ) THEN
    ALTER TABLE public."CompanyPortalUsers"
    ADD COLUMN must_change_password boolean NOT NULL DEFAULT false;
  END IF;

  -- Add temp_password_set_at column
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'CompanyPortalUsers'
      AND column_name = 'temp_password_set_at'
  ) THEN
    ALTER TABLE public."CompanyPortalUsers"
    ADD COLUMN temp_password_set_at timestamptz NULL;
  END IF;
END $$;

-- ============================================================
-- 3) Ensure unique constraints exist (or create them)
-- ============================================================

-- OrganizationUsers: unique (organization_id, user_email)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'organizationusers_org_email_unique'
  ) THEN
    -- Check if index or constraint already exists with different name
    IF NOT EXISTS (
      SELECT 1
      FROM pg_indexes
      WHERE tablename = 'OrganizationUsers'
        AND indexdef LIKE '%organization_id%user_email%'
    ) THEN
      ALTER TABLE public."OrganizationUsers"
      ADD CONSTRAINT organizationusers_org_email_unique 
      UNIQUE (organization_id, user_email);
    END IF;
  END IF;
END $$;

-- CompanyPortalUsers: unique (company_id, portal_user_email)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'companyportalusers_company_email_unique'
  ) THEN
    -- Check if index or constraint already exists with different name
    IF NOT EXISTS (
      SELECT 1
      FROM pg_indexes
      WHERE tablename = 'CompanyPortalUsers'
        AND indexdef LIKE '%company_id%portal_user_email%'
    ) THEN
      ALTER TABLE public."CompanyPortalUsers"
      ADD CONSTRAINT companyportalusers_company_email_unique 
      UNIQUE (company_id, portal_user_email);
    END IF;
  END IF;
END $$;

-- ============================================================
-- 4) Helper function: get must_change_password for current user
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_must_change_password()
RETURNS TABLE (
  must_change_password boolean,
  user_type text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_org_must_change boolean;
  v_portal_must_change boolean;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT false, 'none'::text;
    RETURN;
  END IF;

  -- Check OrganizationUsers
  SELECT ou.must_change_password
  INTO v_org_must_change
  FROM public."OrganizationUsers" ou
  WHERE ou.user_id = v_user_id
    AND ou.deleted = false
  LIMIT 1;

  IF v_org_must_change IS NOT NULL THEN
    RETURN QUERY SELECT v_org_must_change, 'org'::text;
    RETURN;
  END IF;

  -- Check CompanyPortalUsers
  SELECT cpu.must_change_password
  INTO v_portal_must_change
  FROM public."CompanyPortalUsers" cpu
  WHERE cpu.user_id = v_user_id
    AND cpu.deleted = false
  LIMIT 1;

  IF v_portal_must_change IS NOT NULL THEN
    RETURN QUERY SELECT v_portal_must_change, 'portal'::text;
    RETURN;
  END IF;

  -- No membership found
  RETURN QUERY SELECT false, 'none'::text;
END;
$$;

COMMENT ON FUNCTION public.get_must_change_password() IS 
  'Returns must_change_password flag and user type (org/portal/none) for the current authenticated user';

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Added must_change_password and temp_password_set_at to OrganizationUsers
-- 2. Added must_change_password and temp_password_set_at to CompanyPortalUsers
-- 3. Ensured unique constraints on (organization_id, user_email) and (company_id, portal_user_email)
-- 4. Created helper function get_must_change_password() for login guard
-- ============================================================
