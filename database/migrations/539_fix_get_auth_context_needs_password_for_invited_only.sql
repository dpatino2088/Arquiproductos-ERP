-- ============================================================
-- Migration: Fix get_auth_context() to only require password for invited users
-- ============================================================
-- OBJETIVO:
-- Modificar get_auth_context() para que needs_password = true SOLO si:
-- 1) El usuario tiene status='invited' (en OrganizationUsers o CompanyPortalUsers)
-- 2) Y password_set_at IS NULL
-- 
-- Si el usuario tiene status='active', NO necesita password (puede haber hecho login normal)
-- ============================================================

BEGIN;

-- Drop and recreate get_auth_context() function with fixed logic
DO $$
DECLARE
  func_record record;
  drop_sql text;
BEGIN
  FOR func_record IN 
    SELECT 
      oid,
      pg_get_function_identity_arguments(oid) as args,
      oid::regprocedure::text as func_signature
    FROM pg_proc
    WHERE proname = 'get_auth_context'
      AND pronamespace = 'public'::regnamespace
  LOOP
    BEGIN
      IF func_record.args = '' OR func_record.args IS NULL THEN
        drop_sql := 'DROP FUNCTION IF EXISTS public.get_auth_context() CASCADE';
      ELSE
        drop_sql := 'DROP FUNCTION IF EXISTS public.get_auth_context(' || func_record.args || ') CASCADE';
      END IF;
      
      EXECUTE drop_sql;
      RAISE NOTICE 'Dropped function: %', func_record.func_signature;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop function: % - Error: %', func_record.func_signature, SQLERRM;
    END;
  END LOOP;
END $$;

-- Recreate get_auth_context() function with fixed needs_password logic
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
-- IMPORTANT: Don't use SET search_path - use explicit schema prefixes
AS $$
DECLARE
  v_user_id uuid;
  v_org_user_id uuid;
  v_portal_user_id uuid;
  v_organization_id uuid;
  v_company_id uuid;
  v_password_set_at timestamptz;
  v_org_status text;
  v_portal_status text;
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
    ou.status
  INTO 
    v_org_user_id,
    v_organization_id,
    v_org_status
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
  -- Only check if not already an org user (portal takes precedence in UI, but both can exist)
  IF v_org_user_id IS NULL THEN
    SELECT 
      cpu.id,
      cpu.company_id,
      cpu.organization_id,
      cpu.status
    INTO 
      v_portal_user_id,
      v_company_id,
      v_organization_id,
      v_portal_status
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
    -- If org user, also try to get company_id and status from portal user (might be both)
    SELECT 
      cpu.company_id,
      cpu.status
    INTO 
      v_company_id,
      v_portal_status
    FROM public."CompanyPortalUsers" cpu
    WHERE cpu.user_id = v_user_id
      AND cpu.deleted = false
      AND cpu.status IN ('active', 'invited')
    LIMIT 1;
  END IF;

  -- Check password_set_at from Profiles (Profiles uses user_id as PK)
  SELECT p.password_set_at
  INTO v_password_set_at
  FROM public."Profiles" p
  WHERE p.user_id = v_user_id
  LIMIT 1;

  -- needs_password = true ONLY if:
  -- 1) User has status='invited' (in OrganizationUsers or CompanyPortalUsers)
  -- 2) AND password_set_at IS NULL
  -- 
  -- If user has status='active', they don't need to set password (they already logged in successfully)
  IF v_password_set_at IS NULL THEN
    -- Only require password if user is invited
    IF (v_org_status = 'invited' OR v_portal_status = 'invited') THEN
      v_needs_password := true;
    ELSE
      -- User is active, no password needed
      v_needs_password := false;
    END IF;
  ELSE
    -- Password already set
    v_needs_password := false;
  END IF;

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
  'Get authentication context for current user. Checks membership in OrganizationUsers and CompanyPortalUsers. Returns membership status, organization/company IDs, password requirement (only for invited users), and access permission. STABLE function safe for use in queries.';

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_auth_context() TO authenticated;

COMMIT;
