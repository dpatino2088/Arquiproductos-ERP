-- Migration: Fix infinite recursion in OrganizationUsers INSERT policy
-- Problem: The INSERT policy was querying OrganizationUsers within its own definition,
-- causing infinite recursion when trying to insert a new user.
--
-- Solution: Simplify the policy to only use helper functions which have SECURITY DEFINER
-- and can bypass RLS, avoiding recursion.

-- Step 1: Ensure helper functions exist and have SECURITY DEFINER
-- (These should already exist from add_rls_helper_functions.sql, but we ensure they're correct)

-- Step 2: Drop the problematic policy
DROP POLICY IF EXISTS "organizationusers_insert_owners_admins" ON "OrganizationUsers";

-- Step 3: Create a simplified policy that only uses helper functions
-- This avoids recursion because helper functions have SECURITY DEFINER
CREATE POLICY "organizationusers_insert_owners_admins"
ON "OrganizationUsers"
FOR INSERT
WITH CHECK (
  -- SuperAdmins can create users in any organization
  EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = auth.uid()
  )
  OR (
    -- Use helper function to check if user is owner or admin in this organization
    -- This function has SECURITY DEFINER, so it bypasses RLS and avoids recursion
    public.org_is_owner_or_admin(auth.uid(), organization_id)
    -- IMPORTANT: If user is admin (not owner), they cannot create owners
    -- Use helper function to get the inviter's role (also has SECURITY DEFINER)
    AND (
      role != 'owner' 
      OR public.org_user_role(auth.uid(), organization_id) = 'owner'
    )
  )
);

-- Step 4: Update comment
COMMENT ON POLICY "organizationusers_insert_owners_admins" ON "OrganizationUsers" IS 
  'Allows owners, admins, and superadmins to invite users. Admins cannot create owners. Uses helper functions with SECURITY DEFINER to avoid recursion.';

