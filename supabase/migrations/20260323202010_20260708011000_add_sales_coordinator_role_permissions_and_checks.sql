-- Add Sales Coordinator role in org checks and role permissions.

ALTER TABLE "OrganizationUsers"
  DROP CONSTRAINT IF EXISTS organizationusers_role_check;

ALTER TABLE "OrganizationUsers"
  ADD CONSTRAINT organizationusers_role_check
  CHECK (
    role IN (
      'owner',
      'admin',
      'member',
      'viewer',
      'superadmin',
      'sales_coordinator',
      'operator',
      'operator_admin',
      'operator_member',
      'procurement',
      'finance'
    )
  );

INSERT INTO "AppUserRoles" (code, user_type, name, description, is_system, sort_order)
VALUES
  (
    'sales_coordinator',
    'org',
    'Sales Coordinator (Quotes, proposals, and order follow-up)',
    'Coordinates sales flow from quote to order with customer follow-up',
    true,
    30
  )
ON CONFLICT (code) DO NOTHING;

INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT r.role_code, p.code
FROM (
  VALUES
    ('sales_coordinator', 'dashboard.read'),
    ('sales_coordinator', 'directory.read'),
    ('sales_coordinator', 'directory.write'),
    ('sales_coordinator', 'catalog.read'),
    ('sales_coordinator', 'inventory.read'),
    ('sales_coordinator', 'sales.read'),
    ('sales_coordinator', 'sales.write'),
    ('sales_coordinator', 'quotes.edit'),
    ('sales_coordinator', 'salesorders.edit'),
    ('sales_coordinator', 'manufacturing.read')
) AS r(role_code, permission_code)
JOIN "Permissions" p ON p.code = r.permission_code
ON CONFLICT DO NOTHING;;
