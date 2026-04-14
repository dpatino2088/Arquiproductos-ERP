-- Split legacy operator into two levels:
-- - operator_admin: can assign/manage manufacturing operations
-- - operator_member: executes assigned work order tasks

INSERT INTO "AppUserRoles" (code, user_type, name, description, is_system, sort_order)
VALUES
  ('operator_admin', 'org', 'Operator Admin (Assign and supervise operations)', 'Leads manufacturing operations, planning, and assignments', true, 31),
  ('operator_member', 'org', 'Operator Member (Execute work orders)', 'Runs assigned workstation and work order tasks', true, 32)
ON CONFLICT (code) DO NOTHING;

INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT r.role_code, p.code
FROM (
  VALUES
    ('operator_admin', 'dashboard.read'),
    ('operator_admin', 'catalog.read'),
    ('operator_admin', 'inventory.read'),
    ('operator_admin', 'manufacturing.read'),
    ('operator_admin', 'manufacturing.write'),
    ('operator_admin', 'manufacturing.mo.read'),
    ('operator_admin', 'manufacturing.mo.write'),
    ('operator_admin', 'manufacturing.wo.read'),
    ('operator_admin', 'manufacturing.wo.write'),
    ('operator_admin', 'manufacturing.workstation.read'),
    ('operator_admin', 'manufacturing.cutopt.read'),
    ('operator_admin', 'manufacturing.calendar.read'),
    ('operator_member', 'dashboard.read'),
    ('operator_member', 'catalog.read'),
    ('operator_member', 'inventory.read'),
    ('operator_member', 'manufacturing.wo.read'),
    ('operator_member', 'manufacturing.wo.write'),
    ('operator_member', 'manufacturing.workstation.read'),
    ('operator_member', 'manufacturing.cutopt.read')
) AS r(role_code, permission_code)
JOIN "Permissions" p ON p.code = r.permission_code
ON CONFLICT DO NOTHING;;
