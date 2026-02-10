# Blueprint AppUser v2 — Identidad única + JWT + RLS determinístico

Documento de referencia para el equipo backend. Después se implementa el frontend en función de este diseño.

---

## 1. Objetivo

- **Una sola identidad** en la app: tabla `app_users` (reemplaza OrganizationUsers + DealerUsers).
- **“Quién soy” determinístico**: viene en el JWT (`app_user_id`), no “primera fila” ni `set_config`.
- **ActingAs = impersonation real**: cambiar de cuenta cambia el token (nuevo `app_user_id` en el claim); RLS aplica scope por dealer/org de forma impecable.
- **Auditoría universal**: `created_by_app_user_id`, `updated_by_app_user_id` en tablas clave; triggers que usan `current_app_user_id()`.
- **Permisos** por `app_user_id` (`app_user_permissions`); misma semántica que hoy pero sobre una sola tabla de identidad.

No se toca: Catalog, BOM, Pricing, QuoteLine logic, Manufacturing, Inventory (más allá de RLS/audit), flujos grandes de UI.

---

## 2. Tablas y columnas

### 2.1 `app_users`

Una fila = una “cuenta” en la app (membership): o bien usuario internal en una org, o bien usuario dealer en un dealer de una org. El mismo `auth_user_id` puede tener varias filas (varios dealers, o org + dealer).

| Columna            | Tipo     | Nullable | Descripción |
|--------------------|----------|----------|-------------|
| `id`               | uuid     | NOT NULL | PK, default gen_random_uuid() |
| `organization_id`  | uuid     | NOT NULL | FK a Organizations (o referencia lógica) |
| `user_type`        | text     | NOT NULL | `'org'` \| `'dealer'` |
| `dealer_id`        | uuid     | NULL     | Requerido si user_type = 'dealer'; NULL si 'org' |
| `auth_user_id`     | uuid     | NULL     | auth.users.id cuando el usuario ya tiene sesión (no FK obligatorio) |
| `email`            | text     | NOT NULL | Email normalizado (lowercase) |
| `display_name`     | text     | NULL     | Nombre para mostrar (auditoría, UI) |
| `role_code`        | text     | NOT NULL | Ver sección Roles |
| `status`           | text     | NOT NULL | `invited` \| `active` \| `disabled` |
| `invited_by_app_user_id` | uuid | NULL     | FK app_users(id) |
| `deleted`          | boolean  | NOT NULL | default false |
| `created_at`       | timestamptz | NOT NULL | default now() |
| `updated_at`       | timestamptz | NOT NULL | default now() |
| `must_change_password` | boolean | NULL  | Opcional |
| `temp_password_set_at`  | timestamptz | NULL | Opcional |

**Constraints**

- `CHECK ( (user_type = 'dealer' AND dealer_id IS NOT NULL) OR (user_type = 'org' AND dealer_id IS NULL) )`
- Unicidad (ejemplo):  
  - Org: `UNIQUE (organization_id, user_type, email)` donde `user_type = 'org'` (y dealer_id es null).  
  - Dealer: `UNIQUE (organization_id, user_type, dealer_id, email)` donde `user_type = 'dealer'`.  
  Opcional: mismo unique pero con `auth_user_id` cuando no sea null, para evitar duplicar cuenta por auth.

**Índices recomendados**

- `(auth_user_id)` WHERE deleted = false  
- `(organization_id, user_type, dealer_id)` para listar “mis cuentas” y RLS

---

### 2.2 `app_user_permissions`

Reemplaza `OrganizationUserPermissions`. Permisos granulares por app_user (roles/presets se pueden seguir aplicando al crear/actualizar usuarios).

| Columna           | Tipo   | Nullable | Descripción |
|-------------------|--------|----------|-------------|
| `app_user_id`     | uuid   | NOT NULL | FK app_users(id) ON DELETE CASCADE |
| `permission_code` | text   | NOT NULL | FK permissions(code) |
| `created_at`      | timestamptz | NOT NULL | default now() |

**PK:** `(app_user_id, permission_code)`  
**Unique:** mismo par.

---

### 2.3 `permissions` (existente)

Se mantiene tal cual: `code`, `module`, `description`. Solo se deja de usar `OrganizationUserPermissions` en favor de `app_user_permissions`.

---

### 2.4 `app_user_dealer_access` (Fase 2, opcional)

Para restringir usuarios internal a “solo estos dealers”. MVP: no crear; internal ve toda la org.

| Columna       | Tipo | Nullable | Descripción |
|---------------|-----|----------|-------------|
| `app_user_id` | uuid | NOT NULL | FK app_users(id), solo user_type = 'org' |
| `dealer_id`   | uuid | NOT NULL | FK dealers(id) |

**PK:** `(app_user_id, dealer_id)`

---

## 3. JWT: claim `app_user_id`

- En cada request, el backend (RLS y triggers) debe conocer **un único** `app_user_id`.
- Ese valor viene **solo** del JWT: `auth.jwt() ->> 'app_user_id'`.
- No usar `set_config` (no persiste entre requests en Supabase). No usar “primera fila” en una query.

**Quién pone el claim**

- **Login / refresh normal:** el backend que emite el token (Supabase Auth hook, Edge Function de login, o custom) debe:
  - Resolver el `app_user_id` que corresponde a esa sesión (p. ej. el “principal” del usuario: org por defecto, o el último usado guardado en `user_metadata`).
  - Incluir en el access token un custom claim: `app_user_id` (uuid string).
- **Impersonation (ActingAs):** una Edge Function dedicada (p. ej. `POST /impersonate` o `POST /auth/switch-app-user`) que:
  - Recibe `target_app_user_id`.
  - Valida que el usuario autenticado (`auth.uid()`) está autorizado a usar esa cuenta:
    - Que existe una fila en `app_users` con `id = target_app_user_id` y `auth_user_id = auth.uid()`, **o**
    - Que el usuario es superadmin (p. ej. existe en `app_users` con `role_code = 'superadmin'`) y está permitido impersonar a cualquier cuenta de su org.
  - Devuelve un **nuevo access token** (o refresh que luego se usa para obtener access token) con el claim `app_user_id = target_app_user_id`.
- El frontend guarda y usa ese token como Bearer en todas las llamadas; al cambiar “Dealer Account” se llama a la Edge Function y se reemplaza el token.

---

## 4. Helpers para RLS (solo AppUser)

Todos **STABLE**; los que leen `app_users` con **SECURITY DEFINER** y `search_path = public` para evitar ciclos con RLS.

```sql
-- Lee solo del JWT
create or replace function public.current_app_user_id()
returns uuid
language sql
stable
as $$
  select nullif(trim(auth.jwt() ->> 'app_user_id'), '')::uuid
$$;

-- Derivados desde app_users (SECURITY DEFINER)
create or replace function public.current_app_user_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select organization_id from public.app_users where id = public.current_app_user_id()
$$;

create or replace function public.current_app_user_dealer_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select dealer_id from public.app_users where id = public.current_app_user_id()
$$;

create or replace function public.current_app_user_type()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select user_type from public.app_users where id = public.current_app_user_id()
$$;
```

Opcional: `current_app_user_role_code()` si en alguna policy necesitas distinguir por rol.

---

## 5. RLS universal (fórmula única)

### 5.1 Tablas dealer-scoped

Aplicar a: **DirectoryContacts**, **DirectoryCustomers**, **Quotes**, **QuoteLines**, **Proposals**, **SalesOrders** (y cualquier otra que tenga `organization_id` + `dealer_id` y deba restringirse por dealer).

**Condición estándar (SELECT / INSERT / UPDATE / DELETE):**

- `organization_id = current_app_user_org_id()`
- AND (
  - `current_app_user_type() = 'org'`  
  - OR `dealer_id = current_app_user_dealer_id()`
  )

Así: usuario **org** ve toda la org; usuario **dealer** solo las filas de su `dealer_id`. Sin “primera fila” ni mezcla con OrganizationUsers/DealerUsers.

**Fase 2 (internal solo dealers asignados):**  
Añadir uso de `app_user_dealer_access`: para `user_type = 'org'`, restringir a `dealer_id IN (SELECT dealer_id FROM app_user_dealer_access WHERE app_user_id = current_app_user_id())` (y excepción para superadmin si aplica).

### 5.2 Tablas solo-org

Catalog, BOM, Manufacturing, Warehouses, etc.: solo exigen  
`organization_id = current_app_user_org_id()`.  
(Opcional Fase 2: mismo matiz con `app_user_dealer_access` si tiene sentido.)

### 5.3 Políticas concretas (ejemplo para una tabla dealer-scoped)

- **SELECT:**  
  `organization_id = current_app_user_org_id() AND ( current_app_user_type() = 'org' OR dealer_id = current_app_user_dealer_id() ) AND (deleted = false si aplica)`
- **INSERT:**  
  Mismo criterio en `WITH CHECK`; además puede exigir que si es dealer, `dealer_id = current_app_user_dealer_id()`.
- **UPDATE / DELETE:**  
  Misma condición que SELECT en `USING` y, si aplica, en `WITH CHECK` para UPDATE.

---

## 6. Auditoría universal

### 6.1 Columnas

En cada tabla relevante (DirectoryContacts, DirectoryCustomers, Quotes, QuoteLines, Proposals, SalesOrders, y las que se decida):

- `created_by_app_user_id` uuid NULL  
- `updated_by_app_user_id` uuid NULL  

(FK opcional a `app_users(id)` ON DELETE SET NULL.)

### 6.2 Trigger

- **BEFORE INSERT:**  
  `NEW.created_by_app_user_id := current_app_user_id();`  
  `NEW.updated_by_app_user_id := current_app_user_id();`
- **BEFORE UPDATE:**  
  `NEW.updated_by_app_user_id := current_app_user_id();`  
  (no sobrescribir `created_by_app_user_id`.)

Función única reutilizable por tabla (recibe `TG_TABLE_NAME` implícito por el trigger asociado).

### 6.3 UI

Mostrar “Creado por” / “Actualizado por” con join a `app_users` por `created_by_app_user_id` / `updated_by_app_user_id` y mostrar `display_name` (sin depender de auth.users).

---

## 7. Roles: role_code + user_type

- **user_type = 'org'** → `role_code`: `superadmin`, `admin`, `operator`, `procurement`, `finance`, `member`, `viewer` (alineado con org_role actual).
- **user_type = 'dealer'** → `role_code`: `member`, `member_manager` (o los nombres que uses hoy para portal).

No mezclar en un solo enum; la distinción org/dealer ya la da `user_type`. Presets y permisos se aplican por `role_code`; la UI de permisos sigue mostrando módulos y códigos desde `app_user_permissions`.

---

## 8. Flujo de impersonation (ActingAs)

1. Usuario ya autenticado (`auth.uid()`).
2. Front obtiene “mis cuentas”: p. ej. `SELECT id, user_type, dealer_id, organization_id, display_name FROM app_users WHERE auth_user_id = auth.uid() AND deleted = false AND status IN ('active','invited')`.
3. Si hay más de una, muestra selector (ej. “Dealer Account: Carretero” / “Organización”).
4. Usuario elige una cuenta → front llama **Edge Function** con `target_app_user_id`.
5. Edge Function:
   - Valida que `target_app_user_id` pertenece a `auth_user_id` O que el usuario es superadmin y puede impersonar en esa org.
   - Genera un **nuevo access token** (o indica refresh) con custom claim `app_user_id = target_app_user_id`.
6. Front guarda y usa ese token; todas las peticiones posteriores llevan ese `app_user_id` → RLS aplica scope de esa cuenta (dealer o org).

Con esto, “Dealer Account” es **impersonation real**: el token cambia y la seguridad no depende del frontend.

---

## 9. Orden de migración (sin suicidio)

1. **Crear tablas y helpers**  
   - `app_users` con constraints y uniques.  
   - `app_user_permissions`.  
   - Funciones `current_app_user_id()`, `current_app_user_org_id()`, `current_app_user_dealer_id()`, `current_app_user_type()` (y las que hagan falta).  
   - No borrar aún OrganizationUsers ni DealerUsers.

2. **Migrar datos**  
   - OrganizationUsers → `app_users` (user_type='org', dealer_id=null); guardar mapa `OrganizationUsers.id → app_users.id`.  
   - DealerUsers → `app_users` (user_type='dealer', dealer_id, etc.); guardar mapa `DealerUsers.id → app_users.id`.  
   - OrganizationUserPermissions → `app_user_permissions` usando el mapa.  
   - Asignar permisos por defecto a dealers según role_code si hoy no tienen filas.

3. **Implementar claim en JWT**  
   - En login/refresh: incluir `app_user_id` (resolver cuál es la “cuenta por defecto” del usuario).  
   - Edge Function de impersonation que devuelve token con nuevo `app_user_id`.

4. **Piloto con una tabla: DirectoryContacts**  
   - Añadir `created_by_app_user_id`, `updated_by_app_user_id`.  
   - Trigger de auditoría usando `current_app_user_id()`.  
   - RLS nuevo usando solo helpers `current_app_user_*`.  
   - Backfill de auditoría desde columnas viejas (created_by_user_id / created_by_portal_user_id) usando mapas.  
   - Probar con usuario org y con usuario dealer; verificar que RLS y auditoría se comportan bien.

5. **Escalar**  
   - Repetir el mismo patrón para: DirectoryCustomers, Quotes, QuoteLines, Proposals, SalesOrders (y las que correspondan).  
   - Ir deprecando políticas y columnas viejas según se migre cada tabla.

6. **Apagar legacy**  
   - Dejar de usar OrganizationUsers y DealerUsers en la app; cuando todo esté estable, eliminar o marcar como deprecated.

---

## 10. Resumen de decisiones

| Tema | Decisión |
|------|----------|
| “Quién soy” | JWT claim `app_user_id`; no set_config, no “primera fila”. |
| ActingAs | Impersonation real: cambiar cuenta = nuevo token con otro `app_user_id`. |
| Identidad | Una sola tabla `app_users`; una fila = una cuenta (org o dealer). |
| Permisos | `app_user_permissions(app_user_id, permission_code)`. |
| RLS | Fórmula única: org_id + (user_type = 'org' OR dealer_id = current_dealer_id). |
| Auditoría | created_by_app_user_id / updated_by_app_user_id + trigger. |
| Roles | role_code + user_type; no mezclar en un solo enum. |

---

## 11. Diagrama de flujo por request

```
Frontend request
  └─ Authorization: Bearer <JWT con app_user_id>

Supabase / Postgres
  ├─ auth.uid()           → quien está autenticado
  ├─ auth.jwt() ->> 'app_user_id' → cuenta activa (identidad de app)
  ├─ current_app_user_org_id()   → scope org
  ├─ current_app_user_dealer_id() → scope dealer (null si org)
  └─ RLS policies        → filtran filas por org + dealer

INSERT/UPDATE
  └─ Trigger setea created_by_app_user_id / updated_by_app_user_id
```

Este documento es la referencia para implementar el backend; el frontend se alineará después con este diseño (token, llamada a impersonate, uso de `app_user_id` en sesión, etc.).

---

## 12. Nota: “Created by” en pantallas (portal vs internal)

En esquemas donde coexistan `created_by_user_id` (internal) y `created_by_portal_user_id` (portal):

- **Pantallas ERP (internal)** → mostrar creador vía `created_by_user_id` (join a AppUsers).
- **Pantallas portal dealer** → mostrar creador vía `created_by_portal_user_id` (join a PortalUsers o equivalente).
- **Unificar en una sola columna** (cuando aplique): `created_by = resolved(created_by_user_id) ?? resolved(created_by_portal_user_id) ?? 'Legacy / Imported'`, donde `resolved(id)` es el display_name desde AppUsers o la tabla de portal según el id.
