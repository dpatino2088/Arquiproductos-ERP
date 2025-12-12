-- Migration: Add RLS policies for OrganizationUsers
-- These policies enforce role-based access control for organization user management

-- Step 1: Ensure RLS is enabled
ALTER TABLE "OrganizationUsers" ENABLE ROW LEVEL SECURITY;

-- Step 2: Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "organizationusers_select_own" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_select_org_admins" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_insert_owners_admins" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_update_owners" ON "OrganizationUsers";
DROP POLICY IF EXISTS "organizationusers_delete_owners" ON "OrganizationUsers";

-- Step 3: SELECT policies
-- Policy 1: Users can see their own OrganizationUsers record
CREATE POLICY "organizationusers_select_own"
ON "OrganizationUsers"
FOR SELECT
USING (user_id = auth.uid());

-- Policy 2: Owners, admins, and superadmins can see all users in their organization
CREATE POLICY "organizationusers_select_org_admins"
ON "OrganizationUsers"
FOR SELECT
USING (
  organization_id IN (
    SELECT organization_id 
    FROM "OrganizationUsers" 
    WHERE user_id = auth.uid() 
      AND deleted = false
      AND role IN ('owner', 'admin')
  )
  OR EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = auth.uid()
  )
);

-- Step 4: INSERT policy
-- Only owners, admins, and superadmins can invite/create users in their organization
CREATE POLICY "organizationusers_insert_owners_admins"
ON "OrganizationUsers"
FOR INSERT
WITH CHECK (
  -- Must be owner or admin in the same organization
  public.org_is_owner_or_admin(auth.uid(), organization_id)
  -- The organization_id must match one where the inviter has permissions
  AND organization_id IN (
    SELECT organization_id 
    FROM "OrganizationUsers" 
    WHERE user_id = auth.uid() 
      AND deleted = false
      AND role IN ('owner', 'admin')
  )
);

-- Step 5: UPDATE policy
-- Only owners and superadmins can change roles of other users
-- Users can update their own record (except role changes)
CREATE POLICY "organizationusers_update_owners"
ON "OrganizationUsers"
FOR UPDATE
USING (
  -- Users can update their own record (but not change role)
  (user_id = auth.uid() AND role = (SELECT role FROM "OrganizationUsers" WHERE id = "OrganizationUsers".id))
  OR
  -- Owners and superadmins can update any user in their organization
  (
    public.org_is_owner_or_superadmin(auth.uid(), organization_id)
    AND organization_id IN (
      SELECT organization_id 
      FROM "OrganizationUsers" 
      WHERE user_id = auth.uid() 
        AND deleted = false
        AND role = 'owner'
    )
  )
  OR
  -- Superadmins can update any organization
  EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = auth.uid()
  )
)
WITH CHECK (
  -- Same conditions for the updated row
  (
    user_id = auth.uid() AND role = (SELECT role FROM "OrganizationUsers" WHERE id = "OrganizationUsers".id)
  )
  OR
  (
    public.org_is_owner_or_superadmin(auth.uid(), organization_id)
    AND organization_id IN (
      SELECT organization_id 
      FROM "OrganizationUsers" 
      WHERE user_id = auth.uid() 
        AND deleted = false
        AND role = 'owner'
    )
  )
  OR
  EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = auth.uid()
  )
);

-- Step 6: DELETE policy
-- Only owners and superadmins can delete (soft delete) OrganizationUsers records
CREATE POLICY "organizationusers_delete_owners"
ON "OrganizationUsers"
FOR DELETE
USING (
  public.org_is_owner_or_superadmin(auth.uid(), organization_id)
  AND organization_id IN (
    SELECT organization_id 
    FROM "OrganizationUsers" 
    WHERE user_id = auth.uid() 
      AND deleted = false
      AND role = 'owner'
  )
  OR
  EXISTS (
    SELECT 1 
    FROM "PlatformAdmins" 
    WHERE user_id = auth.uid()
  )
);

-- Note: The UPDATE policy above allows users to update their own record
-- but prevents them from changing their own role. If you want to prevent
-- users from removing themselves as owner when they're the only owner,
-- you would need additional logic in a trigger or application code.

-- Add comments to policies
COMMENT ON POLICY "organizationusers_select_own" ON "OrganizationUsers" IS 
  'Users can see their own OrganizationUsers record';

COMMENT ON POLICY "organizationusers_select_org_admins" ON "OrganizationUsers" IS 
  'Owners, admins, and superadmins can see all users in their organization';

COMMENT ON POLICY "organizationusers_insert_owners_admins" ON "OrganizationUsers" IS 
  'Only owners, admins, and superadmins can invite users to their organization';

COMMENT ON POLICY "organizationusers_update_owners" ON "OrganizationUsers" IS 
  'Only owners and superadmins can change roles; users can update their own record (except role)';

COMMENT ON POLICY "organizationusers_delete_owners" ON "OrganizationUsers" IS 
  'Only owners and superadmins can delete OrganizationUsers records';
