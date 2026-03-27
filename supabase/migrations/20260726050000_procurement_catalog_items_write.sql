-- Create granular catalog.items.* and catalog.bom.* permissions in Permissions table,
-- backfill existing roles, and grant procurement edit + create access on Items.

-- 1. Create granular catalog permission codes
INSERT INTO "Permissions" (code, module, description)
VALUES
  ('catalog.items.read',    'catalog', 'View Catalog Items'),
  ('catalog.items.write',   'catalog', 'Edit Catalog Items'),
  ('catalog.items.create',  'catalog', 'Create Catalog Items'),
  ('catalog.items.edit',    'catalog', 'Edit Catalog Items'),
  ('catalog.items.archive', 'catalog', 'Archive Catalog Items'),
  ('catalog.items.delete',  'catalog', 'Delete Catalog Items'),
  ('catalog.bom.read',      'catalog', 'View BOM Templates'),
  ('catalog.bom.write',     'catalog', 'Edit BOM Templates'),
  ('catalog.bom.create',    'catalog', 'Create BOM Templates'),
  ('catalog.bom.edit',      'catalog', 'Edit BOM Templates'),
  ('catalog.bom.archive',   'catalog', 'Archive BOM Templates'),
  ('catalog.bom.delete',    'catalog', 'Delete BOM Templates')
ON CONFLICT (code) DO UPDATE
SET module = EXCLUDED.module, description = EXCLUDED.description;

-- 2. Backfill items.read for all roles that already have catalog.read or catalog.write
INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT DISTINCT rp.role_code, 'catalog.items.read'
FROM "AppUserRolePermissions" rp
WHERE rp.permission_code IN ('catalog.read', 'catalog.write')
ON CONFLICT DO NOTHING;

-- 3. Backfill items.write/create/edit for roles that have catalog.write
INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT DISTINCT rp.role_code, perm
FROM "AppUserRolePermissions" rp
CROSS JOIN (VALUES ('catalog.items.write'),('catalog.items.create'),('catalog.items.edit')) AS t(perm)
WHERE rp.permission_code = 'catalog.write'
ON CONFLICT DO NOTHING;

-- 4. Backfill bom permissions for roles that have catalog.write
INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT DISTINCT rp.role_code, perm
FROM "AppUserRolePermissions" rp
CROSS JOIN (VALUES
  ('catalog.bom.read'),('catalog.bom.write'),('catalog.bom.create'),
  ('catalog.bom.edit'),('catalog.bom.archive'),('catalog.bom.delete')
) AS t(perm)
WHERE rp.permission_code = 'catalog.write'
ON CONFLICT DO NOTHING;

-- 5. Guardrail: procurement must NOT see BOM
DELETE FROM "AppUserRolePermissions"
WHERE role_code = 'procurement'
  AND permission_code IN (
    'catalog.bom.read','catalog.bom.write','catalog.bom.create',
    'catalog.bom.edit','catalog.bom.archive','catalog.bom.delete'
  );

-- 6. Grant procurement: items read + write + create
INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
VALUES
  ('procurement', 'catalog.items.read'),
  ('procurement', 'catalog.items.write'),
  ('procurement', 'catalog.items.create')
ON CONFLICT DO NOTHING;
