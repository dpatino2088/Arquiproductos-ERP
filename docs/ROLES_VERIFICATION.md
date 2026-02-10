# Roles & Permissions — Verificación manual

Queries para comprobar el estado de `AppUserRoles` y `AppUserRolePermissions`. Ejecutar en SQL Editor (Supabase o cliente PostgreSQL).

## 1. Ver roles existentes

```sql
SELECT code, name, user_type
FROM public."AppUserRoles"
ORDER BY user_type, name;
```

## 2. Usuarios con roles inválidos (role_code que no existe en AppUserRoles)

```sql
SELECT au.id, au.email, au.role_code
FROM public."AppUsers" au
LEFT JOIN public."AppUserRoles" r ON r.code = au.role_code
WHERE au.role_code IS NOT NULL
  AND r.code IS NULL;
```

Si hay filas: esos usuarios tienen un `role_code` que ya no existe (rol borrado o legacy). En la UI se muestra "Unknown role: <code>" y se puede elegir un rol nuevo.

## 3. Permisos por rol (conteo)

```sql
SELECT role_code, COUNT(*) AS permission_count
FROM public."AppUserRolePermissions"
GROUP BY role_code
ORDER BY role_code;
```

## 4. Listar permisos asignados a un rol

```sql
-- Reemplaza :role_code por el código (ej. 'member', 'admin')
SELECT p.code, p.module, p.description
FROM public."AppUserRolePermissions" arp
JOIN public."Permissions" p ON p.code = arp.permission_code
WHERE arp.role_code = :role_code
ORDER BY p.module, p.code;
```

## Notas

- **AppUserRoles** tiene `user_type` NOT NULL ('org' | 'dealer'). Incluirlo en cualquier INSERT/UPDATE.
- La UI de Dealer Users carga roles con `user_type = 'dealer'`. La de Organization/App Users (cuando exista) usará `user_type = 'org'`. **Nunca mezclar roles org y dealer en el mismo dropdown**, aunque tengan permisos similares.
- **Permisos cuando el usuario no tiene `role_code` válido (legacy):**
  - **Fase actual (temporal):** superadmin/admin → acceso total; otros → `OrganizationUserPermissions`.
  - **Fase final:** todos los usuarios deben tener `role_code` y esta rama legacy se elimina. No confiar en el fallback a largo plazo.
- **Fuente de verdad de permisos:** es `AppUserRolePermissions`, no el frontend ni el rol en sí. El frontend solo consume conjuntos de permisos ya resueltos (p. ej. `permissionSet.has(code)`). Evitar lógica en UI del tipo `if (role === 'superadmin') { ... }`; usar siempre el set de permisos.
