# Cómo funciona hoy: filtrado por dealer y carga de listas

Este documento describe el comportamiento actual del filtrado por dealer (Dealer filter), la carga de listas (Directory y Sales) y la preservación de contenido. Sirve como base para decidir mejoras (Zero Loading, overlays, etc.).

---

## 1. Scope y Dealer Filter

### 1.1 Origen del scope

- **useDealerScope()** (usado por Directory y Sales) devuelve:
  - `scopeKey`: `"${activeOrganizationId}:${activeDealerId}"` (o `"none"` / `"all"` si falta org o dealer).
  - `activeDealerId`: viene de **useActiveDealer()**, que a su vez usa **useActingAsDealer()** (persistido en BD vía RPC `current_dealer_id()`).
- **useActiveDealer()** depende de **useDealers()** (lista de dealers de la org) y del valor “acting as” guardado para el usuario.
- El **Dealer filter** (ActingAsSwitcher) solo se muestra para usuarios **Super Admin** y **Admin**; el resto no lo ve.

### 1.2 Cuándo cambia el scope

- Al cambiar de **organización** (OrganizationSwitcher): cambia `activeOrganizationId` → nuevo `scopeKey`.
- Al elegir **otro dealer** en el Dealer filter (o "All dealers"): cambia `activeDealerId` → nuevo `scopeKey`.
- Para usuarios **portal**: no hay selector; el dealer es el suyo (un solo valor efectivo).

### 1.3 Hidratación (internal)

- Para usuarios **internos**, `hasHydrated` (de useActingAsDealer) indica si ya se leyó de BD el “acting as” dealer.
- Hasta que `hasHydrated` sea true, los hooks de Directory **no disparan el fetch** (efecto con `if (userType === 'internal' && !hasHydrated) return;`).
- Eso puede retrasar la **primera** carga de Contacts/Customers hasta que el scope esté hidratado.

---

## 2. Hooks de lista (Directory y Sales)

Los hooks relevantes son:

- **useDirectoryContacts**
- **useDirectoryCustomers**
- **useQuotes**
- **useProposals**
- **useSalesOrders**

Patrón común:

- Un **único useEffect** que depende de `scopeKey` (y `enabled`, y en Directory de `hasHydrated` para internal).
- Al montar o al cambiar `scopeKey`, se llama al fetch con **AbortController**; en cleanup se hace `abort()`.
- **No se vacía la lista al iniciar el fetch**: no hay `setContacts([])` / `setQuotes([])` al principio del callback. La lista anterior se mantiene hasta que llega la respuesta nueva (o error).
- Solo se vacía cuando:
  - no hay org (`!activeOrganizationId`) o `enabled` es false, o
  - la respuesta es “sin datos” o error (según cada hook).

Por tanto, **a nivel de hook**, al cambiar de dealer (mismo org, otro dealer) la lista **sí se preserva** durante el fetch: se siguen viendo los datos del dealer anterior hasta que llegan los del nuevo.

---

## 3. Estados que exponen los hooks (ej. useDirectoryContacts)

- **isPending** / **loading**: true mientras el fetch está en curso.
- **hasResolvedOnce**: true después del primer fetch que termina (éxito o error).
- **scopeState**: `'idle' | 'loading_scope' | 'ready' | 'switching' | 'error'`.
- **isFirstLoad**: `isPending && !hasResolvedOnce`.
- **isRefreshing**: `isPending && hasResolvedOnce` (refetch o cambio de scope tras haber cargado algo).
- **isSwitchingDealer**: `scopeState === 'switching' && isPending`.
- **isScopeReady**: para internal = `hasHydrated`; para portal = true.
- **hasData**: `contacts.length > 0` (o equivalente).

Cache en memoria (solo dentro del hook):

- useDirectoryContacts / useDirectoryCustomers tienen un **cacheRef** por `scopeKey`: si se vuelve a ese scope, se sirve desde cache y no se hace red hasta que se invalide.

---

## 4. Páginas: cuándo se muestra contenido y cuándo loading

### 4.1 Contacts (Directory)

- **initialLoading** = `isFirstLoad || orgLoading || !contactsScopeReady`.
- Si **initialLoading** es true → **return temprano**: solo se muestra título "Contacts Directory" y un bloque de carga centrado (spinner + "Loading contacts…"). **No se renderiza la tabla ni los filtros.**
- Cuando **initialLoading** es false → se renderiza la página completa (búsqueda, filtros, tabla).
- Luego, **overlays** (sin desmontar la tabla):
  - **isSwitchingDealer** → overlay "Switching dealer..." sobre la tabla.
  - **isRefreshing** (y no switching) → overlay "Updating...".
  - **isSearchSettling** → overlay "Filtering...".

Consecuencias:

- **Primera carga**: hasta que el primer fetch termina (y para internal hasta que `contactsScopeReady` sea true), el usuario **solo** ve el spinner a pantalla completa; no hay “contenido previo” que preservar.
- **Cambio de dealer**: una vez que ya hubo una carga exitosa, `hasResolvedOnce` es true, así que `isFirstLoad` es false. Si además `contactsScopeReady` sigue true, **initialLoading** es false y se muestra la tabla con los datos **antiguos** y el overlay "Switching dealer...". Es decir, **sí se preserva el contenido** durante el cambio de dealer en Contacts.

### 4.2 Customers (Directory)

- Patrón muy similar a Contacts (mismo useDirectoryCustomers, mismo tipo de scope e initialLoading).
- Misma idea: primera carga = pantalla de carga hasta primer éxito; cambio de dealer = tabla visible con overlay.

### 4.3 Quotes / Proposals / Sales Orders

- No tienen un “initialLoading” que haga **return temprano** con pantalla en blanco.
- Usan **loading** del hook y suelen mostrar la tabla siempre; cuando **loading** es true pueden mostrar skeleton o overlay según implementación.
- **useQuotes** / **useProposals** / **useSalesOrders** no vacían la lista al iniciar el fetch, así que al cambiar dealer la lista anterior se mantiene hasta que llega la nueva (comportamiento “keep previous data”).

---

## 5. Zero Loading (actual)

- **zeroLoading.ts** expone:
  - **warmDetailIfNeeded(queryClient, spec, opts)**: para “calentar” la cache de un **detalle** (p. ej. una fila o un panel de detalle) con un **cooldown** (por defecto 20s) y sin disparar si ya hay un fetch en curso para esa query.
  - **shouldWarm(warmId, cooldownMs)**.
- Se usa en **Proposals** e **Items** (catálogo) para pre-cargar detalle al hover/foco o cerca del viewport, no en el render inicial.
- **Directory (Contacts/Customers)** y las listas de **Sales** no usan React Query para las listas: usan estado local (useState) dentro de hooks propios. Por tanto, el patrón “placeholderData / keepPreviousData” de TanStack Query no se aplica ahí; la “preservación” depende de no vaciar la lista en el hook (ya implementado) y de que la página no oculte toda la tabla con un return temprano cuando hay datos previos.

---

## 6. Resumen: qué se preserva y qué no

| Escenario | ¿Se preserva el contenido en pantalla? |
|-----------|----------------------------------------|
| Primera carga (Contacts/Customers) | No. Se muestra pantalla de carga hasta que el primer fetch termina y (internal) scope está listo. |
| Cambio de dealer (Contacts/Customers) | Sí. La tabla con datos del dealer anterior sigue visible con overlay "Switching dealer...". |
| Cambio de dealer (Quotes/Proposals/Orders) | Sí. Los hooks no vacían la lista; la tabla muestra datos viejos hasta que llegan los nuevos. |
| Refetch manual (mismo scope) | Sí. Misma lista en pantalla; overlay "Updating..." si la página lo implementa. |
| Cambio de pestaña (Contacts ↔ Customers) | Depende de si el módulo desmonta las pestañas. Si se mantienen montadas (solo ocultas con `hidden`), cada una conserva su estado. |

---

## 7. Dolor actual (para mejorar)

1. **Primera carga “en blanco”**: en Contacts/Customers se espera a que termine el primer fetch (y en internal a que hidrate el scope) antes de mostrar la tabla; el usuario solo ve un spinner durante ese tiempo.
2. **Hidratación bloqueante**: para usuarios internos, el fetch no arranca hasta `hasHydrated`; si la RPC o la red son lentas, la primera carga se retrasa.
3. **Consistencia de UX**: Directory usa “pantalla de carga única” y luego tabla + overlays; Sales usa más bien tabla siempre + loading/overlay. Unificar criterio puede mejorar la sensación de “contenido que se preserva”.
4. **Zero Loading**: hoy solo se usa para **detalle** (Proposals, Items). Las **listas** de Directory/Sales no usan TanStack Query ni warmModuleQueries; si se quiere “precalentar” al cambiar de tab o al mostrar el Dealer filter, haría falta integrar algo equivalente (o no bloquear el fetch por hasHydrated en la primera carga).

---

## 8. Referencias en código

- Scope: `src/hooks/useDealerScope.ts`, `src/hooks/useActiveDealer.ts`, `src/hooks/useActingAsDealer.ts`.
- Dealer filter (solo Super Admin / Admin): `src/components/Layout.tsx` (`showDealerSwitcher`), `src/components/layout/ActingAsSwitcher.tsx`.
- Listas Directory: `src/hooks/useDirectoryContacts.ts`, `src/hooks/useDirectoryCustomers.ts`.
- Listas Sales: `src/hooks/useQuotes.ts`, `src/hooks/useProposals.ts`, `src/hooks/useSalesOrders.ts`.
- Contacts UI (initialLoading, overlays): `src/pages/directory/Contacts.tsx`.
- Zero Loading: `src/lib/zeroLoading.ts`.
- Regla de overlays y skeleton: `.cursor/rules/erp-data-pattern.mdc` (punto 8: skeleton solo cuando `!hasData && isInitialLoading`; si `hasData && isFetching`, overlay “Updating…” y mantener filas).
