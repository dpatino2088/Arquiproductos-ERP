# Error RLS DirectoryContacts — Resumen, causas posibles y solución

Error: **"new row violates row-level security policy for table DirectoryContacts"** al crear un contacto en `/directory/contacts/new` como usuario portal (DealerUsers, Member Manager).

---

## 1. Qué hay actualmente

### 1.1 Base de datos (según dump V9 y migraciones)

| Elemento | Descripción |
|----------|-------------|
| **Políticas INSERT** | En el dump hay **varias** políticas INSERT sobre `DirectoryContacts`. Para que el INSERT sea permitido, la fila debe cumplir **al menos una** (PostgreSQL las combina con OR). |
| **dircontacts_insert** | `(organization_id IS NOT NULL AND is_org_user_member(organization_id)) OR (current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = current_dealer_id(organization_id)))`. Es la que permite a portal users si envían `organization_id` y opcionalmente `dealer_id`. |
| **directory_contacts_insert** | Usa `current_app_user_org_id()` y `current_app_user_type()` (tabla **AppUsers**). Si el usuario portal **no** está en `AppUsers`, esta policy no permite el insert. |
| **Otras INSERT** | `directorycontacts_dealer_insert`, `directorycontacts_org_insert` — pensadas para internos o dealer_id desde OrganizationUsers. |
| **is_org_user_member(p_org_id)** | Devuelve true si el usuario está en OrganizationUsers o DealerUsers para esa org (active/invited, no deleted). |
| **current_dealer_id(p_org_id)** | Devuelve `DealerUsers.dealer_id` para esa org y `auth.uid()`, o NULL. |
| **Triggers BEFORE INSERT** | `trg_dircontacts_set_dealer` (rellena `dealer_id` desde portal user), `trg_directorycontacts_fill_org_id` (rellena `organization_id` desde Dealers si ya hay `dealer_id`). Si el trigger no obtiene portal user, no rellenan nada. |

### 1.2 Frontend (hooks)

| Archivo | Comportamiento actual |
|---------|------------------------|
| **useDirectoryContacts.ts** | Obtiene DealerUser con `id, dealer_id, organization_id`. Calcula `effectiveOrgId = activeOrganizationId ?? portalUserOrganizationId`. Si no hay org, lanza error antes de insertar. Payload incluye `organization_id: effectiveOrgId` y `dealer_id: effectiveDealerId` (portal o acting-as). Log en DEV: `[DirectoryContacts insert payload]` con el payload completo. |
| **useDirectoryCustomers.ts** | Mismo patrón para clientes. |
| **OrganizationContext** | Carga orgs desde OrganizationUsers o, si no hay, desde DealerUsers. Para portal, usa `organization_id` de DealerUsers y pone `activeOrganizationId` (o desde localStorage). |

### 1.3 Migraciones relevantes

| Migración | Contenido |
|-----------|-----------|
| **20260209_fix_directory_insert_rls_portal.sql** | Crea/actualiza `is_org_user_member`, `current_dealer_id` (CREATE OR REPLACE). Crea políticas `dircontacts_insert` y `dircustomers_insert` con la rama `dealer_id IS NULL OR dealer_id = current_dealer_id(organization_id)`. |
| **20260218_directory_rls_insert_fix_portal.sql** | Alternativa que solo recrea las políticas INSERT con `is_org_user_member` (sin rama dealer_id NULL). |

---

## 2. Posibles causas del error (checklist)

### A) La policy `dircontacts_insert` no existe o no está aplicada en producción

- Si en la base **solo** existen políticas que usan `current_app_user_org_id()` (AppUsers) y el usuario portal **no** está en AppUsers, **todas** las políticas INSERT fallan.
- **Comprobar en Supabase SQL:**  
  `SELECT polname, polcmd, pg_get_expr(polwithcheck, polrelid) AS with_check FROM pg_policy WHERE polrelid = 'public."DirectoryContacts"'::regclass ORDER BY polname;`  
  (en Postgres, `polcmd = 'a'` suele ser INSERT; si no ves columna polcmd, listar todas y buscar las que tengan WITH CHECK y nombre tipo dircontacts_insert / directory_contacts_insert).

### B) Migración 20260209 no ejecutada en el proyecto donde falla

- Si la base que usa la app (local o remota) **no** ha ejecutado `20260209_fix_directory_insert_rls_portal.sql`, no existirá la policy que permite portal con `organization_id` + `is_org_user_member` o `current_dealer_id`.
- **Solución:** Ejecutar esa migración en la base correspondiente (Supabase SQL Editor o tu runner de migraciones).

### C) Payload sin `organization_id` en el request real

- Aunque el hook construye `organization_id: effectiveOrgId`, podría ser que:
  - `activeOrganizationId` y `portalUserOrganizationId` sean null (ej. query a DealerUsers falla por RLS o no devuelve fila).
  - El código que corre en el navegador no es el actual (caché, build viejo).
- **Comprobar:** En la consola del navegador (DEV), al guardar, debe aparecer `[DirectoryContacts insert payload]` con `organization_id` distinto de null. En la pestaña Network, el body del POST a `DirectoryContacts` debe incluir `"organization_id": "<uuid>"`.

### D) RLS en DealerUsers impide que el portal user lea su fila

- Si el usuario no puede hacer SELECT en su fila de DealerUsers, el hook no obtiene `organization_id` ni `dealer_id` y `effectiveOrgId` podría ser null (y se lanzaría el error “Missing organization_id”) **o** no se detecta como portal y se envía otra combinación que no cumple la policy.
- **Comprobar:** En consola, si hay error “Missing organization_id” es que ni contexto ni DealerUsers dieron org. Revisar políticas SELECT en `DealerUsers` para `user_id = auth.uid()` (p. ej. `dealerusers_select_stable`, `companyportalusers_select`).

### E) `auth.uid()` en el backend distinto al usuario que ve la UI

- Las funciones RLS usan `auth.uid()`. Si la petición llega con otro JWT (o sin JWT), `is_org_user_member(organization_id)` y `current_dealer_id(organization_id)` pueden devolver false/NULL.
- **Comprobar:** Que la app use la clave **anon** (o authenticated) de Supabase con el JWT del usuario logueado, no service_role para ese flujo.

### F) Varias políticas INSERT y conflicto

- En el dump hay varias políticas INSERT. En PostgreSQL, con varias políticas para el mismo comando, la fila debe pasar **al menos una**. Si **todas** exigen cosas que el portal user no cumple (ej. solo AppUsers o solo internos), el insert falla.
- **Solución:** Tener una policy explícita para portal: `dircontacts_insert` con la condición que usa `is_org_user_member` y `current_dealer_id`, y asegurarse de que esté aplicada (migración 20260209).

### G) Tipo de policy / nombre de tabla

- Policy definida para otra tabla o para otro comando (SELECT/UPDATE en vez de INSERT). O typo en el nombre de la policy en la migración.
- **Comprobar:** En `pg_policy`, que la policy sea sobre `public."DirectoryContacts"` y que sea para INSERT (polcmd 'a' en Postgres).

---

## 3. Solución más probable (orden recomendado)

### Paso 1: Asegurar que la policy correcta existe en la base que usa la app

1. Conectar a la **misma base** que usa `localhost:5173` (Supabase project o local).
2. Ejecutar:

```sql
-- Listar todas las políticas INSERT en DirectoryContacts
SELECT polname, polcmd, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polrelid = 'public."DirectoryContacts"'::regclass
ORDER BY polname;
```

3. Debe existir una policy (por ejemplo **dircontacts_insert**) cuyo `with_check` contenga:
   - `organization_id IS NOT NULL` y `is_org_user_member(organization_id)`, **o**
   - `current_dealer_id(organization_id) IS NOT NULL` y `(dealer_id IS NULL OR dealer_id = current_dealer_id(organization_id))`.

4. Si **no** existe esa policy, ejecutar la migración:

```bash
# Desde el repo, ejecutar el contenido de:
# database/migrations/20260209_fix_directory_insert_rls_portal.sql
```

en el SQL Editor de Supabase (o con tu runner de migraciones) sobre esa base.

### Paso 2: Confirmar qué envía el frontend

1. Con la app en **modo desarrollo**, ir a `/directory/contacts/new`, rellenar y guardar.
2. En la **consola** del navegador, revisar el log `[DirectoryContacts insert payload]`:
   - Debe aparecer `organization_id` con un UUID (no null).
   - Idealmente `dealer_id` con UUID para portal.
3. En **Network**, inspeccionar el request POST a `rest/v1/DirectoryContacts`:
   - Request body debe incluir `"organization_id": "<uuid>"`.

Si aquí `organization_id` es null, el fallo está en el frontend/contexto/DealerUsers (ver causas C y D).

### Paso 3: Probar las funciones RLS con el mismo usuario

En Supabase SQL Editor (o psql) con la misma base:

```sql
-- Sustituir <AUTH_USER_ID> por auth.users.id del usuario con el que falla (Member Manager).
-- Sustituir <ORG_ID> por el organization_id que debería tener ese usuario (el de su DealerUser).

SELECT set_config('request.jwt.claims', '{"sub":"<AUTH_USER_ID>"}', true);

SELECT public.is_org_user_member('<ORG_ID>'::uuid);   -- debe ser true
SELECT public.current_dealer_id('<ORG_ID>'::uuid);    -- debe devolver un uuid (dealer_id)
```

Si `is_org_user_member` es false o `current_dealer_id` es NULL, el problema está en datos (DealerUsers/OrganizationUsers) o en cómo se resuelve `auth.uid()` en ese contexto (E).

### Paso 4: Ajustar solo si hace falta

- Si la policy no existe → aplicar migración **20260209** (Paso 1).
- Si el payload no lleva `organization_id` → revisar OrganizationContext y RLS de DealerUsers (causas C, D); el hook ya tiene fallback con `portalUserOrganizationId`, asegurar que la query a DealerUsers devuelva fila.
- Si las funciones devuelven false/NULL en SQL pero el usuario sí está en DealerUsers → revisar `auth.uid()` / JWT (E) y que la app no use service_role para ese flujo.

---

## 4. Resumen en una frase

El error aparece porque la fila que se inserta **no cumple ninguna** de las políticas INSERT de `DirectoryContacts`. Lo más probable es que en la base que usa la app **no esté aplicada la policy `dircontacts_insert`** (migración 20260209) o que el **payload no esté llegando con `organization_id`** (contexto/DealerUsers/caché). Verificar en la base la existencia y texto de las políticas INSERT, y en el navegador el payload y el body del POST; aplicar la migración si falta la policy y depurar contexto/RLS DealerUsers si falta `organization_id`.
