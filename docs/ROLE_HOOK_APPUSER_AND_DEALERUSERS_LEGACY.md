# Hook de rol: AppUser.role_code y DealerUsers (Legacy)

## Cambio realizado

El **hook de rol** para usuarios portal (Dealer Manager / Dealer Member) ahora usa en este orden:

1. **AppUsers.role_code** (fuente principal)  
   - Se busca en `AppUsers` por `user_type = 'dealer'` y `auth_user_id = uid` o `email = jwtEmail`.  
   - El rol se toma de **role_code** (ej. `dealer_manager`, `dealer_member`) y se mapea a `PortalRole`:  
     - `dealer_manager` → `member_manager`  
     - `dealer_member` → `member`

2. **DealerUsers (Legacy)**  
   - Si no hay fila en AppUsers, se busca en `DealerUsers` por `user_id` o `portal_user_email`.  
   - El rol se toma de la columna **role** (`member` | `member_manager`) y se usa como `PortalRole`.  
   - Este camino se considera Legacy y se mantendrá mientras existan usuarios solo en DealerUsers.

3. **OrganizationUsers** (usuarios internos)  
   - Sin cambios: se sigue usando `OrganizationUsers.role` para usuarios internos.

## Archivos modificados

- **`src/hooks/useAccessContext.ts`**:  
  - Primero consulta `AppUsers` (user_type = 'dealer') y usa `role_code`.  
  - Fallback a `DealerUsers` con la columna `role` (Legacy).  
  - Función de mapeo renombrada a `roleCodeToPortalRole` (soporta `dealer_manager`/`dealer_member` y `member`/`member_manager`).

- **`src/context/PermissionContext.tsx`**:  
  - Ya usaba `AppUsers.role_code` para cargar permisos vía `AppUserRolePermissions`. No se modificó.

## ¿Se puede hacer DROP de la tabla DealerUsers?

**No.** En el dump V14 (y en el esquema actual) la tabla **DealerUsers** sigue siendo referenciada por FKs:

| Tabla                | Columna                     | FK a DealerUsers |
|----------------------|-----------------------------|-------------------|
| DirectoryContacts    | created_by_portal_user_id   | Sí                |
| DirectoryCustomers   | created_by_portal_user_id   | Sí                |
| Proposals            | created_by_portal_user_id   | Sí                |
| Quotes               | created_by_portal_user_id   | Sí                |

Además, varias funciones y políticas RLS siguen usando DealerUsers, por ejemplo:

- `get_current_portal_user_dealer_id()` (lee DealerUsers)
- `current_dealer_id(p_org_id)` (lee DealerUsers)
- `is_org_user_member` (incluye DealerUsers)
- RLS en Directory, Quotes, Proposals, etc.

Para poder hacer DROP de DealerUsers en el futuro habría que:

1. Migrar `created_by_portal_user_id` a algo como `created_by_app_user_id` (referenciando `AppUsers.id`) en las tablas anteriores, **o**
2. Mantener DealerUsers como tabla Legacy y sincronizarla desde AppUsers (triggers o jobs).

Mientras tanto, **no eliminar la tabla DealerUsers** y seguir usando el fallback Legacy en el front (useAccessContext).

## Módulo Dealer Profile (Settings)

El módulo **Dealer Detail / Dealer Profile** en Settings (lista de usuarios del dealer, alta/edición/baja) usa **solo AppUsers**:

- **Hook:** `useAppUsersByDealer(dealerId)` — lista `AppUsers` con `user_type='dealer'` y `dealer_id=dealerId`. Sustituye a `useDealerUsers` en esta pantalla.
- **Crear usuario:** la Edge Function `create-temp-user` (kind=portal) escribe en **DealerUsers** (legacy, para FKs) y en **AppUsers** (fuente de verdad). `role_code`: `dealer_manager` | `dealer_member`.
- **Editar:** actualización directa en `AppUsers` (display_name, email, role_code, status).
- **Eliminar:** soft-delete en `AppUsers` (`deleted = true`). No se usa el RPC `delete_dealer_user` para esta pantalla.
- Los roles mostrados (Manager / Member) vienen de `AppUsers.role_code` y se mapean con `roleCodeToPortalLabel` / `portalRoleToRoleCode` en `src/hooks/useAppUsersByDealer.ts`.
