# Dealer Account (Super Admin) y RLS por Dealer — Para el equipo

Documento de referencia para dejar **claro y establecido** qué hay en el DUMP, qué se implementó y qué falta.

---

## 1. Qué hay en el DUMP / esquema que usamos

Todo está referenciado a **Dealer** (no Company). Origen: migración `20260207_rename_company_to_dealer.sql`.

### Tablas base

| Tabla | Uso |
|-------|-----|
| **Organizations** | La “casa” (ej. Pertexco). Una org tiene muchos dealers. |
| **Dealers** | Dealers de la org. PK `id`, `organization_id`, `dealer_no`, `dealer_name`, `dealer_email`, `dealer_phone`, `status`, `deleted`. |
| **OrganizationUsers** | Usuarios internos de la org. `user_id`, `organization_id`, **`role`** (ej. `superadmin`, `admin`, `super_admin` legacy), `status`, `deleted`. |
| **DealerUsers** | Usuarios portal por dealer. `user_id`, **`organization_id`**, **`dealer_id`**, `portal_user_email`, `role`, `status`, `deleted`. |

### Tablas con `dealer_id` (FK a Dealers)

- **Quotes**, **QuoteLines**, **SalesOrders**, **ManufacturingOrders**, **OrderList**
- **DirectoryCustomers**, **DirectoryContacts**

Referencia: `database/DUMP_REVISION_DEALERS_DEALERTIERS.md`.

### Rol en OrganizationUsers

- En BD el rol puede venir como **`superadmin`** o **`super_admin`** (legacy).
- En frontend usamos **rol canónico** `superadmin`; el legacy se normaliza con `mapLegacyRole()` en `OrganizationContext`.

---

## 2. Qué se hizo (implementado)

### A. Frontend — “Dealer Account” (solo Organization Super Admin)

- **ActingAsContext** (`src/context/ActingAsContext.tsx`): guarda `activeDealerId`, `activeDisplayName`, `activeDealerType` (`internal` \| `external`). Persistido en **localStorage** (`adaptio_acting_as`). No se persiste en BD.
- **ActingAsSwitcher** (`src/components/layout/ActingAsSwitcher.tsx`): badge **“Dealer Account: [Nombre]”** (ej. “Dealer Account: Carretero”). Solo visible para usuario con rol **superadmin** (Organization Super Admin).
- **SelectActingDealer** (`src/pages/SelectActingDealer.tsx`): pantalla obligatoria para Super Admin sin cuenta elegida. Ruta: `/select-acting-dealer`.
- **SuperAdminActingGate**: si no hay cuenta elegida → redirect a `/select-acting-dealer`. Si el dealer elegido ya no existe → limpia y redirect (evita estados zombis).
- **useActiveDealer**: cuando el usuario es Super Admin, usa el contexto “Dealer Account”; para el resto, comportamiento anterior (primer dealer o estado local).
- **Rol canónico**: en `OrganizationContext` se usa `mapLegacyRole(m.role)` al construir memberships, para que en toda la app el rol sea `superadmin` (no `super_admin`).

### B. Filtrado por dealer (cuando Super Admin tiene cuenta dealer seleccionada)

- **useDirectoryContacts**: si `activeDealerId` está definido, solo se piden contactos de ese dealer (y `dealer_id` null). Si no, se mantiene “toda la org”.
- **useDirectoryCustomers**: si `activeDealerId` está definido, la query filtra por `.eq('dealer_id', activeDealerId)`.
- **useQuotes / Sales**: ya filtraban por `effectiveDealerId` (que para Super Admin viene de `useActiveDealer` → contexto Dealer Account). Sin cambios adicionales.

Con “Dealer Account: Carretero” solo se ven contactos, clientes y cotizaciones de ese dealer.

### C. Migraciones SQL (RLS para usuarios Dealer/portal)

Estas migraciones **sí tocan RLS** para que los usuarios **portal (DealerUsers)** puedan leer lo necesario. Hay que ejecutarlas en el orden indicado si aún no están aplicadas.

| Archivo | Qué hace |
|---------|----------|
| **20260215_bom_templates_rls_allow_dealer_users.sql** | Política SELECT en `BOMTemplates`: además de `OrganizationUsers`, permite acceso cuando `organization_id` está en `DealerUsers` para el usuario actual. Así el configurador muestra templates a usuarios Dealer. |
| **20260215_configured_products_rls_allow_dealer_users.sql** | Política SELECT en `ConfiguredProducts` (y en `ConfiguredProductOptions` si la tabla existe): mismo criterio, vía `OrganizationUsers` o `DealerUsers`. Evita “Configuration Not Found” para Dealers. |
| **20260215_is_org_user_member_include_dealer_users.sql** | Redefine `is_org_user_member(organization_id)`: devuelve true si el usuario está en **OrganizationUsers** o en **DealerUsers** para esa org. Así QuoteLines (y todo lo que usa esta función) permite a usuarios Dealer leer/escribir líneas de cotización. |

Sin estas tres migraciones, los usuarios Dealer no ven templates en el configurador, no cargan ConfiguredProduct y no ven líneas de cotización.

### D. Ajustes varios (ya hechos)

- **ConfigDiff**: log con `JSON.stringify(diff)` para evitar “[circular]” en consola.
- **OrganizationContext (portal)**: en modo portal se muestra el nombre del **Dealer** (`Dealers.dealer_name`) en el switcher de organización en lugar del nombre de la organización.

---

## 3. Qué hace falta (pendiente / opcional)

### 3.1 Migraciones: asegurar que están aplicadas

- En el proyecto existen las tres migraciones `20260215_*` listadas arriba.
- **Acción:** Ejecutarlas en la base (Supabase SQL o tu flujo de migraciones) si no se han corrido ya.
- **Verificación:** Usuario Dealer puede abrir cotización, ver líneas, ver templates en configurador y no ver “Configuration Not Found” al cargar una línea con `configured_product_id`.

### 3.2 RLS por dealer en backend (opcional / fase 2)

- Hoy, cuando un **Super Admin** elige “Dealer Account: Carretero”, el **frontend** solo pide datos con `dealer_id = Carretero`. Las políticas RLS de Directory (534) permiten a Super Admin ver toda la org.
- Si se quiere que **en BD** un Super Admin no pueda leer datos de otros dealers aunque manipule el cliente, haría falta:
  - Variable de sesión o claim JWT con “acting as dealer_id”, y
  - Políticas RLS que para usuarios internos (OrganizationUsers) restrinjan por ese `dealer_id` cuando esté definido.
- **Resumen:** No es obligatorio para el MVP; el filtrado en frontend es suficiente para el flujo actual.

### 3.3 Normalizar rol en BD (opcional)

- En BD, `OrganizationUsers.role` puede ser `super_admin` (legacy). En frontend ya se normaliza con `mapLegacyRole` a `superadmin`.
- **Opcional:** Migración que actualice `OrganizationUsers.role` de `super_admin` → `superadmin` (y `owner` → `superadmin` si aplica) para tener un solo valor canónico en BD. No bloquea nada si no se hace.

### 3.4 Documentación / DUMP

- **DUMP_REVISION_DEALERS_DEALERTIERS.md** describe la tabla Dealers y su uso; está alineado con lo anterior.
- **PLAN_MVP_SUPER_ADMIN_ACTING_AS.md** describe el MVP “Dealer Account” y el flujo Super Admin.

---

## 4. Resumen rápido

| Tema | En DUMP / base | Hecho en código | Pendiente |
|------|----------------|-----------------|-----------|
| Nomenclatura | Todo es Dealer (`Dealers`, `dealer_id`) | UI “Dealer Account”, hooks y contexto con `activeDealerId` | — |
| Rol Super Admin | `OrganizationUsers.role` (puede ser `super_admin`) | Normalización a `superadmin` en OrganizationContext; badge solo para superadmin | Opcional: normalizar valor en BD |
| Dealer Account | No hay tabla “cuenta activa”; es sesión | ActingAsContext + localStorage; SelectActingDealer; ActingAsSwitcher | — |
| Filtro por dealer | Directory y Sales tienen `dealer_id` | useDirectoryContacts/Customers y useQuotes filtran por `activeDealerId` cuando está definido | — |
| RLS para portal | Políticas solo por OrganizationUsers | Migraciones 20260215_*: BOMTemplates, ConfiguredProducts, is_org_user_member incluyen DealerUsers | Ejecutar migraciones si no están aplicadas |
| RLS por dealer (backend) | No implementado | — | Opcional fase 2 (variable de sesión + políticas) |

---

## 5. Referencias de archivos

- **Contexto y UI:** `src/context/ActingAsContext.tsx`, `src/components/layout/ActingAsSwitcher.tsx`, `src/pages/SelectActingDealer.tsx`, `src/components/SuperAdminActingGate.tsx`
- **Hooks que filtran por dealer:** `src/hooks/useActiveDealer.ts`, `src/hooks/useDirectoryContacts.ts`, `src/hooks/useDirectoryCustomers.ts`, `src/hooks/useQuotes.ts`
- **Rol:** `src/context/OrganizationContext.tsx` (mapLegacyRole), `src/rbac/rolePresets.ts` (mapLegacyRole), `src/components/Layout.tsx` (isSuperAdminUser)
- **Migraciones RLS:** `database/migrations/20260215_*.sql`
- **DUMP / esquema:** `database/DUMP_REVISION_DEALERS_DEALERTIERS.md`, `database/migrations/20260207_rename_company_to_dealer.sql`
