-- Keep admin/superadmin fully permission-driven without UI bypasses.
-- This migration guarantees both roles always have all permission codes.

INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
SELECT r.role_code, p.code
FROM (VALUES ('admin'::text), ('superadmin'::text)) AS r(role_code)
CROSS JOIN public."Permissions" p
ON CONFLICT (role_code, permission_code) DO NOTHING;
