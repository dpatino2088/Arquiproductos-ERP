-- ====================================================
-- RE-ENABLE RLS with Correct Policies
-- ====================================================
-- This script re-enables RLS and creates correct policies
-- so users can access their organizations
-- ====================================================

-- ====================================================
-- STEP 1: Re-enable RLS
-- ====================================================
ALTER TABLE "Organizations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "OrganizationUsers" ENABLE ROW LEVEL SECURITY;

-- ====================================================
-- STEP 2: Drop existing policies (clean slate)
-- ====================================================
DO $$
DECLARE
    pol RECORD;
BEGIN
    -- Drop OrganizationUsers policies
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'OrganizationUsers'
          AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON "OrganizationUsers"', pol.policyname);
    END LOOP;
    
    -- Drop Organizations policies
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'Organizations'
          AND schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON "Organizations"', pol.policyname);
    END LOOP;
    
    RAISE NOTICE '✅ Old policies dropped';
END $$;

-- ====================================================
-- STEP 3: Create helper functions (if they don't exist)
-- ====================================================

-- Function: Check if user is Super Admin
CREATE OR REPLACE FUNCTION public.is_super_admin(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM "PlatformAdmins" 
        WHERE user_id = p_user_id 
          AND deleted = false
    );
END;
$$;

-- ====================================================
-- STEP 4: Create RLS Policies for OrganizationUsers
-- ====================================================

-- Policy 1: Users can view their own records
CREATE POLICY "organizationusers_select_own"
ON "OrganizationUsers"
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()
    OR is_super_admin(auth.uid())
);

-- Policy 2: Owners and Admins can view all users in their organization
CREATE POLICY "organizationusers_select_org_managers"
ON "OrganizationUsers"
FOR SELECT
TO authenticated
USING (
    organization_id IN (
        SELECT organization_id 
        FROM "OrganizationUsers" 
        WHERE user_id = auth.uid() 
          AND role IN ('owner', 'admin')
          AND deleted = false
    )
    OR is_super_admin(auth.uid())
);

-- Policy 3: Owners can insert new users
CREATE POLICY "organizationusers_insert_owners"
ON "OrganizationUsers"
FOR INSERT
TO authenticated
WITH CHECK (
    organization_id IN (
        SELECT organization_id 
        FROM "OrganizationUsers" 
        WHERE user_id = auth.uid() 
          AND role = 'owner'
          AND deleted = false
    )
    OR is_super_admin(auth.uid())
);

-- Policy 4: Users can update their own profile
CREATE POLICY "organizationusers_update_own"
ON "OrganizationUsers"
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Policy 5: Owners can update any user in their organization
CREATE POLICY "organizationusers_update_owners"
ON "OrganizationUsers"
FOR UPDATE
TO authenticated
USING (
    organization_id IN (
        SELECT organization_id 
        FROM "OrganizationUsers" 
        WHERE user_id = auth.uid() 
          AND role = 'owner'
          AND deleted = false
    )
    OR is_super_admin(auth.uid())
)
WITH CHECK (
    organization_id IN (
        SELECT organization_id 
        FROM "OrganizationUsers" 
        WHERE user_id = auth.uid() 
          AND role = 'owner'
          AND deleted = false
    )
    OR is_super_admin(auth.uid())
);

-- Policy 6: Owners can soft-delete users
CREATE POLICY "organizationusers_delete_owners"
ON "OrganizationUsers"
FOR UPDATE
TO authenticated
USING (
    organization_id IN (
        SELECT organization_id 
        FROM "OrganizationUsers" 
        WHERE user_id = auth.uid() 
          AND role = 'owner'
          AND deleted = false
    )
    OR is_super_admin(auth.uid())
);

-- ====================================================
-- STEP 5: Create RLS Policies for Organizations
-- ====================================================

-- Policy 1: Super Admins can do everything
CREATE POLICY "orgs_superadmin_all"
ON "Organizations"
FOR ALL
TO authenticated
USING (is_super_admin(auth.uid()))
WITH CHECK (is_super_admin(auth.uid()));

-- Policy 2: Users can view organizations they belong to
CREATE POLICY "orgs_select_members"
ON "Organizations"
FOR SELECT
TO authenticated
USING (
    id IN (
        SELECT organization_id 
        FROM "OrganizationUsers" 
        WHERE user_id = auth.uid() 
          AND deleted = false
    )
    OR is_super_admin(auth.uid())
);

-- Policy 3: Owners can update their organization
CREATE POLICY "orgs_update_owners"
ON "Organizations"
FOR UPDATE
TO authenticated
USING (
    id IN (
        SELECT organization_id 
        FROM "OrganizationUsers" 
        WHERE user_id = auth.uid() 
          AND role = 'owner'
          AND deleted = false
    )
    OR is_super_admin(auth.uid())
)
WITH CHECK (
    id IN (
        SELECT organization_id 
        FROM "OrganizationUsers" 
        WHERE user_id = auth.uid() 
          AND role = 'owner'
          AND deleted = false
    )
    OR is_super_admin(auth.uid())
);

-- Policy 4: Owners can soft-delete their organization  
CREATE POLICY "orgs_delete_owners"
ON "Organizations"
FOR UPDATE
TO authenticated
USING (
    id IN (
        SELECT organization_id 
        FROM "OrganizationUsers" 
        WHERE user_id = auth.uid() 
          AND role = 'owner'
          AND deleted = false
    )
    OR is_super_admin(auth.uid())
);

-- Policy 5: Super Admins can insert organizations
CREATE POLICY "orgs_insert_superadmin"
ON "Organizations"
FOR INSERT
TO authenticated
WITH CHECK (is_super_admin(auth.uid()));

-- ====================================================
-- STEP 6: Verify policies were created
-- ====================================================
SELECT 
  'OrganizationUsers policies' as table_name,
  policyname,
  cmd as command
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'OrganizationUsers'
ORDER BY policyname;

SELECT 
  'Organizations policies' as table_name,
  policyname,
  cmd as command
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'Organizations'
ORDER BY policyname;

-- Verify RLS is enabled
SELECT 
  'RLS Status' as info,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE tablename IN ('Organizations', 'OrganizationUsers')
ORDER BY tablename;

