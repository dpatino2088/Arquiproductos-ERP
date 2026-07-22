-- Let both operator profiles (operator_admin, operator_member) VIEW Purchase
-- Orders. Operators receive goods against POs, so they need read access to the
-- Purchase Orders section (and related receipt context). Purchasing itself
-- (create/edit POs) stays with procurement/admin, so only the *.read grant is
-- added here — never *.write.

INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT r.role_code, p.code
FROM (
  VALUES
    ('operator_admin',  'inventory.purchase_orders.read'),
    ('operator_member', 'inventory.purchase_orders.read')
) AS r(role_code, permission_code)
JOIN "Permissions" p ON p.code = r.permission_code
ON CONFLICT DO NOTHING;
