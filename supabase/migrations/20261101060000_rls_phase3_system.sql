-- RLS Phase 3: system / global tables
-- These tables hold reference data (roles, permissions, role mapping).
-- Reads are allowed to any authenticated user.
-- Writes are intentionally not granted via RLS: only migrations and the
-- service role (which bypasses RLS) may modify them.

-- =========================================================
-- AppUserRoles (system catalog)
-- =========================================================
ALTER TABLE public."AppUserRoles" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_user_roles_select ON public."AppUserRoles";
CREATE POLICY app_user_roles_select
ON public."AppUserRoles"
FOR SELECT
TO authenticated
USING (true);

-- =========================================================
-- AppUserRolePermissions (role -> permission mapping)
-- =========================================================
ALTER TABLE public."AppUserRolePermissions" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_user_role_permissions_select ON public."AppUserRolePermissions";
CREATE POLICY app_user_role_permissions_select
ON public."AppUserRolePermissions"
FOR SELECT
TO authenticated
USING (true);

-- =========================================================
-- CatalogItemRoles (catalog reference, no organization_id)
-- =========================================================
ALTER TABLE public."CatalogItemRoles" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS catalog_item_roles_select ON public."CatalogItemRoles";
CREATE POLICY catalog_item_roles_select
ON public."CatalogItemRoles"
FOR SELECT
TO authenticated
USING (true);

-- =========================================================
-- AppUserPermissions (per-user overrides)
-- The user can read their own; org admins can read/write any user in their org.
-- =========================================================
ALTER TABLE public."AppUserPermissions" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_user_permissions_select ON public."AppUserPermissions";
CREATE POLICY app_user_permissions_select
ON public."AppUserPermissions"
FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public."AppUsers" au
    WHERE au.id = "AppUserPermissions".app_user_id
      AND (
        au.auth_user_id = auth.uid()
        OR is_org_owner_or_admin(au.organization_id)
      )
  )
);

DROP POLICY IF EXISTS app_user_permissions_insert ON public."AppUserPermissions";
CREATE POLICY app_user_permissions_insert
ON public."AppUserPermissions"
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public."AppUsers" au
    WHERE au.id = "AppUserPermissions".app_user_id
      AND is_org_owner_or_admin(au.organization_id)
  )
);

DROP POLICY IF EXISTS app_user_permissions_update ON public."AppUserPermissions";
CREATE POLICY app_user_permissions_update
ON public."AppUserPermissions"
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public."AppUsers" au
    WHERE au.id = "AppUserPermissions".app_user_id
      AND is_org_owner_or_admin(au.organization_id)
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public."AppUsers" au
    WHERE au.id = "AppUserPermissions".app_user_id
      AND is_org_owner_or_admin(au.organization_id)
  )
);

DROP POLICY IF EXISTS app_user_permissions_delete ON public."AppUserPermissions";
CREATE POLICY app_user_permissions_delete
ON public."AppUserPermissions"
FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM public."AppUsers" au
    WHERE au.id = "AppUserPermissions".app_user_id
      AND is_org_owner_or_admin(au.organization_id)
  )
);

NOTIFY pgrst, 'reload schema';
