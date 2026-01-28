-- ============================================================
-- Migration: Remove Profiles table dependency from get_auth_context()
-- ============================================================
-- OBJETIVO:
-- Actualizar get_auth_context() para NO depender de la tabla Profiles
-- Usar must_change_password de OrganizationUsers/CompanyPortalUsers en su lugar
-- ============================================================

BEGIN;

-- Drop existing get_auth_context() function
DROP FUNCTION IF EXISTS public.get_auth_context() CASCADE;

-- Recreate get_auth_context() without Profiles dependency
CREATE FUNCTION public.get_auth_context()
RETURNS TABLE (
  user_id uuid,
  is_org_user boolean,
  is_portal_user boolean,
  organization_id uuid,
  company_id uuid,
  needs_password boolean,
  access_allowed boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_org_user_id uuid;
  v_portal_user_id uuid;
  v_organization_id uuid;
  v_company_id uuid;
  v_org_status text;
  v_portal_status text;
  v_org_must_change_password boolean;
  v_portal_must_change_password boolean;
  v_is_org_user boolean := false;
  v_is_portal_user boolean := false;
  v_access_allowed boolean := false;
  v_needs_password boolean := false;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  -- If no user, return empty context
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 
      NULL::uuid,
      false::boolean,
      false::boolean,
      NULL::uuid,
      NULL::uuid,
      false::boolean,
      false::boolean;
    RETURN;
  END IF;

  -- Check for OrganizationUser membership (active or invited)
  SELECT 
    ou.id,
    ou.organization_id,
    ou.status,
    COALESCE(ou.must_change_password, false)
  INTO 
    v_org_user_id,
    v_organization_id,
    v_org_status,
    v_org_must_change_password
  FROM public."OrganizationUsers" ou
  WHERE ou.user_id = v_user_id
    AND ou.deleted = false
    AND ou.status IN ('active', 'invited')
  LIMIT 1;

  IF v_org_user_id IS NOT NULL THEN
    v_is_org_user := true;
    v_access_allowed := true;
  END IF;

  -- Check for CompanyPortalUser membership (active or invited)
  IF v_org_user_id IS NULL THEN
    SELECT 
      cpu.id,
      cpu.company_id,
      cpu.organization_id,
      cpu.status,
      COALESCE(cpu.must_change_password, false)
    INTO 
      v_portal_user_id,
      v_company_id,
      v_organization_id,
      v_portal_status,
      v_portal_must_change_password
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.user_id = v_user_id
      AND cpu.deleted = false
      AND cpu.status IN ('active', 'invited')
    LIMIT 1;

    IF v_portal_user_id IS NOT NULL THEN
      v_is_portal_user := true;
      v_access_allowed := true;
    END IF;
  ELSE
    -- If org user, also try to get company_id and status from portal user
    SELECT 
      cpu.company_id,
      cpu.status,
      COALESCE(cpu.must_change_password, false)
    INTO 
      v_company_id,
      v_portal_status,
      v_portal_must_change_password
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.user_id = v_user_id
      AND cpu.deleted = false
      AND cpu.status IN ('active', 'invited')
    LIMIT 1;
  END IF;

  -- ✅ needs_password = true if must_change_password is true in EITHER table
  v_needs_password := COALESCE(v_org_must_change_password, false) OR COALESCE(v_portal_must_change_password, false);

  -- Return context
  RETURN QUERY SELECT 
    v_user_id,
    v_is_org_user,
    v_is_portal_user,
    v_organization_id,
    v_company_id,
    v_needs_password,
    v_access_allowed;
END;
$$;

COMMENT ON FUNCTION public.get_auth_context IS 
  'Get authentication context for current user. Checks membership in OrganizationUsers and CompanyPortalUsers. Returns membership status, organization/company IDs, password requirement (from must_change_password), and access permission. NO dependency on Profiles table. STABLE function safe for use in queries.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_auth_context() TO authenticated;

COMMIT;
