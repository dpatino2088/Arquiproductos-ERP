# Entregables: fix is_org_user_member (sin DROP) + Inventory visible en UI

## Lista de archivos tocados

### Part A (DB)
- **database/migrations/20260208_fix_is_org_user_member_no_drop.sql** (nuevo)

### Part B (UI)
- **src/components/Layout.tsx** — ítem Inventory en sidebar, mapa de rutas portal
- **src/hooks/useAccessContext.ts** — `ModuleKey` + `allowedModules` con `inventory`
- **src/hooks/usePermissions.ts** — `MODULE_PERMS.inventory` (inventory.read / inventory.write)

### Part C (RBAC BD + presets)
- **database/migrations/20260217_inventory_rbac_permissions.sql** (nuevo) — INSERT permisos y asignación a roles
- **src/rbac/rolePresets.ts** — `inventory.read` y `inventory.write` en presets (superadmin, admin, operator, procurement)

---

## Part A — Migración SQL

**Archivo:** `database/migrations/20260208_fix_is_org_user_member_no_drop.sql`

- **No usa DROP FUNCTION** (las policies dependen de la función).
- Obtiene el nombre del argumento actual con `pg_proc.proargnames[1]` y ejecuta `CREATE OR REPLACE` por SQL dinámico con ese nombre (en PROD es `p_org_id`).
- La función devuelve `true` si `auth.uid()` está en:
  - **OrganizationUsers** para esa org, con `coalesce(deleted, false) = false` y `(status IS NULL OR status IN ('active', 'invited'))`, o
  - **DealerUsers** para esa org, con la misma condición.
- `SET search_path = public, auth`.
- Bloque opcional: si existe la tabla **ConfiguredProductOptions**, se crea la policy `configured_product_options_select_org` (SELECT con `is_org_user_member(organization_id)`). En el dump V4 esa tabla no existe; el bloque no hace nada hasta que exista.

---

## Part B — Inventory en UI

1. **Layout.tsx**
   - Añadido ítem `{ name: 'Inventory', href: '/inventory', icon: Package, module: 'inventory' }` en `allItems`.
   - Añadido `inventory: "inventory"` al mapa de rutas para portal (bloqueo si no está en `allowedModules`).
   - El `case 'Inventory'` en el switch de ruta activa ya existía.

2. **useAccessContext.ts**
   - `ModuleKey` incluye `"inventory"`.
   - Para usuarios **internal**, `allowedModules` incluye `"inventory"`.
   - **Portal** sigue con `PORTAL_ALLOWED_MODULES` (dashboard, directory, sales); no se añade inventory (solo internal por defecto).

3. **usePermissions.ts**
   - Añadido `inventory: { view: ['inventory.read'], edit: ['inventory.write'] }` en `MODULE_PERMS`.
   - Los internal no-SuperAdmin necesitan permiso `inventory.read` (o rol que lo incluya) para ver el módulo; SuperAdmin sigue con bypass.

---

## Part C — RBAC en BD y consistencia UI

1. **Tabla de permisos**  
   Se usa **`public.Permissions`** (code, module, description) y **`public.OrganizationUserPermissions`** (organization_user_id, permission_code), igual que en 511 / 510.

2. **Migración** `database/migrations/20260217_inventory_rbac_permissions.sql`
   - **INSERT** en `Permissions`: `inventory.read`, `inventory.write` (module `inventory`), con `ON CONFLICT (code) DO NOTHING`.
   - **Asignación** a usuarios existentes:
     - Roles `superadmin` y `admin`: `inventory.read` + `inventory.write`.
     - Roles `operator` y `procurement`: `inventory.read`.
     - Rol `procurement`: además `inventory.write`.
   - Todo con `ON CONFLICT (organization_user_id, permission_code) DO NOTHING`.

3. **rolePresets.ts**
   - **superadmin** y **admin**: añadidos `inventory.read`, `inventory.write`.
   - **operator**: añadido `inventory.read`.
   - **procurement**: añadidos `inventory.read`, `inventory.write`.

4. **Sidebar (Layout)**
   - **Portal**: Inventory **no** aparece (no está en `allowedModules`).
   - **Internal**: Inventory aparece solo si está en `allowedModules` **y** (usuario es SuperAdmin, **o** tiene al menos `inventory.read` vía `MODULE_PERMS.inventory.view`). No se inventan tablas; se usa el flujo existente (PermissionContext / can()).

---

## QA checklist

- [ ] **Migración**
  - Ejecutar `20260208_fix_is_org_user_member_no_drop.sql` en entorno tipo PROD (con policies que usan `is_org_user_member`).
  - Verificar que no se use DROP y que la función siga existiendo con el mismo nombre y argumento `p_org_id`.
  - Comprobar que usuarios en DealerUsers (active/invited) pasan `is_org_user_member(organization_id)` para su org.
  - Si existe tabla ConfiguredProductOptions, verificar que la policy SELECT se crea y que el SELECT usa `is_org_user_member(organization_id)`.

- [ ] **Portal (Dealer)**
  - Por defecto el portal **no** tiene `inventory` en `allowedModules`, por tanto no ve el ítem Inventory en el sidebar.
  - Si en el futuro se añade `inventory` a `PORTAL_ALLOWED_MODULES`, comprobar que un Dealer puede abrir `/inventory` y que las consultas a tablas/vistas de inventario (p. ej. `inventory_availability`) respetan RLS vía `is_org_user_member` (DealerUsers para esa org).

- [ ] **Internal (org user)**
  - Usuario internal ve **Inventory** en el sidebar y puede abrir `/inventory` (p. ej. `/inventory/warehouse`) **solo si** tiene permiso `inventory.read` (o es SuperAdmin con bypass).
  - **Con permisos**: usuario internal no-SuperAdmin con rol admin/operator/procurement (o con `inventory.read` asignado en OrganizationUserPermissions) debe ver el ítem Inventory.
  - **Sin permisos**: usuario internal no-SuperAdmin **sin** `inventory.read` no debe ver el ítem Inventory en el sidebar.
  - SuperAdmin siempre ve Inventory (bypass en Layout).
  - Comprobar que el menú lateral muestra Inventory entre Catalog y Manufacturing cuando el usuario tiene acceso.

- [ ] **Availability deja de ser "—"**
  - Con **warehouse por defecto** creado para la org y datos en **InventoryBalances** y/o **PurchaseOrders** (líneas OPEN/PARTIAL), la columna Availability en Catalog Items (y donde se use el badge) debe mostrar IN_STOCK / ON_ORDER / OUT_OF_STOCK según corresponda, en lugar de "—".

- [ ] **RBAC (migración 20260217)**
  - Tras ejecutar la migración, en `Permissions` existen filas con `code` = `inventory.read` e `inventory.write` y `module` = `inventory`.
  - Usuarios con rol `superadmin` o `admin` tienen ambas permisos en `OrganizationUserPermissions`.
  - Usuarios con rol `operator` o `procurement` tienen al menos `inventory.read`; `procurement` además `inventory.write`.

---

## Notas

- Los permisos `inventory.read` e `inventory.write` se insertan y asignan con la migración **20260217_inventory_rbac_permissions.sql**. Los presets en `rolePresets.ts` se usan al crear/editar usuarios (asignación por rol en la UI).
- Si quieres que el portal (Dealers) vea Inventory, añade `"inventory"` a `PORTAL_ALLOWED_MODULES` en `useAccessContext.ts`.
