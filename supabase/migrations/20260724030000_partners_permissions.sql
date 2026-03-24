-- Create missing partners.* permission codes and assign them to roles.
-- The Permissions table had no partners.* entries, causing the sidebar
-- to never show Partners for internal users (can() always returned false).

INSERT INTO public."Permissions" (code, module, description)
VALUES
  ('partners.read',  'partners', 'View dealers, vendors, manufacturers'),
  ('partners.write', 'partners', 'Create and edit dealers, vendors, manufacturers')
ON CONFLICT (code) DO NOTHING;

-- Grant to roles that need Partners access
INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
SELECT r.role_code, p.code
FROM (VALUES
  ('superadmin'), ('admin'), ('member'),
  ('sales_coordinator'), ('finance'), ('procurement')
) AS r(role_code)
CROSS JOIN (VALUES ('partners.read'), ('partners.write')) AS p(code)
ON CONFLICT (role_code, permission_code) DO NOTHING;

-- procurement only gets partners.read (view-only access to vendors)
DELETE FROM public."AppUserRolePermissions"
WHERE role_code = 'procurement' AND permission_code = 'partners.write';
