-- Migration: Add helper functions for RLS policies
-- These functions simplify RLS policy definitions and improve readability

-- Function 1: Get organization role for a user
-- Returns the role from OrganizationUsers or NULL if user is not a member
CREATE OR REPLACE FUNCTION public.org_user_role(
  p_user_id uuid,
  p_org_id uuid
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_role text;
BEGIN
  SELECT role INTO v_role
  FROM "OrganizationUsers"
  WHERE user_id = p_user_id
    AND organization_id = p_org_id
    AND deleted = false
  LIMIT 1;
  
  RETURN v_role;
END;
$$;

-- Function 2: Check if user is owner or admin (or superadmin)
-- Returns true if:
--   - User is owner or admin in OrganizationUsers, OR
--   - User is in PlatformAdmins (superadmin)
CREATE OR REPLACE FUNCTION public.org_is_owner_or_admin(
  p_user_id uuid,
  p_org_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_role text;
  v_is_superadmin boolean;
BEGIN
  -- Check if user is superadmin
  SELECT EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = p_user_id
  ) INTO v_is_superadmin;
  
  IF v_is_superadmin THEN
    RETURN true;
  END IF;
  
  -- Get user's role in organization
  SELECT role INTO v_role
  FROM "OrganizationUsers"
  WHERE user_id = p_user_id
    AND organization_id = p_org_id
    AND deleted = false
  LIMIT 1;
  
  -- Return true if owner or admin
  RETURN v_role IN ('owner', 'admin');
END;
$$;

-- Function 3: Check if user is owner or superadmin
-- Returns true if user is owner in OrganizationUsers or superadmin
CREATE OR REPLACE FUNCTION public.org_is_owner_or_superadmin(
  p_user_id uuid,
  p_org_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_role text;
  v_is_superadmin boolean;
BEGIN
  -- Check if user is superadmin
  SELECT EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = p_user_id
  ) INTO v_is_superadmin;
  
  IF v_is_superadmin THEN
    RETURN true;
  END IF;
  
  -- Get user's role in organization
  SELECT role INTO v_role
  FROM "OrganizationUsers"
  WHERE user_id = p_user_id
    AND organization_id = p_org_id
    AND deleted = false
  LIMIT 1;
  
  -- Return true if owner
  RETURN v_role = 'owner';
END;
$$;

-- Add comments to functions
COMMENT ON FUNCTION public.org_user_role(uuid, uuid) IS 
  'Returns the organization role for a user, or NULL if not a member';

COMMENT ON FUNCTION public.org_is_owner_or_admin(uuid, uuid) IS 
  'Returns true if user is owner, admin, or superadmin';

COMMENT ON FUNCTION public.org_is_owner_or_superadmin(uuid, uuid) IS 
  'Returns true if user is owner or superadmin';
