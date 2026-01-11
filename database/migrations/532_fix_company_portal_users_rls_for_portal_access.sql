-- ============================================================
-- Migration: Fix CompanyPortalUsers RLS to allow portal users to read their own records
-- ============================================================
-- OBJECTIVE:
-- Update RLS policy for CompanyPortalUsers SELECT to allow portal users to read their own records
-- even when user_id is NULL (not yet linked) by matching portal_user_email with session email.
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Create helper function to check if current user is a portal user (by email or user_id)
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_portal_user_or_email_match(
  p_portal_user_email text,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id uuid;
  v_current_user_email text;
BEGIN
  -- Get current authenticated user
  v_current_user_id := auth.uid();
  
  -- If no authenticated user, deny access
  IF v_current_user_id IS NULL THEN
    RETURN false;
  END IF;

  -- Check match by user_id (if portal user is already linked)
  IF p_user_id IS NOT NULL AND p_user_id = v_current_user_id THEN
    RETURN true;
  END IF;

  -- Check match by email (for invites not yet linked)
  SELECT email INTO v_current_user_email
  FROM auth.users
  WHERE id = v_current_user_id;

  IF v_current_user_email IS NOT NULL 
     AND p_portal_user_email IS NOT NULL
     AND lower(trim(p_portal_user_email)) = lower(trim(v_current_user_email)) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

COMMENT ON FUNCTION public.is_portal_user_or_email_match IS 
  'Checks if current authenticated user matches a portal user by user_id or by email (case-insensitive). Used in RLS policies to allow portal users to read their own records even when not yet linked.';

-- ============================================================
-- 2) Update SELECT policy to allow portal users to read their own records
-- ============================================================
DROP POLICY IF EXISTS companyportalusers_select_own_org ON public."CompanyPortalUsers";

-- New policy: allow if:
-- A) User is an internal organization member (via is_company_member)
-- B) OR user is the portal user themselves (by user_id or email match)
CREATE POLICY companyportalusers_select_own_org
  ON public."CompanyPortalUsers"
  FOR SELECT
  USING (
    deleted = false
    AND (
      -- Internal organization members can see portal users in their companies
      (
        company_id IS NOT NULL 
        AND public.is_company_member(company_id)
      )
      OR
      -- Portal users can see their own record (by user_id or email)
      public.is_portal_user_or_email_match(portal_user_email, user_id)
      OR
      -- Also check if organization_id exists and user is org member
      (
        organization_id IS NOT NULL
        AND EXISTS (
          SELECT 1
          FROM public."OrganizationUsers" ou
          WHERE ou.organization_id = "CompanyPortalUsers".organization_id
            AND ou.user_id = auth.uid()
            AND ou.deleted = false
            AND ou.status IN ('active', 'invited')
        )
      )
    )
  );

COMMENT ON POLICY companyportalusers_select_own_org ON public."CompanyPortalUsers" IS 
  'Allows internal org members to see portal users in their companies, and portal users to see their own records (even if not yet linked by user_id).';

-- ============================================================
-- 3) Grant execute permission on helper function
-- ============================================================
GRANT EXECUTE ON FUNCTION public.is_portal_user_or_email_match(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_portal_user_or_email_match(text, uuid) TO anon;

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
-- Summary:
-- 1. Created helper function is_portal_user_or_email_match to check if current user matches portal user
-- 2. Updated SELECT policy to allow portal users to read their own records by user_id or email
-- 3. Policy now supports both internal members (via is_company_member) and portal users (via email/user_id match)
-- ============================================================
