-- =====================================================
-- Inventory RBAC: add inventory.read and inventory.write
-- =====================================================
-- 1) Insert permissions into public.Permissions (same table/pattern as 511).
-- 2) Assign inventory.read and inventory.write to existing org users with
--    role in ('superadmin', 'admin').
-- 3) Assign inventory.read to role 'procurement' and 'operator' so they
--    see the module; procurement also gets inventory.write.
-- =====================================================

SET search_path = public;

-- 1) Ensure permissions exist (idempotent)
INSERT INTO public."Permissions" (code, module, description)
VALUES
  ('inventory.read', 'inventory', 'View inventory (warehouses, stock, availability)'),
  ('inventory.write', 'inventory', 'Create/edit inventory (warehouses, POs, adjustments)')
ON CONFLICT (code) DO NOTHING;

-- 2) Assign to superadmin and admin (full access)
INSERT INTO public."OrganizationUserPermissions" (organization_user_id, permission_code)
SELECT ou.id, p.code
FROM public."OrganizationUsers" ou
CROSS JOIN public."Permissions" p
WHERE p.code IN ('inventory.read', 'inventory.write')
  AND ou.role IN ('superadmin', 'admin')
  AND ou.deleted = false
ON CONFLICT (organization_user_id, permission_code) DO NOTHING;

-- 3) Assign inventory.read to operator and procurement; inventory.write to procurement only
INSERT INTO public."OrganizationUserPermissions" (organization_user_id, permission_code)
SELECT ou.id, 'inventory.read'
FROM public."OrganizationUsers" ou
WHERE ou.role IN ('operator', 'procurement')
  AND ou.deleted = false
ON CONFLICT (organization_user_id, permission_code) DO NOTHING;

INSERT INTO public."OrganizationUserPermissions" (organization_user_id, permission_code)
SELECT ou.id, 'inventory.write'
FROM public."OrganizationUsers" ou
WHERE ou.role = 'procurement'
  AND ou.deleted = false
ON CONFLICT (organization_user_id, permission_code) DO NOTHING;
