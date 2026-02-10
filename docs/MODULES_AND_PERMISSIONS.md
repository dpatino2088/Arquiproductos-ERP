# Módulos vs Permissions (RBAC)

## En la base de datos

- **`public.Permissions`**: tabla de permisos disponibles.
  - `code` (PK): identificador del permiso, p. ej. `directory.read`, `inventory.write`.
  - `module`: agrupación para la UI; suele coincidir con la primera parte de `code` (p. ej. `directory`, `inventory`).
  - `description`: texto para mostrar en la UI.

- **`public.OrganizationUserPermissions`**: relación N:N entre **OrganizationUsers** (usuarios internal) y **Permissions**.
  - Solo aplica a usuarios **internal** (OrganizationUsers).
  - Los usuarios **portal** (DealerUsers) no tienen filas aquí; su acceso es por RLS (su `dealer_id`) y por rol portal (member / member_manager).

## Cómo se relacionan con la UI

- En **Settings → User Permissions** se agrupa por **module** (Directory, Sales, Catalog, Inventory, etc.).
- Cada permiso mostrado es un `code` de `Permissions` (p. ej. `directory.read`, `quotes.edit`).
- Los presets por rol (superadmin, admin, operator, …) en `src/rbac/rolePresets.ts` usan esos mismos `code` y se persisten en `OrganizationUserPermissions`.

## Regla práctica

- **Module** = agrupación visual y lógica (dashboard, directory, sales, catalog, inventory, manufacturing, finance, settings, org).
- **Permission code** = `"<module>.<action>"` (p. ej. `directory.read`, `directory.write`, `inventory.read`, `inventory.write`).
- Para que un permiso aparezca en la UI y se pueda asignar, debe existir una fila en `Permissions` con ese `code` y un `module` coherente.

## Seed de permisos

Si faltan filas en `Permissions`, hay que hacer `INSERT` (por migración o seed), por ejemplo:

```sql
INSERT INTO public."Permissions" (code, module, description)
VALUES
  ('directory.read', 'directory', 'View directory'),
  ('directory.write', 'directory', 'Edit directory'),
  ('sales.read', 'sales', 'View sales'),
  ('quotes.edit', 'sales', 'Create and edit quotes'),
  ('inventory.read', 'inventory', 'View inventory (warehouses, stock, availability)'),
  ('inventory.write', 'inventory', 'Create/edit inventory (warehouses, POs, adjustments)')
ON CONFLICT (code) DO NOTHING;
```

La migración `20260217_inventory_rbac_permissions.sql` ya inserta `inventory.read` e `inventory.write`. El resto de permisos (directory, sales, catalog, etc.) deberían estar en migraciones anteriores o en el seed del proyecto.
