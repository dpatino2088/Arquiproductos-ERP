-- Migration: Fix INSERT policy to allow SuperAdmins to create users in any organization
-- This fixes the issue where SuperAdmins couldn't create users because they might not
-- be in OrganizationUsers for that specific organization

-- Step 1: Drop the existing policy
DROP POLICY IF EXISTS "organizationusers_insert_owners_admins" ON "OrganizationUsers";

-- Step 2: Recreate the policy with SuperAdmin support
-- SuperAdmins can create users in any organization with any role
-- IMPORTANT: This policy uses only helper functions to avoid recursion
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
    -- Must be owner or admin in the same organization
    -- Use helper function (has SECURITY DEFINER, avoids recursion)
    public.org_is_owner_or_admin(auth.uid(), organization_id)
    -- IMPORTANT: If user is admin (not owner), they cannot create owners
    -- Use helper function to get role (also has SECURITY DEFINER, avoids recursion)
    AND (
      role != 'owner' 
      OR public.org_user_role(auth.uid(), organization_id) = 'owner'
    )
  )
);

-- Step 3: Update comment
COMMENT ON POLICY "organizationusers_insert_owners_admins" ON "OrganizationUsers" IS 
  'Owners, admins, and superadmins can invite users. Admins cannot create owners. SuperAdmins can create users in any organization with any role.';

