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
      'directory.customers.read',
      'directory.customers.write',
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
      'directory.customers.write',
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
      'directory.contacts.read',
      'directory.contacts.write',
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
      'directory.contacts.write',
      'directory.write',
      'directory.edit',
      'directory.create'
    ]::text[]
  );
$$;

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
GRANT EXECUTE ON FUNCTION public.can_write_directory_contacts_org(uuid) TO authenticated;;
