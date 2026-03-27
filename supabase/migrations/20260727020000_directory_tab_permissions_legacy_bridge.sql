-- Bridge migration: allow legacy Directory permission codes to satisfy
-- strict tab-level helpers used by Directory Customers/Contacts RLS.
-- This prevents false negatives for roles that still carry:
-- directory.read / directory.write / directory.create / directory.edit.

SET search_path = public;

CREATE OR REPLACE FUNCTION public.can_read_directory_customers_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      -- strict tab codes
      'directory.customers.read',
      'directory.customers.write',
      -- legacy bridge
      'directory.read',
      'directory.write',
      'directory.create',
      'directory.edit'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_directory_customers_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      -- strict tab code
      'directory.customers.write',
      -- legacy bridge
      'directory.write',
      'directory.edit',
      'directory.create'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_read_directory_contacts_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      -- strict tab codes
      'directory.contacts.read',
      'directory.contacts.write',
      -- legacy bridge
      'directory.read',
      'directory.write',
      'directory.create',
      'directory.edit'
    ]::text[]
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_directory_contacts_org(p_org_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.user_has_org_permission(
    p_org_id,
    ARRAY[
      -- strict tab code
      'directory.contacts.write',
      -- legacy bridge
      'directory.write',
      'directory.edit',
      'directory.create'
    ]::text[]
  );
$$;

-- Backfill tab-level Directory permissions from legacy module-level grants
-- so role editors and strict checks stay aligned going forward.
INSERT INTO public."AppUserRolePermissions"(role_code, permission_code)
SELECT DISTINCT rp.role_code, tab.permission_code
FROM public."AppUserRolePermissions" rp
JOIN (
  VALUES
    ('directory.customers.read'),
    ('directory.customers.write'),
    ('directory.contacts.read'),
    ('directory.contacts.write')
) AS tab(permission_code) ON TRUE
WHERE rp.permission_code IN (
  'directory.read',
  'directory.write',
  'directory.create',
  'directory.edit'
)
ON CONFLICT (role_code, permission_code) DO NOTHING;

GRANT EXECUTE ON FUNCTION public.can_read_directory_customers_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_directory_customers_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_read_directory_contacts_org(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_write_directory_contacts_org(uuid) TO authenticated;

