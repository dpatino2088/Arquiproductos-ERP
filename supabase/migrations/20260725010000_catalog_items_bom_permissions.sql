-- Split Catalog permissions into Items and BOM submodules.
-- Goal: Roles UI can manage Catalog > Items and Catalog > BOM independently.

-- 1) Create new permission codes under module=catalog
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
SET
  module = EXCLUDED.module,
  description = EXCLUDED.description;

-- 2) Backfill Items permissions from existing Catalog permissions
-- Read: anyone with catalog.read or catalog.write can view Items
INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT DISTINCT rp.role_code, 'catalog.items.read'
FROM "AppUserRolePermissions" rp
WHERE rp.permission_code IN ('catalog.read', 'catalog.write')
ON CONFLICT DO NOTHING;

-- Write-level
INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT DISTINCT rp.role_code, 'catalog.items.write'
FROM "AppUserRolePermissions" rp
WHERE rp.permission_code = 'catalog.write'
ON CONFLICT DO NOTHING;

-- Action-level for Items
INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT DISTINCT rp.role_code, 'catalog.items.create'
FROM "AppUserRolePermissions" rp
WHERE rp.permission_code IN ('catalog.create', 'catalog.write')
ON CONFLICT DO NOTHING;

INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT DISTINCT rp.role_code, 'catalog.items.edit'
FROM "AppUserRolePermissions" rp
WHERE rp.permission_code IN ('catalog.edit', 'catalog.write')
ON CONFLICT DO NOTHING;

INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT DISTINCT rp.role_code, 'catalog.items.archive'
FROM "AppUserRolePermissions" rp
WHERE rp.permission_code IN ('catalog.archive', 'catalog.write')
ON CONFLICT DO NOTHING;

INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT DISTINCT rp.role_code, 'catalog.items.delete'
FROM "AppUserRolePermissions" rp
WHERE rp.permission_code IN ('catalog.delete', 'catalog.write')
ON CONFLICT DO NOTHING;

-- 3) Backfill BOM permissions from catalog.write (legacy BOM access behavior)
INSERT INTO "AppUserRolePermissions" (role_code, permission_code)
SELECT DISTINCT rp.role_code, bom_perm.permission_code
FROM "AppUserRolePermissions" rp
CROSS JOIN (
  VALUES
    ('catalog.bom.read'),
    ('catalog.bom.write'),
    ('catalog.bom.create'),
    ('catalog.bom.edit'),
    ('catalog.bom.archive'),
    ('catalog.bom.delete')
) AS bom_perm(permission_code)
WHERE rp.permission_code = 'catalog.write'
ON CONFLICT DO NOTHING;

-- 4) Guardrail: procurement must only see Items in Catalog (no BOM)
DELETE FROM "AppUserRolePermissions"
WHERE role_code = 'procurement'
  AND permission_code IN (
    'catalog.bom.read',
    'catalog.bom.write',
    'catalog.bom.create',
    'catalog.bom.edit',
    'catalog.bom.archive',
    'catalog.bom.delete'
  );
