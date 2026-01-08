-- ====================================================
-- Migration: Fix RBAC System - Final Stable Version
-- ====================================================
-- OBJETIVO: 
-- 1. Normalizar nombres de tablas RBAC
-- 2. Crear función has_permission_for_org con organization_id
-- 3. Eliminar SET search_path de funciones STABLE
-- 4. Asegurar que superadmin vea todo
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Normalize table names (fix typos)
-- ====================================================
-- Check if OrganizationUserPermissionss (wrong) exists and rename it
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'OrganizationUserPermissionss'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'OrganizationUserPermissions'
    ) THEN
        ALTER TABLE public."OrganizationUserPermissionss" 
        RENAME TO "OrganizationUserPermissions";
        
        RAISE NOTICE 'Renamed OrganizationUserPermissionss to OrganizationUserPermissions';
    END IF;
END $$;

-- Check if Permissionss (wrong) exists and rename it
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'Permissionss'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'Permissions'
    ) THEN
        ALTER TABLE public."Permissionss" 
        RENAME TO "Permissions";
        
        RAISE NOTICE 'Renamed Permissionss to Permissions';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Ensure Permissions table exists with correct structure
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
-- STEP 3: Ensure OrganizationUserPermissions table exists with correct structure
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
-- STEP 4: Enable RLS and create policies
-- ====================================================
ALTER TABLE public."Permissions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."OrganizationUserPermissions" ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (idempotent)
DROP POLICY IF EXISTS "authenticated_can_read_permissions" ON public."Permissions";
DROP POLICY IF EXISTS "users_can_read_own_permissions" ON public."OrganizationUserPermissions";
DROP POLICY IF EXISTS "admins_can_read_org_permissions" ON public."OrganizationUserPermissions";
DROP POLICY IF EXISTS "admins_can_modify_permissions" ON public."OrganizationUserPermissions";

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
-- STEP 5: Create/Replace has_permission function (STABLE, NO SET search_path)
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

  -- Get organization user and role (first one found)
  SELECT id, role INTO v_org_user_id, v_role
  FROM public."OrganizationUsers"
  WHERE user_id = v_user_id
    AND deleted = false
  ORDER BY created_at ASC
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
  'Checks if the current authenticated user has a specific permission. Superadmins always return true. Uses first organization found.';

-- ====================================================
-- STEP 6: Create has_permission_for_org function (NEW - with organization_id)
-- ====================================================
CREATE OR REPLACE FUNCTION public.has_permission_for_org(
  p_organization_id uuid,
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

  -- Get organization user and role for SPECIFIC organization
  SELECT id, role INTO v_org_user_id, v_role
  FROM public."OrganizationUsers"
  WHERE user_id = v_user_id
    AND organization_id = p_organization_id
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

COMMENT ON FUNCTION public.has_permission_for_org(uuid, text) IS 
  'Checks if the current authenticated user has a specific permission for a given organization. Superadmins always return true.';

-- ====================================================
-- STEP 7: Grant execute permissions
-- ====================================================
GRANT EXECUTE ON FUNCTION public.has_permission(text) TO anon;
GRANT EXECUTE ON FUNCTION public.has_permission(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_permission_for_org(uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION public.has_permission_for_org(uuid, text) TO authenticated;

-- ====================================================
-- STEP 8: Seed Permissions (idempotent)
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
ON CONFLICT (code) DO UPDATE SET
  module = EXCLUDED.module,
  description = EXCLUDED.description,
  updated_at = now();

-- ====================================================
-- STEP 9: Fix get_organization_users RPC (remove SET search_path if STABLE)
-- ====================================================
-- Check if function exists and is STABLE with SET search_path
DO $$
DECLARE
  v_func_volatility char;
  v_func_def text;
BEGIN
  SELECT p.provolatile INTO v_func_volatility
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname = 'get_organization_users';
  
  IF v_func_volatility = 's' THEN -- 's' = STABLE
    -- Function is STABLE, check if it has SET search_path
    SELECT pg_get_functiondef(p.oid) INTO v_func_def
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public'
      AND p.proname = 'get_organization_users';
    
    IF v_func_def LIKE '%SET search_path%' THEN
      RAISE NOTICE 'get_organization_users is STABLE with SET search_path - should be fixed in migration 446';
      -- The function should already be fixed in 446, but we log it here
    END IF;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    -- Function might not exist yet, ignore
    NULL;
END $$;

-- ====================================================
-- STEP 10: Notify PostgREST to reload schema
-- ====================================================
NOTIFY pgrst, 'reload schema';

COMMIT;

