# Admin → Roles (UI)

Pantalla `/admin/roles` con Tabs ORG | DEALER | ALL, CRUD básico de roles (crear + renombrar) y editor de permisos por rol.

Fuente de verdad: **AppUserRoles** (code, name, description, user_type, sort_order, is_system), **AppUserRolePermissions**, **Permissions**. Sin migraciones. Sin triggers.

## Rutas y navegación

- **`/admin/roles`** — Pantalla principal Admin → Roles.
- **`/settings/roles`** — Redirect a `/admin/roles`:
  - `setCurrentPage('admin-roles')`
  - `router.navigate('/admin/roles', false)`
- Tanto `case 'roles'` como `case 'admin-roles'` en el router renderizan la misma pantalla (AdminRoles).
- Settings → "Roles & Permissions" navega a `/admin/roles`.

## Archivos

| Archivo | Uso |
|---------|-----|
| **`src/hooks/useRolesAdmin.ts`** | **Único archivo de hooks.** Tipos: PermissionRow, AppUserRoleRow, AppUserRoleListItem. Hooks: useRoleList(user_type, enabled), usePermissionsList(enabled), useRolePermissionCodes(roleCode, enabled), useCreateRole(), useUpdateRoleName(), useSyncRolePermissions(). |
| `src/pages/admin/Roles.tsx` | Página: tabs ORG \| DEALER \| ALL, lista roles (name, code muted, badge user_type, permission_count, badge System), botón New role, editor (name editable si !is_system, Save name, RolePermissionsEditor, Save permissions si dirty). Modal crear rol: code, name, user_type (por tab; si tab ALL se elige). |
| `src/components/permissions/RolePermissionsEditor.tsx` | Props: permissions (PermissionRow[]), selected (Set<string>), onToggle, onSelectAllInModule, loading?. Agrupa por module, checkbox por permiso, "Select all in module". Si selected.size === 0 => "No permissions assigned." |

## Acceso

- **canManageRoles** := `permissionSet.has('roles.manage')` **OR** `(isSuperAdmin || isAdmin)` usando useCurrentOrgRole().
- Si **!canManageRoles**: mostrar "Not authorized" + botón "Back to Dashboard".
- **Importante:** si !canManageRoles => **no ejecutar queries** (React Query `enabled: false` en todos los hooks).

## Reglas de negocio

1. **Tabs:** ORG (default) | DEALER | ALL. No mezclar tipos en un mismo tab; al cambiar tab se limpia la selección.
2. **Listado:** order user_type asc, sort_order asc, name asc. Normalizar: sort_order null => 9999, is_system => !!.
3. **Conteo en batch:** una query AppUserRolePermissions con .in('role_code', roleCodes); si roleCodes.length === 0 no llamar.
4. **Guardado permisos:** diff toAdd / toRemove; delete batch + insert batch (NO upsert). Invalidar rolePermissionCodes y roleList.
5. **is_system:** nombre NO editable, NO borrar; permisos SÍ editables.

## Tipos (useRolesAdmin.ts)

```ts
type PermissionRow = { code: string; module: string; description: string | null; }
type AppUserRoleRow = {
  code: string; name: string; description: string | null;
  user_type: 'org' | 'dealer'; sort_order: number | null; is_system: boolean | null;
}
type AppUserRoleListItem = {
  ...AppUserRoleRow normalizado (sort_order number, is_system boolean);
  permission_count: number;
}
```

## Nota: ActingAsSwitcher y Admin → Roles

- **ActingAsSwitcher** es visible en `/admin/roles` (la ruta no es settings, así que la barra superior se muestra).
- **Admin → Roles no depende de activeDealerId**: esta pantalla solo consume AppUserRoles / Permissions / AppUserRolePermissions; el filtro "Dealer Account" (activeDealerId) no afecta los listados de roles ni permisos. Si el "dealer filter" falla en Directory/Sales/etc., es un bug aparte (p. ej. queryKey o .eq('dealer_id') en esos hooks).

## Queries SQL de verificación

(Ver sección anterior en el doc o usar las 6 queries estándar: roles, usuarios con role_code inválido, conteo permisos por rol, permisos de un rol, roles sin permisos, role_permissions con permission_code inválido.)

## QA manual

1. **Acceso:** Con roles.manage o Admin/Superadmin; sin permiso mostrar "Not authorized" y no ejecutar queries.
2. **Tabs:** ORG | DEALER | ALL; al cambiar tab la lista cambia y se limpia la selección.
3. **Lista:** name, code muted, badge user_type, permission_count, badge System.
4. **Crear rol:** New role; si tab ALL elegir user_type; code, name; duplicate code => "Role code already exists".
5. **Editar nombre:** Solo si !is_system; Save name solo si cambió.
6. **Permisos:** RolePermissionsEditor; Save permissions solo si dirty; recargar y verificar persistencia.
7. **Empty:** Rol con 0 permisos muestra "No permissions assigned."
