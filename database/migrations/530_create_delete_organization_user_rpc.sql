BEGIN;

-- Migration: Create RPC function to delete (soft delete) organization users
-- Only superadmins/admins can delete users via this RPC
-- Uses SECURITY DEFINER to bypass RLS

-- Drop function if exists
DROP FUNCTION IF EXISTS public.delete_organization_user(uuid, uuid);

CREATE OR REPLACE FUNCTION public.delete_organization_user(
  p_org_user_id uuid,
  p_organization_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_role text;
  v_result json;
BEGIN
  -- 1) Verify user is authenticated
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 2) Check if user is superadmin or admin in the organization
  SELECT ou.role INTO v_user_role
  FROM public."OrganizationUsers" ou
  WHERE ou.user_id = auth.uid()
    AND ou.organization_id = p_organization_id
    AND ou.deleted = false
    AND ou.status = 'active';

  IF v_user_role IS NULL THEN
    RAISE EXCEPTION 'User not found in organization or not active';
  END IF;

  IF v_user_role NOT IN ('superadmin', 'admin') THEN
    RAISE EXCEPTION 'Only superadmins and admins can delete users';
  END IF;

  -- 3) Verify the user to delete exists and belongs to the organization
  IF NOT EXISTS (
    SELECT 1
    FROM public."OrganizationUsers"
    WHERE id = p_org_user_id
      AND organization_id = p_organization_id
      AND deleted = false
  ) THEN
    RAISE EXCEPTION 'User not found in organization or already deleted';
  END IF;

  -- 4) Prevent self-deletion
  IF EXISTS (
    SELECT 1
    FROM public."OrganizationUsers"
    WHERE id = p_org_user_id
      AND user_id = auth.uid()
      AND organization_id = p_organization_id
  ) THEN
    RAISE EXCEPTION 'Cannot delete your own account';
  END IF;

  -- 5) Perform soft delete
  UPDATE public."OrganizationUsers"
  SET 
    deleted = true,
    updated_at = NOW()
  WHERE id = p_org_user_id
    AND organization_id = p_organization_id
    AND deleted = false;

  -- 6) Return success
  SELECT json_build_object(
    'success', true,
    'message', 'User deleted successfully',
    'id', p_org_user_id
  ) INTO v_result;

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'id', p_org_user_id
    );
END;
$$;

COMMENT ON FUNCTION public.delete_organization_user IS 'Soft delete an organization user. Only superadmins/admins can call. Uses SECURITY DEFINER to bypass RLS. Prevents self-deletion.';

COMMIT;
