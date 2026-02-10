-- Dealer roles permissions: dealer_member y dealer_manager
-- ==========================================================
-- OBJETIVO: dealer_member y dealer_manager tengan directory.read, directory.write,
-- sales.read, sales.write, quotes.edit; dealer_manager además quotes.approve y quotes.manage.
-- Tablas: public.Permissions (columna "code"), public.AppUserRolePermissions (role_code, permission_code).
-- Requisito: los códigos dealer_member y dealer_manager deben existir en public.AppUserRoles (FK).
-- No tocar RLS ni triggers.
-- ==========================================================

-- 1) Crear permisos faltantes en public.Permissions (solo si no existen)
INSERT INTO public."Permissions" (code, module, description)
VALUES
  ('directory.read',  'directory', 'Read directory'),
  ('directory.write', 'directory', 'Create and edit directory records'),
  ('sales.read',      'sales',     'Read sales data'),
  ('sales.write',     'sales',     'Create sales records'),
  ('quotes.edit',     'sales',     'Create and edit quotes'),
  ('quotes.approve',  'sales',     'Approve quotes'),
  ('quotes.manage',  'sales',     'Manage all dealer quotes')
ON CONFLICT (code) DO NOTHING;

-- 2) Asignar permisos a dealer_member
INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
VALUES
  ('dealer_member', 'directory.read'),
  ('dealer_member', 'directory.write'),
  ('dealer_member', 'sales.read'),
  ('dealer_member', 'sales.write'),
  ('dealer_member', 'quotes.edit')
ON CONFLICT (role_code, permission_code) DO NOTHING;

-- 3) Asignar permisos a dealer_manager (todo lo de dealer_member + approve + manage)
INSERT INTO public."AppUserRolePermissions" (role_code, permission_code)
VALUES
  ('dealer_manager', 'directory.read'),
  ('dealer_manager', 'directory.write'),
  ('dealer_manager', 'sales.read'),
  ('dealer_manager', 'sales.write'),
  ('dealer_manager', 'quotes.edit'),
  ('dealer_manager', 'quotes.approve'),
  ('dealer_manager', 'quotes.manage')
ON CONFLICT (role_code, permission_code) DO NOTHING;

-- 4) Verificación (opcional: comentar en producción)
-- SELECT role_code, permission_code
-- FROM public."AppUserRolePermissions"
-- WHERE role_code IN ('dealer_member', 'dealer_manager')
-- ORDER BY role_code, permission_code;
