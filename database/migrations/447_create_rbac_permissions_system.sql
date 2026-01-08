-- ====================================================
-- Migration: Create RBAC Permissions System
-- ====================================================
-- OBJETIVO: Sistema de permisos escalable por módulo
-- Separación clara: Roles (jerarquía) vs Permissions (capacidad)
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Create Permissions table
-- ====================================================
CREATE TABLE IF NOT EXISTS public."Permissions" (
  code text PRIMARY KEY,
  module text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public."Permissions" IS 'Defines all available permissions in the system, organized by module';

-- ====================================================
-- STEP 2: Create OrganizationUserPermissions table
-- ====================================================
CREATE TABLE IF NOT EXISTS public."OrganizationUserPermissions" (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_user_id uuid NOT NULL REFERENCES public."OrganizationUsers"(id) ON DELETE CASCADE,
  permission_code text NOT NULL REFERENCES public."Permissions"(code) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (organization_user_id, permission_code)
);

CREATE INDEX IF NOT EXISTS idx_org_user_permissions_user_id 
ON public."OrganizationUserPermissions"(organization_user_id);

CREATE INDEX IF NOT EXISTS idx_org_user_permissions_code 
ON public."OrganizationUserPermissions"(permission_code);

COMMENT ON TABLE public."OrganizationUserPermissions" IS 'Assigns specific permissions to organization users';

-- ====================================================
-- STEP 3: Enable RLS
-- ====================================================
ALTER TABLE public."Permissions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."OrganizationUserPermissions" ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Permissions (read-only for authenticated users)
CREATE POLICY "authenticated_can_read_permissions"
ON public."Permissions" FOR SELECT
TO authenticated
USING (true);

-- RLS Policies for OrganizationUserPermissions
-- Users can read their own permissions
CREATE POLICY "users_can_read_own_permissions"
ON public."OrganizationUserPermissions" FOR SELECT
TO authenticated
USING (
  organization_user_id IN (
    SELECT id FROM public."OrganizationUsers"
    WHERE user_id = auth.uid()
      AND deleted = false
  )
);

-- Admins can read all permissions in their organization
CREATE POLICY "admins_can_read_org_permissions"
ON public."OrganizationUserPermissions" FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public."OrganizationUsers" ou
    WHERE ou.id = "OrganizationUserPermissions".organization_user_id
      AND ou.organization_id IN (
        SELECT organization_id FROM public."OrganizationUsers"
        WHERE user_id = auth.uid()
          AND role IN ('superadmin', 'admin')
          AND deleted = false
      )
  )
);

-- Only admins can modify permissions
CREATE POLICY "admins_can_modify_permissions"
ON public."OrganizationUserPermissions"
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public."OrganizationUsers"
    WHERE user_id = auth.uid()
      AND role IN ('superadmin', 'admin')
      AND deleted = false
      AND organization_id = (
        SELECT organization_id FROM public."OrganizationUsers"
        WHERE id = "OrganizationUserPermissions".organization_user_id
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public."OrganizationUsers"
    WHERE user_id = auth.uid()
      AND role IN ('superadmin', 'admin')
      AND deleted = false
      AND organization_id = (
        SELECT organization_id FROM public."OrganizationUsers"
        WHERE id = "OrganizationUserPermissions".organization_user_id
      )
  )
);

-- ====================================================
-- STEP 4: Create RPC function to check permissions
-- ====================================================
CREATE OR REPLACE FUNCTION public.has_permission(
  p_permission_code text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_org_user_id uuid;
  v_role text;
  v_has_permission boolean := false;
BEGIN
  -- Get current user ID
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN false;
  END IF;

  -- Get organization user and role
  SELECT id, role INTO v_org_user_id, v_role
  FROM public."OrganizationUsers"
  WHERE user_id = v_user_id
    AND deleted = false
  LIMIT 1;

  IF v_org_user_id IS NULL THEN
    RETURN false;
  END IF;

  -- Superadmin always has all permissions
  IF v_role = 'superadmin' THEN
    RETURN true;
  END IF;

  -- Check if user has the specific permission
  SELECT EXISTS (
    SELECT 1
    FROM public."OrganizationUserPermissions"
    WHERE organization_user_id = v_org_user_id
      AND permission_code = p_permission_code
  ) INTO v_has_permission;

  RETURN v_has_permission;
END;
$$;

COMMENT ON FUNCTION public.has_permission(text) IS 
  'Checks if the current authenticated user has a specific permission. Superadmins always return true.';

-- ====================================================
-- STEP 5: Grant execute permissions
-- ====================================================
GRANT EXECUTE ON FUNCTION public.has_permission(text) TO anon;
GRANT EXECUTE ON FUNCTION public.has_permission(text) TO authenticated;

-- ====================================================
-- STEP 6: Seed Permissions
-- ====================================================
INSERT INTO public."Permissions" (code, module, description) VALUES
  -- Directory
  ('directory.read', 'directory', 'Read directory (customers, contacts, vendors)'),
  ('directory.write', 'directory', 'Create/edit/delete directory entries'),
  
  -- Catalog
  ('catalog.read', 'catalog', 'Read catalog items and BOM templates'),
  ('catalog.write', 'catalog', 'Create/edit/delete catalog items and BOM templates'),
  
  -- Quotes
  ('quotes.read', 'sales', 'Read quotes'),
  ('quotes.write', 'sales', 'Create/edit/delete quotes'),
  
  -- Sales Orders
  ('sales_orders.read', 'sales', 'Read sales orders'),
  ('sales_orders.write', 'sales', 'Create/edit/delete sales orders'),
  
  -- Manufacturing
  ('manufacturing.read', 'manufacturing', 'Read manufacturing orders'),
  ('manufacturing.write', 'manufacturing', 'Create/edit/delete manufacturing orders'),
  
  -- Purchasing
  ('purchasing.read', 'purchasing', 'Read purchase orders'),
  ('purchasing.write', 'purchasing', 'Create/edit/delete purchase orders'),
  
  -- Inventory
  ('inventory.read', 'inventory', 'Read inventory levels and movements'),
  ('inventory.write', 'inventory', 'Create/edit inventory movements'),
  
  -- Financials
  ('financials.read', 'financials', 'Read financial reports and data'),
  ('financials.write', 'financials', 'Create/edit financial transactions'),
  
  -- Reports
  ('reports.read', 'reports', 'Access reports module'),
  
  -- Settings
  ('settings.read', 'settings', 'Read organization settings'),
  ('settings.write', 'settings', 'Modify organization settings, users, and permissions')
ON CONFLICT (code) DO NOTHING;

-- ====================================================
-- STEP 7: Notify PostgREST to reload schema
-- ====================================================
NOTIFY pgrst, 'reload schema';

COMMIT;

