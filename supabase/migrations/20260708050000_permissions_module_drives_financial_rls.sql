-- Centralized permission evaluator for org scope.
-- Purpose: when a permission is granted in Permissions module
-- (OrganizationUserPermissions), RLS should honor it without per-user policy edits.

CREATE OR REPLACE FUNCTION public.user_has_org_permission(
  p_org_id uuid,
  p_permission_codes text[]
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    -- AppUsers role-based permissions
    EXISTS (
      SELECT 1
      FROM public."AppUsers" au
      WHERE au.auth_user_id = auth.uid()
        AND au.organization_id = p_org_id
        AND COALESCE(au.deleted, false) = false
        AND (
          au.role_code = 'superadmin'
          OR EXISTS (
            SELECT 1
            FROM public."AppUserRolePermissions" arp
            WHERE arp.role_code = au.role_code
              AND arp.permission_code = ANY (p_permission_codes)
          )
        )
    )
    OR
    -- OrganizationUsers explicit permissions from Permissions module
    EXISTS (
      SELECT 1
      FROM public."OrganizationUsers" ou
      JOIN public."OrganizationUserPermissions" oup
        ON oup.organization_user_id = ou.id
      WHERE ou.organization_id = p_org_id
        AND ou.user_id = auth.uid()
        AND COALESCE(ou.deleted, false) = false
        AND oup.permission_code = ANY (p_permission_codes)
    )
    OR
    -- Safety fallback for org superadmin on OrganizationUsers model
    EXISTS (
      SELECT 1
      FROM public."OrganizationUsers" ou
      WHERE ou.organization_id = p_org_id
        AND ou.user_id = auth.uid()
        AND COALESCE(ou.deleted, false) = false
        AND ou.role::text = 'superadmin'
    );
$$;

GRANT EXECUTE ON FUNCTION public.user_has_org_permission(uuid, text[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.can_write_financials_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      'financials.invoices.create',
      'financials.create',
      'financials.write'
    ]::text[]
  );
$$;

GRANT EXECUTE ON FUNCTION public.can_write_financials_org(uuid) TO authenticated;
