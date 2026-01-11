-- ====================================================
-- Migration: Create base RBAC Permissions system
-- ====================================================
-- OBJETIVO: Crear tablas Permissions y OrganizationUserPermissions
-- ====================================================

BEGIN;

-- Create Permissions table
CREATE TABLE IF NOT EXISTS public."Permissions" (
    code text PRIMARY KEY,
    module text NOT NULL,
    description text
);

-- Create OrganizationUserPermissions junction table
CREATE TABLE IF NOT EXISTS public."OrganizationUserPermissions" (
    organization_user_id uuid NOT NULL REFERENCES public."OrganizationUsers"(id) ON DELETE CASCADE,
    permission_code text NOT NULL REFERENCES public."Permissions"(code) ON DELETE CASCADE,
    PRIMARY KEY (organization_user_id, permission_code)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_permissions_module ON public."Permissions"(module);
CREATE INDEX IF NOT EXISTS idx_org_user_permissions_user_id ON public."OrganizationUserPermissions"(organization_user_id);
CREATE INDEX IF NOT EXISTS idx_org_user_permissions_code ON public."OrganizationUserPermissions"(permission_code);

-- Add comments
COMMENT ON TABLE public."Permissions" IS 'RBAC Permissions - available permissions with module grouping';
COMMENT ON TABLE public."OrganizationUserPermissions" IS 'Junction table linking OrganizationUsers to Permissions';

-- Enable RLS
ALTER TABLE public."Permissions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."OrganizationUserPermissions" ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Permissions (read-only for authenticated users)
DROP POLICY IF EXISTS "Authenticated users can read permissions" ON public."Permissions";
CREATE POLICY "Authenticated users can read permissions"
    ON public."Permissions"
    FOR SELECT
    TO authenticated
    USING (true);

-- RLS Policies for OrganizationUserPermissions
-- Users can read permissions for users in their organizations
DROP POLICY IF EXISTS "Users can read own organization permissions" ON public."OrganizationUserPermissions";
CREATE POLICY "Users can read own organization permissions"
    ON public."OrganizationUserPermissions"
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.id = "OrganizationUserPermissions".organization_user_id
            AND EXISTS (
                SELECT 1 FROM public."OrganizationUsers" ou2
                WHERE ou2.organization_id = ou.organization_id
                AND ou2.user_id = auth.uid()
                AND ou2.deleted = false
                AND ou2.status = 'active'
            )
        )
    );

-- Only owners and admins can manage permissions
DROP POLICY IF EXISTS "Owners and admins can manage permissions" ON public."OrganizationUserPermissions";
CREATE POLICY "Owners and admins can manage permissions"
    ON public."OrganizationUserPermissions"
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public."OrganizationUsers" ou
            WHERE ou.id = "OrganizationUserPermissions".organization_user_id
            AND EXISTS (
                SELECT 1 FROM public."OrganizationUsers" ou2
                WHERE ou2.organization_id = ou.organization_id
                AND ou2.user_id = auth.uid()
                AND ou2.role IN ('owner', 'admin')
                AND ou2.deleted = false
                AND ou2.status = 'active'
            )
        )
    );

COMMIT;
