INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
SELECT r.role_code, p.code
FROM (VALUES ('admin'::text), ('superadmin'::text)) AS r(role_code)
CROSS JOIN public."Permissions" p
ON CONFLICT (role_code, permission_code) DO NOTHING;;
