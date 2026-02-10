# PLAN MVP — Super Admin con contexto activo

## Objetivo (1 frase)

Que un **Super Admin** pueda elegir **con qué empresa está operando** (la organización tipo “Pertexco” o un **Dealer**) y que todo el sistema use ese contexto.

**Principio:** *Super Admin no cotiza; las empresas cotizan.* Todo depende de `active_dealer_id` (en frontend: `activeDealerId`).

---

## Alineación con el DUMP / esquema actual

- **No se crean tablas nuevas.** Se usan las existentes:
  - **Organizations** — la “casa” (ej. Pertexco).
  - **Dealers** — empresas/dealers de la org (tabla renombrada desde `Companies` en `20260207_rename_company_to_dealer.sql`).
  - **OrganizationUsers** — usuarios internos de la org (incluye Super Admin vía rol).
  - **DealerUsers** — usuarios portal por dealer.
- **Nomenclatura (alineada al DUMP):** Todo va referenciado a **Dealer** (tabla `Dealers`, columna `dealer_id`, hook `useActiveDealer`, `activeDealerId`). No se usan Company/Companies. “Acting as” = operar como **Organización** (dealer_id null) o como **Dealer** (dealer_id = id del dealer).
- **Queries existentes:** Quotes, QuoteLines, SalesOrders, ManufacturingOrders, OrderList, etc. ya filtran por `dealer_id` cuando se pasa `effectiveDealerId` (hoy desde `useActiveDealer()`). El MVP solo asegura que, para Super Admin, ese valor salga del **contexto “Acting as”** (persistido en localStorage).

---

## Qué NO hacemos (MVP)

- No crear nuevos roles.
- No tocar RLS.
- No duplicar usuarios ni impersonation avanzada.

---

## Qué SÍ hacemos (MVP)

### A. Sin nuevas tablas

Solo frontend + sesión/localStorage.

### B. Concepto: “Acting as” = `active_dealer_id` en UI

- **`activeDealerId`** (en código):
  - `null` = operar como **organización** (ej. Pertexco; cotizaciones/órdenes sin dealer o “internas”).
  - `uuid` = operar como **Dealer** con ese id.
- Vive en:
  - Context (React)
  - **localStorage** (clave `adaptio_acting_as`, JSON con `organizationId`, `dealerId`, `displayName`, `dealerType`).
- **`activeDealerType`:** `'internal'` (org) | `'external'` (dealer). Para pricing rules, features y UI condicional.
- **No** se persiste en BD.

### C. Flujo

1. **Login** como Super Admin.
2. Si **no hay** valor en localStorage para “acting as”:
   - Mostrar pantalla obligatoria: **“Selecciona con qué dealer u organización deseas operar”** (ruta `/select-acting-dealer`).
   - Opciones: **[Nombre de la organización]** (Pertexco) o **[Dealer A]**, **[Dealer B]**, …
   - Al elegir: se setea `activeDealerId` (null o uuid) y se guarda en localStorage.
3. Resto del sistema usa ese contexto (mismos queries que hoy con `effectiveDealerId`).

### D. Reglas

- **Sin empresa activa (Super Admin):** no cotizar, no ver precios sensibles, no crear órdenes hasta haber elegido.
- **Queries:** siguen usando `.eq('dealer_id', activeDealerId)` cuando `activeDealerId` está definido (ya lo hacen vía `useActiveDealer` → `effectiveDealerId`).
- Super Admin puede **cambiar de empresa** en cualquier momento desde el header.

### E. UI

- En el header (solo para Super Admin): **“Acting as: Organización – Pertexco”** o **“Acting as: Dealer – X”** (badge siempre visible para evitar “¿en qué cuenta estoy?”).
- Si el dealer elegido ya no existe (eliminado/permisos), `SuperAdminActingGate` limpia y redirige de nuevo a `/select-acting-dealer` (evita estados zombis).
- Pantalla obligatoria: `SelectActingDealer` — lista org + dealers; al elegir, se guarda en context + localStorage y redirige al dashboard.

---

## Cómo verificar que quedó bien

- Se ve el badge **“Acting as: X”** (solo Super Admin).
- Al elegir un Dealer, Directory (Contactos, Clientes) y Sales muestran solo datos de ese dealer. Rol canónico: superadmin.

---

## Referencias técnicas

- **DUMP / esquema:** `database/DUMP_REVISION_DEALERS_DEALERTIERS.md`, `database/migrations/20260207_rename_company_to_dealer.sql`. Todo referenciado a **Dealer** (no Company).
- **Hooks que usan dealer:** `useQuotes`, `useSalesOrders`, `useManufacturing`, `useOrderList`, `useActiveDealer`.
- **Super Admin:** `useCurrentOrgRole()` → `role === 'superadmin'`; en Layout `isSuperAdminUser`.
