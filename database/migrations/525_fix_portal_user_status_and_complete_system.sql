-- ============================================================
-- Migration: Fix portal user status and complete portal system
-- ============================================================
-- OBJECTIVE:
-- 1. Ensure CompanyPortalUsers status uses only 'active' or 'disabled' (not 'invited' or 'draft')
-- 2. Normalize existing portal users with 'invited' or 'draft' status to 'active'
-- 3. Update RLS policies to use correct status check
-- 4. Ensure portal_user_role is properly constrained to only 'member_manager' or 'member'
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Normalize portal_user_status to only 'active' or 'disabled'
-- ============================================================

DO $$
BEGIN
  -- Update existing records: 'invited' or 'draft' -> 'active', keep 'active' and 'disabled' as-is
  UPDATE public."CompanyPortalUsers"
  SET portal_user_status = CASE
    WHEN portal_user_status IN ('invited', 'draft') THEN 'active'
    WHEN portal_user_status IN ('active', 'disabled') THEN portal_user_status
    ELSE 'active' -- Default fallback
  END
  WHERE portal_user_status NOT IN ('active', 'disabled');

  RAISE NOTICE 'Normalized portal_user_status: invited/draft -> active';
END $$;

-- ============================================================
-- 2) Update get_current_portal_user to use correct status
-- ============================================================

-- Drop existing function first to avoid return type mismatch
-- Drop all overloads of the function dynamically
DO $$
DECLARE
  func_record record;
  drop_sql text;
BEGIN
  -- Find all versions of get_current_portal_user and drop them
  FOR func_record IN 
    SELECT 
      oid,
      pg_get_function_identity_arguments(oid) as args,
      oid::regprocedure::text as func_signature
    FROM pg_proc
    WHERE proname = 'get_current_portal_user'
      AND pronamespace = 'public'::regnamespace
  LOOP
    BEGIN
      -- Build DROP statement - handle functions with no arguments
      IF func_record.args = '' OR func_record.args IS NULL THEN
        drop_sql := 'DROP FUNCTION IF EXISTS public.get_current_portal_user() CASCADE';
      ELSE
        drop_sql := 'DROP FUNCTION IF EXISTS public.get_current_portal_user(' || func_record.args || ') CASCADE';
      END IF;
      
      EXECUTE drop_sql;
      RAISE NOTICE 'Dropped function: %', func_record.func_signature;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop function: % - Error: %', func_record.func_signature, SQLERRM;
    END;
  END LOOP;
END $$;

-- Recreate with correct signature (includes organization_id)
CREATE FUNCTION public.get_current_portal_user()
RETURNS TABLE (
  id uuid,
  organization_id uuid,
  company_id uuid,
  portal_user_role text,
  portal_user_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cpu.id,
    cpu.organization_id,
    cpu.company_id,
    COALESCE(cpu.portal_user_role, 'member')::text as portal_user_role,
    cpu.portal_user_status::text as portal_user_status
  FROM public."CompanyPortalUsers" cpu
  WHERE cpu.user_id = auth.uid()
    AND cpu.deleted = false
    AND cpu.portal_user_status = 'active' -- Only active portal users
  LIMIT 1;
END;
$$;

COMMENT ON FUNCTION public.get_current_portal_user IS 'Retrieves active portal user details for RLS. SECURITY DEFINER. Only returns active users.';

-- ============================================================
-- 3) Ensure portal_user_role constraint is correct
-- ============================================================

DO $$
BEGIN
  -- Normalize any legacy role values
  UPDATE public."CompanyPortalUsers"
  SET portal_user_role = CASE
    WHEN portal_user_role = 'manager' THEN 'member_manager'
    WHEN portal_user_role NOT IN ('member_manager', 'member') THEN 'member'
    ELSE portal_user_role
  END
  WHERE portal_user_role NOT IN ('member_manager', 'member');
  
  RAISE NOTICE 'Normalized portal_user_role: manager -> member_manager, others -> member';
END $$;

-- Ensure constraint exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'companyportalusers_portal_user_role_check'
    AND conrelid = 'public."CompanyPortalUsers"'::regclass
  ) THEN
    ALTER TABLE public."CompanyPortalUsers"
    ADD CONSTRAINT companyportalusers_portal_user_role_check
    CHECK (portal_user_role IN ('member_manager', 'member'));
    RAISE NOTICE 'Added portal_user_role check constraint';
  ELSE
    RAISE NOTICE 'portal_user_role check constraint already exists';
  END IF;
END $$;

-- ============================================================
-- 4) Update RLS policies for CompanyPortalUsers to use correct status
-- ============================================================

-- Note: The INSERT and UPDATE policies already use is_company_owner_or_admin
-- which we fixed in migration 524. No changes needed here.

-- ============================================================
-- 5) Verify Quotes RLS policies are correct (already in migration 522)
-- ============================================================

-- The RLS policies for Quotes were already created in migration 522
-- and they correctly use get_current_portal_user() which now only returns active users

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Normalized portal_user_status: 'invited'/'draft' -> 'active'
-- 2. Updated get_current_portal_user to only return active users
-- 3. Ensured portal_user_role constraint enforces only 'member_manager' or 'member'
-- 4. Normalized legacy role values ('manager' -> 'member_manager')
-- ============================================================
