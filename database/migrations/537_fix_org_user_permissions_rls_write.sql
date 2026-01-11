-- ============================================================
-- Migration: Fix OrganizationUserPermissions RLS for INSERT/UPDATE/DELETE
-- ============================================================
-- OBJETIVO:
-- 1) Crear políticas INSERT/UPDATE/DELETE no recursivas para OrganizationUserPermissions
-- 2) Permitir a superadmin/admin gestionar permisos de usuarios en su organización
-- 3) Usar funciones helper existentes para evitar recursión
-- ============================================================

BEGIN;

-- ============================================================
-- 1) Actualizar is_org_user_superadmin para incluir 'admin'
-- ============================================================
-- La función ya existe de la migración 534, pero necesitamos asegurarnos
-- de que incluya 'admin' además de 'superadmin'/'owner'
-- Si la función ya incluye admin, esto es idempotente

CREATE OR REPLACE FUNCTION public.is_org_user_superadmin(p_org_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public."OrganizationUsers" ou
    WHERE ou.organization_id = p_org_id
      AND ou.user_id = auth.uid()
      AND ou.role IN ('superadmin', 'admin', 'owner')
      AND ou.deleted = false
      AND ou.status IN ('active', 'invited')
  );
END;
$$;

COMMENT ON FUNCTION public.is_org_user_superadmin(uuid) IS 
  'Returns true if current user is superadmin/admin/owner in the organization. Used for RLS policies that allow full access.';

-- Grant execute permissions (idempotent)
GRANT EXECUTE ON FUNCTION public.is_org_user_superadmin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_org_user_superadmin(uuid) TO anon;

-- ============================================================
-- 2) Drop existing write policies (if they exist and are recursive)
-- ============================================================
DROP POLICY IF EXISTS "admins_can_modify_permissions" ON public."OrganizationUserPermissions";

-- ============================================================
-- 3) CREATE NON-RECURSIVE write policies using helper functions
-- ============================================================

-- INSERT: Superadmin/Admin can insert permissions for users in their organization
CREATE POLICY orguserperms_insert_admin
  ON public."OrganizationUserPermissions"
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."OrganizationUsers" target_ou
      WHERE target_ou.id = organization_user_id
        AND target_ou.deleted = false
        AND public.is_org_user_superadmin(target_ou.organization_id)
    )
  );

-- UPDATE: Superadmin/Admin can update permissions for users in their organization
CREATE POLICY orguserperms_update_admin
  ON public."OrganizationUserPermissions"
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public."OrganizationUsers" target_ou
      WHERE target_ou.id = organization_user_id
        AND target_ou.deleted = false
        AND public.is_org_user_superadmin(target_ou.organization_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public."OrganizationUsers" target_ou
      WHERE target_ou.id = organization_user_id
        AND target_ou.deleted = false
        AND public.is_org_user_superadmin(target_ou.organization_id)
    )
  );

-- DELETE: Superadmin/Admin can delete permissions for users in their organization
CREATE POLICY orguserperms_delete_admin
  ON public."OrganizationUserPermissions"
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM public."OrganizationUsers" target_ou
      WHERE target_ou.id = organization_user_id
        AND target_ou.deleted = false
        AND public.is_org_user_superadmin(target_ou.organization_id)
    )
  );

COMMENT ON POLICY orguserperms_insert_admin ON public."OrganizationUserPermissions" IS 
  'Superadmin/Admin can insert permissions for users in their organization. Uses non-recursive helper function.';

COMMENT ON POLICY orguserperms_update_admin ON public."OrganizationUserPermissions" IS 
  'Superadmin/Admin can update permissions for users in their organization. Uses non-recursive helper function.';

COMMENT ON POLICY orguserperms_delete_admin ON public."OrganizationUserPermissions" IS 
  'Superadmin/Admin can delete permissions for users in their organization. Uses non-recursive helper function.';

COMMIT;

-- ============================================================
-- NOTAS:
-- - Las políticas usan is_org_user_superadmin() que es SECURITY DEFINER
--   y no recursivo porque hace un SELECT directo sin subqueries a RLS
-- - Superadmin y Admin (incluyendo 'owner' mapeado a superadmin) pueden gestionar permisos
-- - La función verifica que el usuario actual sea superadmin/admin de la misma organización
--   que el usuario objetivo (target_ou.organization_id)
-- ============================================================
