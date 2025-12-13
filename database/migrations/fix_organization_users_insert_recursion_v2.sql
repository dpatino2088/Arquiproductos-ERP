-- Migration: Fix infinite recursion in OrganizationUsers INSERT policy (Version 2)
-- Problem: Even with SECURITY DEFINER functions, there's still recursion when
-- the functions query OrganizationUsers within the INSERT policy context.
--
-- Solution: Create a specialized function that explicitly disables RLS
-- and simplify the policy to avoid any recursive queries.

-- Step 1: Create a function that checks permissions WITHOUT triggering RLS
-- This function will be used ONLY in INSERT policies to avoid recursion
-- CRITICAL: Uses SET LOCAL row_security = off to completely bypass RLS
CREATE OR REPLACE FUNCTION public.can_insert_organization_user(
  p_inviter_user_id uuid,
  p_organization_id uuid,
  p_new_user_role text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_is_superadmin boolean;
  v_inviter_role text;
BEGIN
  -- CRITICAL: Disable RLS for this function's execution
  -- This prevents any recursive RLS policy evaluation
  SET LOCAL row_security = off;
  
  -- Check if inviter is superadmin (no need to check OrganizationUsers)
  SELECT EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = p_inviter_user_id
  ) INTO v_is_superadmin;
  
  IF v_is_superadmin THEN
    RETURN true; -- SuperAdmins can create any user in any organization
  END IF;
  
  -- Get inviter's role in the organization
  -- With row_security = off, this query bypasses ALL RLS policies
  SELECT role INTO v_inviter_role
  FROM public."OrganizationUsers"
  WHERE user_id = p_inviter_user_id
    AND organization_id = p_organization_id
    AND deleted = false
  LIMIT 1;
  
  -- If inviter is not owner or admin, deny
  IF v_inviter_role NOT IN ('owner', 'admin') THEN
    RETURN false;
  END IF;
  
  -- If trying to create an owner, only owners (not admins) can do this
  IF p_new_user_role = 'owner' AND v_inviter_role != 'owner' THEN
    RETURN false;
  END IF;
  
  -- All checks passed
  RETURN true;
END;
$$;

-- Step 2: Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.can_insert_organization_user(uuid, uuid, text) TO authenticated;

-- Step 3: Drop the problematic policy
DROP POLICY IF EXISTS "organizationusers_insert_owners_admins" ON "OrganizationUsers";

-- Step 4: Create a simplified policy that uses the specialized function
-- This function is designed to avoid recursion by using SECURITY DEFINER
-- and explicit schema references
CREATE POLICY "organizationusers_insert_owners_admins"
ON "OrganizationUsers"
FOR INSERT
WITH CHECK (
  public.can_insert_organization_user(
    auth.uid(),
    organization_id,
    role
  )
);

-- Step 5: Update comment
COMMENT ON FUNCTION public.can_insert_organization_user(uuid, uuid, text) IS 
  'Checks if a user can insert an organization user. Designed to avoid RLS recursion in INSERT policies.';

COMMENT ON POLICY "organizationusers_insert_owners_admins" ON "OrganizationUsers" IS 
  'Allows owners, admins, and superadmins to invite users. Admins cannot create owners. Uses specialized function to avoid recursion.';

