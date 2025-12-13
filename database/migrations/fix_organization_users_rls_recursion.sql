-- Migration: Fix RLS policy recursion for OrganizationUsers SELECT
-- This fixes the "stack depth limit exceeded" error when Admins try to view users
-- 
-- Problem: The SELECT policy was querying OrganizationUsers within its own definition,
-- causing infinite recursion when evaluating the policy.
--
-- Solution: Use the helper function org_is_owner_or_admin which has SECURITY DEFINER
-- to bypass RLS and avoid recursion.

-- Step 1: Ensure the helper function exists with SECURITY DEFINER
-- Recreate the function to ensure it has SECURITY DEFINER
CREATE OR REPLACE FUNCTION public.org_is_owner_or_admin(
  p_user_id uuid,
  p_org_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER  -- This is critical to avoid recursion
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
  -- SECURITY DEFINER allows this to bypass RLS
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

-- Step 2: Drop the problematic policy
DROP POLICY IF EXISTS "organizationusers_select_org_admins" ON "OrganizationUsers";

-- Step 3: Recreate the policy using the helper function to avoid recursion
-- The helper function has SECURITY DEFINER, so it bypasses RLS when checking roles
CREATE POLICY "organizationusers_select_org_admins"
ON "OrganizationUsers"
FOR SELECT
USING (
  -- Use helper function to avoid recursion
  -- This function has SECURITY DEFINER, so it can query OrganizationUsers
  -- without triggering RLS policies recursively
  public.org_is_owner_or_admin(auth.uid(), organization_id)
);

-- Step 4: Update comment
COMMENT ON POLICY "organizationusers_select_org_admins" ON "OrganizationUsers" IS 
  'Owners, admins, and superadmins can see all users in their organization. Uses helper function to avoid recursion.';

