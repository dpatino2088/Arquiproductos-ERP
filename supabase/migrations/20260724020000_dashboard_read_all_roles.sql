-- Grant dashboard.read to all internal roles that don't have it yet.
-- Each role will see a role-specific dashboard (procurement, operator, finance views).

INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
SELECT r.role_code, 'dashboard.read'
FROM (VALUES
  ('procurement'),
  ('operator'),
  ('operator_admin'),
  ('operator_member'),
  ('finance'),
  ('viewer')
) AS r(role_code)
ON CONFLICT (role_code, permission_code) DO NOTHING;
