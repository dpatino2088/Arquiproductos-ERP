-- ============================================================
-- Migration: Stable RLS for CompanyPortalUsers
-- ============================================================
-- OBJECTIVE:
-- Create stable RLS policies for CompanyPortalUsers using minimal, idempotent functions.
-- Supports both internal OrganizationUsers and portal CompanyPortalUsers.
-- Uses column "status" (NOT portal_user_status) as per schema.
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Drop old conflicting policies
-- ============================================================
DROP POLICY IF EXISTS companyportalusers_select_own_org ON public."CompanyPortalUsers";
DROP POLICY IF EXISTS portalusers_select ON public."CompanyPortalUsers";
DROP POLICY IF EXISTS portalusers_update ON public."CompanyPortalUsers";
DROP POLICY IF EXISTS companyportalusers_select_customer ON public."CompanyPortalUsers";

-- ============================================================
-- 2) Helper function: Check if user is internal org member
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_org_user_member(p_org_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.deleted = false
      AND ou.status IN ('active', 'invited')
  );
END;
$$;

COMMENT ON FUNCTION public.is_org_user_member(uuid) IS 
  'Returns true if current user is an active/invited member of the organization via OrganizationUsers.';

-- ============================================================
-- 3) Helper function: Check if current user is the portal user themselves
-- ============================================================
CREATE OR REPLACE FUNCTION public.is_portal_user_self(p_portal_row_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_current_user_id uuid;
  v_current_email text;
  v_portal_user_id uuid;
  v_portal_email text;
BEGIN
  v_current_user_id := auth.uid();
  
  -- If no authenticated user, deny
  IF v_current_user_id IS NULL THEN
    RETURN false;
  END IF;

  -- Get portal user's user_id and email
  SELECT user_id, portal_user_email
  INTO v_portal_user_id, v_portal_email
  FROM public."CompanyPortalUsers"
  WHERE id = p_portal_row_id
    AND deleted = false;

  -- If portal user not found, deny
  IF v_portal_user_id IS NULL AND v_portal_email IS NULL THEN
    RETURN false;
  END IF;

  -- Match by user_id (if linked)
  IF v_portal_user_id IS NOT NULL AND v_portal_user_id = v_current_user_id THEN
    RETURN true;
  END IF;

  -- Match by email (fallback for unlinked invites)
  -- Use auth.jwt()->>'email' as fallback
  v_current_email := COALESCE(
    (SELECT email FROM auth.users WHERE id = v_current_user_id),
    (auth.jwt() ->> 'email')
  );

  IF v_current_email IS NOT NULL 
     AND v_portal_email IS NOT NULL
     AND lower(trim(v_portal_email)) = lower(trim(v_current_email)) THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$;

COMMENT ON FUNCTION public.is_portal_user_self(uuid) IS 
  'Returns true if current user is the portal user themselves (by user_id or email match). Uses auth.jwt()->>''email'' as fallback.';

-- ============================================================
-- 4) Main function: Check if user can read a portal user record
-- ============================================================
CREATE OR REPLACE FUNCTION public.can_read_company_portal_user(p_portal_row_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_portal_org_id uuid;
BEGIN
  -- Case A: User is the portal user themselves
  IF public.is_portal_user_self(p_portal_row_id) THEN
    RETURN true;
  END IF;

  -- Case B: User is an internal org member of the same organization
  SELECT organization_id
  INTO v_portal_org_id
  FROM public."CompanyPortalUsers"
  WHERE id = p_portal_row_id
    AND deleted = false;

  IF v_portal_org_id IS NOT NULL THEN
    RETURN public.is_org_user_member(v_portal_org_id);
  END IF;

  RETURN false;
END;
$$;

COMMENT ON FUNCTION public.can_read_company_portal_user(uuid) IS 
  'Returns true if current user can read the portal user record: either they are the portal user themselves, or they are an internal org member of the same organization.';

-- ============================================================
-- 5) RLS Policies for CompanyPortalUsers
-- ============================================================

-- SELECT policy: allow if can_read_company_portal_user returns true
CREATE POLICY companyportalusers_select_stable
  ON public."CompanyPortalUsers"
  FOR SELECT
  USING (
    deleted = false
    AND public.can_read_company_portal_user(id)
  );

COMMENT ON POLICY companyportalusers_select_stable ON public."CompanyPortalUsers" IS 
  'Allows reading portal user records if user is the portal user themselves or an internal org member.';

-- UPDATE policy: portal users can update only their own records (for user_id linkage, etc.)
CREATE POLICY companyportalusers_update_self
  ON public."CompanyPortalUsers"
  FOR UPDATE
  USING (public.is_portal_user_self(id))
  WITH CHECK (public.is_portal_user_self(id));

COMMENT ON POLICY companyportalusers_update_self ON public."CompanyPortalUsers" IS 
  'Allows portal users to update only their own records (e.g., for user_id linkage).';

-- ============================================================
-- 6) Grant execute permissions
-- ============================================================
GRANT EXECUTE ON FUNCTION public.is_org_user_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_org_user_member(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.is_portal_user_self(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_portal_user_self(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.can_read_company_portal_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_company_portal_user(uuid) TO anon;

COMMIT;

-- ============================================================
-- 7) Verification queries (run separately after migration)
-- ============================================================

-- Test: Find portal user by email
-- SELECT id, user_id, portal_user_email, status, deleted, organization_id 
-- FROM public."CompanyPortalUsers" 
-- WHERE lower(portal_user_email) = lower('dpv2088@gmail.com') 
--   AND deleted = false;

-- Test: List organizations visible to portal user
-- SELECT DISTINCT o.id, o.name, o.created_at
-- FROM public."Organizations" o
-- JOIN public."CompanyPortalUsers" cpu ON cpu.organization_id = o.id
-- WHERE lower(cpu.portal_user_email) = lower('dpv2088@gmail.com')
--   AND cpu.deleted = false
--   AND (cpu.status IS NULL OR cpu.status IN ('active', 'invited'))
--   AND o.deleted = false;
