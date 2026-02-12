# Migración: Dealer Profile y Settings a AppUsers

Resumen de los cambios realizados para que el módulo Dealer Detail / Dealer Profile y todas las pantallas de usuarios dealer en Settings usen **AppUsers** como fuente de verdad en lugar de **DealerUsers**.

---

## ⚠️ CustomerPortalUser / CompanyPortalUser: ya no se usan

- **No existe** la tabla "CustomerPortalUsers" ni "CompanyPortalUsers" en el esquema actual. La migración `20260207_rename_company_to_dealer.sql` renombró **CompanyPortalUsers → DealerUsers** (y Companies → Dealers).
- **Fuente de verdad para usuarios del portal dealer:** **AppUsers** (user_type = 'dealer', dealer_id, role_code) y, por FKs legacy, **DealerUsers**.
- La página **CustomerPortalUsers.tsx** existe en el repo pero **no está montada en el router**; la ruta `/settings/dealer-users` (y el legacy `/settings/company-portal-users`) cargan **DealerUsers.tsx**. No se debe seguir usando el nombre "CustomerPortalUser(s)" en lógica ni en nuevas funciones.

---

## Objetivo

- **Fuente de verdad:** tabla **AppUsers** (user_type = 'dealer', role_code = dealer_manager | dealer_member).
- **DealerUsers:** se mantiene por FKs legacy (DirectoryContacts, DirectoryCustomers, Proposals, Quotes tienen `created_by_portal_user_id` → DealerUsers.id). La Edge Function `create-temp-user` sigue escribiendo en ambas tablas para portal.

---

## 1. Hooks nuevos / modificados

### `src/hooks/useAppUsersByDealer.ts`

| Export | Uso |
|--------|-----|
| **useAppUsersByDealer(dealerId)** | Lista AppUsers de **un dealer** (user_type='dealer', dealer_id=dealerId). Usado en **Dealer Profile (formulario de edición)** para la sección "Dealer Users". |
| **useDealerAppUsersForOrg(organizationId)** | Lista **todos** los AppUsers tipo dealer de la organización (con dealer_name). Usado en **DealerUsers.tsx**, **DealerUser.tsx**. (CustomerPortalUsers.tsx no está en el router; ver nota arriba.) |
| **DealerAppUser** | Tipo: id, email, display_name, role_code, status, dealer_id, created_at, etc. |
| **DealerAppUserWithDealer** | DealerAppUser + dealer_name. |
| **roleCodeToPortalLabel(roleCode)** | Mapea role_code → "Manager" / "Member". |
| **portalRoleToRoleCode(role)** | Mapea 'member' | 'member_manager' → 'dealer_member' | 'dealer_manager'. |
| **roleCodeToPortalRole(roleCode)** | Mapea role_code → CompanyPortalRole para formularios. |

---

## 2. Edge Function: create-temp-user

**Archivo:** `supabase/functions/create-temp-user/index.ts`

- Para **kind: 'portal'**:
  - Sigue haciendo **upsert en DealerUsers** (legacy y FKs).
  - **Además** escribe en **AppUsers**:
    - Si ya existe fila (mismo org, user_type, dealer_id, email): **UPDATE** (auth_user_id, display_name, role_code, status, etc.).
    - Si no existe: **INSERT** (organization_id, user_type='dealer', dealer_id, auth_user_id, email, display_name, role_code, status, …).
  - `role` del body ('member' | 'member_manager') se mapea a **role_code** ('dealer_member' | 'dealer_manager').

---

## 3. Páginas migradas

### 3.1 Dealer Profile (Dealer Detail) — `DealerProfileForm.tsx`

| Antes | Después |
|-------|--------|
| useDealerUsers(dealerId) | **useAppUsersByDealer(dealerId)** |
| Lista DealerUsers | Lista **AppUsers** (display_name, email, role_code, status, created_at) |
| Crear usuario | Sigue **create-temp-user** (ya escribe AppUsers + DealerUsers) |
| Editar | **UPDATE AppUsers** (display_name, email, role_code, status) |
| Eliminar | **UPDATE AppUsers** (deleted = true). No se usa RPC delete_dealer_user. |

- Tipos: **DealerAppUser** para la lista y modales de edición/eliminación.

---

### 3.2 Dealer Users — `DealerUsers.tsx`

| Antes | Después |
|-------|--------|
| useDealerUsers() (toda la org) | **useDealerAppUsersForOrg(activeOrganizationId)** |
| Tipo DealerUser | **DealerAppUserWithDealer** |
| Autorizar | UPDATE **AppUsers** (status = 'active') |
| Archivar | UPDATE **AppUsers** (status = 'disabled') |
| Eliminar | UPDATE **AppUsers** (deleted = true) |
| Editar (modal) | UPDATE **AppUsers** (display_name, email, dealer_id, role_code, status) |
| Reenviar invitación | user.email, user.display_name (AppUsers) |

- Crear usuario: **create-temp-user** (sin cambios en la llamada).

---

### 3.3 Dealer User — `DealerUser.tsx`

- Misma migración que DealerUsers.tsx: **useDealerAppUsersForOrg**, CRUD sobre **AppUsers**, tipo **DealerAppUserWithDealer** en lista, edición y acciones.

---

### 3.4 Customer Portal Users — `CustomerPortalUsers.tsx`

| Antes | Después |
|-------|--------|
| useDealerUsers() | **useDealerAppUsersForOrg(activeOrganizationId)** |
| Crear: INSERT DealerUsers | **create-temp-user** (portal) |
| Editar: UPDATE DealerUsers | **UPDATE AppUsers** |
| Eliminar / Autorizar / Archivar | **UPDATE AppUsers** |
| Invite modal: buscar/crear en DealerUsers | Buscar en **AppUsers** (org + email); si no existe, **create-temp-user** y luego obtener AppUsers.id para send-customer-portal-invite |
| Lista / Edit / Resend | **DealerAppUserWithDealer**; display_name, email, status, created_at |

- Tabla: columnas Contact Name, Contact Email, Contact Phone mostradas como "—" (AppUsers no tiene esos campos).

---

## 4. Documentación actualizada

- **docs/ROLE_HOOK_APPUSER_AND_DEALERUSERS_LEGACY.md**  
  Se añadió la sección **"Módulo Dealer Profile (Settings)"** describiendo que ese módulo usa solo AppUsers (hook, crear vía create-temp-user, editar/eliminar en AppUsers).

---

## 5. Resumen de archivos tocados

| Archivo | Cambio |
|---------|--------|
| `src/hooks/useAppUsersByDealer.ts` | Hook useAppUsersByDealer (ya existía); **añadido** useDealerAppUsersForOrg y tipos/helpers. |
| `supabase/functions/create-temp-user/index.ts` | Para portal: **insert/update en AppUsers** además de DealerUsers. |
| `src/pages/settings/DealerProfileForm.tsx` | useAppUsersByDealer; list/edit/delete sobre AppUsers. |
| `src/pages/settings/DealerUsers.tsx` | useDealerAppUsersForOrg; CRUD y acciones sobre AppUsers. |
| `src/pages/settings/DealerUser.tsx` | Idem DealerUsers.tsx. |
| `src/pages/settings/CustomerPortalUsers.tsx` | useDealerAppUsersForOrg; Create/Edit/Invite/Delete/Authorize/Archive sobre AppUsers. |
| `docs/ROLE_HOOK_APPUSER_AND_DEALERUSERS_LEGACY.md` | Sección "Módulo Dealer Profile (Settings)". |

---

## 6. Notas

- **AppUserRoles:** Los códigos `dealer_manager` y `dealer_member` deben existir en la tabla AppUserRoles (FK de AppUsers.role_code). Si faltan, hay que crearlos (p. ej. migración o seed).
- **DealerUsers** no se elimina: sigue referenciada por `created_by_portal_user_id` en DirectoryContacts, DirectoryCustomers, Proposals, Quotes.
- **useAccessContext** ya usaba AppUsers como primera fuente de rol para portal; el fallback a DealerUsers (Legacy) se mantiene.
- **RPC delete_dealer_user:** ya no se usa desde las pantallas migradas; el borrado es soft-delete en AppUsers.

---

## 7. Edge Functions válidas para dealer portal

| Función | Uso | Nota |
|--------|-----|------|
| **create-temp-user** | Crear usuario portal (DealerUsers + AppUsers). Body: `kind: 'portal'`, **dealer_id**, organization_id, email, name, role, status. | Error si falta: "Missing dealer_id". |
| **send-customer-portal-invite** | Enviar invitación por **Auth** (inviteUserByEmail). Body: **dealer_id**, organization_id, portal_user_email, role, redirect_to. | Nombre legacy; la implementación usa tabla **DealerUsers** y **dealer_id**. No usa CompanyPortalUsers ni company_id. |

**No usar / obsoletas para este flujo:**

- **send-company-portal-invite**: no está en el repo actual; si aparece en Supabase Dashboard es un deploy antiguo. Para dealer portal usar **send-customer-portal-invite** (con dealer_id).
- **invite-user**: usa `company_id` para portal; en el código front no se invoca para portal. Para invitaciones dealer usar **send-customer-portal-invite** con **dealer_id**.
