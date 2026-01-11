-- ============================================================
-- Migration: Update list_organization_users to allow superadmin
-- ============================================================
-- OBJECTIVE:
-- Update the list_organization_users RPC function to allow
-- superadmin role to list organization users, in addition to
-- admin and owner roles.
-- ============================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.list_organization_users(
  p_organization_id uuid
)
RETURNS SETOF public."OrganizationUsers"
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_user_id uuid;
  v_caller_role public.org_role;
BEGIN
  -- Obtener caller user_id
  v_caller_user_id := auth.uid();
  
  IF v_caller_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Validar que caller es miembro de la organización
  SELECT ou.role INTO v_caller_role
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND ou.user_id = v_caller_user_id
    AND ou.deleted = false
    AND ou.status = 'active'
  LIMIT 1;

  IF v_caller_role IS NULL THEN
    RAISE EXCEPTION 'Caller is not a member of organization %', p_organization_id;
  END IF;

  -- Allow superadmin, admin, and owner (legacy) roles to list users
  IF v_caller_role::text NOT IN ('superadmin', 'admin', 'owner') THEN
    RAISE EXCEPTION 'Only superadmins, admins, and owners can list organization users';
  END IF;

  -- Retornar usuarios de la organización (deleted=false)
  RETURN QUERY
  SELECT ou.*
  FROM public."OrganizationUsers" ou
  WHERE ou.organization_id = p_organization_id
    AND ou.deleted = false
  ORDER BY ou.created_at DESC;
END;
$$;

COMMENT ON FUNCTION public.list_organization_users IS 'List all users in an organization. Only superadmins, admins, and owners can call.';

COMMIT;

-- ============================================================
-- Migration complete
-- ============================================================
