# Directory: flujo completo, permisos, columnas y troubleshooting

Documento de referencia para localizar el error **"new row violates row-level security policy for table DirectoryContacts"** y verificar todo el flujo: esquema, permisos, RLS, triggers y frontend.

---

## 1. Resumen del flujo

```
Usuario portal (DealerUsers) → ContactNew.tsx → useDirectoryContacts.createContact()
  → payload con organization_id + dealer_id
  → Supabase INSERT DirectoryContacts
  → Triggers BEFORE INSERT (fill_org_id, set_dealer, set_created_by, audit)
  → RLS WITH CHECK (alguna política INSERT debe pasar)
  → fila insertada
```

Si falla en RLS: o no hay ninguna política INSERT que permita al usuario portal, o las funciones que usan las políticas (`is_org_user_member`, `current_dealer_id`) no consideran DealerUsers / no devuelven lo esperado.

---

## 2. Esquema de tablas (según dump V9)

### 2.1 DirectoryContacts

| Columna | Tipo | Notas |
|--------|------|--------|
| id | uuid | PK, default gen_random_uuid() |
| organization_id | uuid | NOT NULL, FK Organizations |
| dealer_id | uuid | nullable, FK Dealers |
| customer_id | uuid | nullable, FK DirectoryCustomers |
| contact_title | text | |
| contact_name | text | |
| contact_id_number | text | |
| contact_type | contact_type (enum) | architect, interior_designer, etc. |
| contact_primary_phone | text | |
| contact_cell_phone | text | |
| contact_alt_phone | text | |
| contact_email | text | |
| contact_street_address | text | |
| contact_street_address_2 | text | |
| contact_city | text | |
| contact_state | text | |
| contact_zip_code | text | |
| contact_country | text | |
| created_by_user_id | uuid | auth.users (usuarios internos) |
| created_by_portal_user_id | uuid | DealerUsers.id (portal) |
| created_by_email | text | |
| deleted | boolean | default false |
| created_at, updated_at | timestamptz | |
| (+ audit columns) | | created_by_app_user_id, updated_by_*, etc. |

**Importante:** En el dump **no** existen columnas genéricas `name`, `email`, `phone`, `title`. Solo las prefijadas `contact_*`. El frontend debe usar **solo** estas columnas en SELECT e INSERT.

### 2.2 DirectoryCustomers

| Columna | Tipo | Notas |
|--------|------|--------|
| id | uuid | PK |
| organization_id | uuid | NOT NULL |
| dealer_id | uuid | nullable |
| customer_name | text | |
| customer_email | text | |
| customer_phone | text | |
| identification_number | text | |
| customer_type_name | text | contractor, architecture_studio, etc. |
| website | text | |
| alt_phone | text | |
| primary_contact_id | uuid | FK DirectoryContacts |
| street_address_line_1 | text | |
| (+ billing_*, notes, status, deleted, created_at, updated_at, created_by_*) | | |

Tampoco hay columnas `name`, `email`, `phone` genéricas; solo `customer_name`, `customer_email`, `customer_phone`.

### 2.3 DealerUsers (usuarios portal)

| Columna | Tipo | Notas |
|--------|------|--------|
| id | uuid | PK |
| user_id | uuid | FK auth.users (puede ser NULL si aún no aceptó invitación) |
| organization_id | uuid | Organización del dealer |
| dealer_id | uuid | Dealer al que pertenece |
| portal_user_email | text | Email del portal user |
| role | text | 'member' | 'member_manager' |
| status | portal_user_status | active, invited, draft, etc. |
| deleted | boolean | |

RLS SELECT: el usuario puede leer su propia fila con `user_id = auth.uid()` y `deleted = false`. Por tanto el hook puede hacer `.eq('user_id', user.id)` y obtener `organization_id` y `dealer_id`.

### 2.4 Permissions y AppUserRolePermissions (RBAC)

- **Permissions**: `code` (PK), `module`, `description`. Ej: `directory.read`, `directory.write`, `sales.read`, `quotes.edit`.
- **AppUserRolePermissions**: `role_code` (FK AppUserRoles.code), `permission_code` (FK Permissions.code). PK (role_code, permission_code).
- **AppUserRoles**: `code` (PK), `user_type` ('org' | 'dealer'), `name`, etc. Ej: `dealer_member`, `dealer_manager`, `admin`, `member`.

Los usuarios portal (DealerUsers) tienen `role` en la columna `DealerUsers.role` ('member' | 'member_manager'); no se identifican por `AppUserRoles.code` en este flujo. El frontend usa **useAccessContext** y deriva `canEditDirectory` de `userType === "portal"`, no de una consulta a AppUserRolePermissions. Aun así, para coherencia del sistema, `dealer_member` y `dealer_manager` deberían tener en AppUserRolePermissions: `directory.read`, `directory.write`, `sales.read`, `sales.write`, `quotes.edit`; y `dealer_manager` además `quotes.approve`, `quotes.manage`. Migración: `20260209_dealer_roles_permissions.sql`.

---

## 3. Permisos (RBAC) y UI

- **Tabla Permissions:** columna `code` (no `permission_code`). FK desde AppUserRolePermissions es `permission_code` → `Permissions.code`.
- **ContactNew / CustomerNew:** usan `useAccessContext().canEditDirectory`. Para portal: `canEditDirectory = (userType === "portal")`, es decir **siempre true** para cualquier usuario portal. No se consulta AppUserRolePermissions en este flujo para mostrar/ocultar el botón de guardar.
- Si en el futuro se quiere restringir por rol (solo member_manager puede crear contactos), habría que cruzar DealerUsers.role con permisos o con AppUserRolePermissions.

---

## 4. RLS en DirectoryContacts (dump V9)

Hay **varias políticas INSERT** en el dump. Para que el INSERT tenga éxito, la fila debe cumplir **al menos una** (todas son permissivas, se combinan con OR).

| Política | WITH CHECK | ¿Permite usuario portal (DealerUsers)? |
|----------|------------|----------------------------------------|
| **dircontacts_insert** | (organization_id IS NOT NULL AND is_org_user_member(organization_id)) OR (current_dealer_id(organization_id) IS NOT NULL AND (dealer_id IS NULL OR dealer_id = current_dealer_id(organization_id))) | Sí, si is_org_user_member incluye DealerUsers o si current_dealer_id devuelve el dealer del usuario. |
| **directory_contacts_insert** | organization_id = current_app_user_org_id() AND (current_app_user_type() = 'org' OR dealer_id = current_app_user_dealer_id()) | No. Usa JWT `app_user_id` y tabla AppUsers; portal no tiene app_user_id. |
| **directorycontacts_dealer_insert** | organization_id IS NOT NULL AND dealer_id IS NOT NULL AND dealer_id = ANY(current_user_dealer_ids(organization_id)) | Depende de current_user_dealer_ids (suele ser para usuarios org con dealer_id en OrganizationUsers). |
| **directorycontacts_org_insert** | organization_id IS NOT NULL AND is_internal_org_user(organization_id) AND dealer_id IS NULL | No. Solo usuarios internos y dealer_id NULL. |

Conclusión: la única política que puede autorizar a un usuario **portal** es **dircontacts_insert**, y solo si:

1. **is_org_user_member(organization_id)** devuelve true para ese usuario (es decir, la función debe incluir filas de **DealerUsers** con ese organization_id y auth.uid()).
2. O bien **current_dealer_id(organization_id)** devuelve un UUID y (dealer_id IS NULL o dealer_id = ese UUID).

Si en la base solo existen políticas que usan `current_app_user_*` o `is_internal_org_user` / `current_user_dealer_ids`, el portal nunca pasará. Por eso la migración **20260209_fix_directory_insert_rls_portal.sql** elimina el resto de políticas INSERT y deja solo **dircontacts_insert** con la condición que usa `is_org_user_member` + `current_dealer_id`.

---

## 5. Funciones usadas por RLS

### 5.1 is_org_user_member(p_org_id uuid)

- **Debe:** devolver true si el usuario actual es OrganizationUser **o** DealerUser de esa organización (active/invited, no deleted).
- **Si en tu base solo mira OrganizationUsers:** los usuarios portal nunca pasan → INSERT falla.
- **Solución:** ejecutar la migración que hace `CREATE OR REPLACE` incluyendo el `EXISTS (SELECT 1 FROM DealerUsers du WHERE du.organization_id = p_org_id AND du.user_id = auth.uid() ...)`.

### 5.2 current_dealer_id(p_org_id uuid)

- **Debe:** devolver `DealerUsers.dealer_id` para la fila donde organization_id = p_org_id y user_id = auth.uid(), status active/invited.
- **Seguridad:** SECURITY DEFINER para poder leer DealerUsers sin depender de RLS del cliente.
- Si no existe o devuelve NULL para un usuario portal, la segunda rama de dircontacts_insert no se cumple (aunque la primera pueda cumplirse con is_org_user_member).

### 5.3 current_app_user_org_id() / current_app_user_type() / current_app_user_dealer_id()

- Leen de **AppUsers** usando `auth.jwt() ->> 'app_user_id'`. Usuarios portal no tienen esa claim → devuelven NULL u otro valor que no encaja. No deben ser la base única para INSERT de portal.

### 5.4 get_current_portal_user()

- Usada por el trigger **tg_set_dealer_id_from_portal_user**. Devuelve id, organization_id, dealer_id, role, status de DealerUsers donde user_id = auth.uid() o portal_user_email = JWT email. Si el INSERT llega con dealer_id NULL, el trigger puede rellenar dealer_id con este valor.

---

## 6. Triggers en DirectoryContacts (BEFORE INSERT)

| Trigger | Función | Efecto |
|---------|---------|--------|
| trg_directorycontacts_fill_org_id | directorycontacts_fill_org_id | Si organization_id es NULL y dealer_id no es NULL, rellena organization_id desde Dealers. No sobrescribe si organization_id ya viene. |
| trg_dircontacts_set_dealer | tg_set_dealer_id_from_portal_user | Si dealer_id es NULL, intenta asignar dealer_id desde get_current_portal_user(). |
| trg_directorycontacts_set_created_by | set_created_by_fields | Rellena created_by_* según contexto. |
| trg_directory_contacts_audit | set_audit_app_user | Rellena created_by_app_user_id (puede quedar NULL para portal). |

Ninguno borra `organization_id` si ya viene en el payload. El fallo típico es RLS, no los triggers.

---

## 7. Flujo frontend (crear contacto)

1. **ContactNew.tsx**
   - Obtiene `activeOrganizationId` de `useOrganizationContext()`.
   - Obtiene `createContact` de `useDirectoryContacts()` (sin pasar organizationId explícito; el hook usa contexto).
   - Al guardar: `form.getValues()` → objeto con contact_* (sin organization_id ni dealer_id) → `createContact(contactInput)`.

2. **useDirectoryContacts.createContact**
   - Obtiene `user` de `supabase.auth.getUser()`.
   - Consulta **DealerUsers** con `.eq('user_id', user.id)`, `.or('deleted.is.false,deleted.is.null')`, `.in('status', ['active','invited'])`, `.maybeSingle()`.
   - Si hay fila: `portalUserOrganizationId`, `portalUserDealerId`, `createdByPortalUserId`.
   - `effectiveOrgId = activeOrganizationId ?? portalUserOrganizationId ?? null`. Si es null → lanza error "Missing organization_id...".
   - `effectiveDealerId` para portal: `input.dealer_id ?? activeDealerId ?? portalUserDealerId ?? null`.
   - Construye **payload** con organization_id, dealer_id, created_by_*, contact_*, deleted: false.
   - Fuerza de nuevo `payload.organization_id = effectiveOrgId` y `payload.dealer_id = effectiveDealerId`.
   - `console.log('[DirectoryContacts][REAL_INSERT_PAYLOAD]', ...)`.
   - `supabase.from('DirectoryContacts').insert(payload).select(...).single()`.
   - Si error: `console.error('[DirectoryContacts][INSERT_ERROR]', ...)` y log del payload (organization_id, dealer_id).

3. **OrganizationContext**
   - Para portal, si no hay `activeOrganizationId` y el hook tiene `portalUserOrganizationId`, el payload sigue teniendo organization_id (del DealerUser). Pero si el contexto no se ha inicializado y el hook no encuentra DealerUser (p. ej. RLS en DealerUsers impide leer), entonces effectiveOrgId sería null y el hook lanzaría antes del INSERT. Si el error es RLS en DirectoryContacts, el payload sí llega con organization_id y el fallo es en la base.

---

## 8. Dónde puede estar el problema (checklist)

| # | Punto de fallo | Comprobación |
|---|----------------|--------------|
| 1 | Migración RLS no aplicada | En Supabase: listar políticas INSERT de DirectoryContacts. Debe existir solo **dircontacts_insert** con condición que use is_org_user_member Y current_dealer_id. Si existen directory_contacts_insert u otras, o si dircontacts_insert no está, ejecutar **20260209_fix_directory_insert_rls_portal.sql**. |
| 2 | is_org_user_member no incluye DealerUsers | En Supabase: `SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'is_org_user_member';` Debe contener `FROM public."DealerUsers" du` y `du.organization_id = p_org_id` y `du.user_id = auth.uid()`. Si no, misma migración. |
| 3 | current_dealer_id no existe o devuelve NULL | `SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'current_dealer_id';` Debe leer DealerUsers por organization_id y auth.uid(). Si no existe, misma migración. |
| 4 | organization_id llega NULL en el payload | En el navegador: consola → buscar `[DirectoryContacts][REAL_INSERT_PAYLOAD]` y `[DirectoryContacts][INSERT_ERROR] Payload enviado`. Si organization_id es null, el fallo está en contexto (activeOrganizationId) o en la lectura de DealerUsers (RLS en DealerUsers o query incorrecta). |
| 5 | DealerUsers no devuelve fila al hook | El hook hace select en DealerUsers con user_id = auth.uid(). RLS de DealerUsers debe permitir SELECT cuando user_id = auth.uid() y deleted = false. Si no, portalUserOrganizationId queda null; si además activeOrganizationId es null, effectiveOrgId es null y el hook lanza antes del INSERT. |
| 6 | Columna inexistente en INSERT/SELECT | El dump no tiene name, email, phone, title genéricos en DirectoryContacts. El hook ya usa solo contact_*. Si en algún sitio se usan columnas que no existen, el error sería de Postgres (columna no existe), no RLS. |
| 7 | Permisos RBAC (opcional) | Para que dealer_member / dealer_manager tengan directory.write en AppUserRolePermissions: ejecutar **20260209_dealer_roles_permissions.sql**. No es la causa del RLS en INSERT, pero alinea el modelo de permisos. |

---

## 9. Migraciones a ejecutar (orden)

1. **20260209_fix_directory_insert_rls_portal.sql**  
   - Recrea `is_org_user_member` y `current_dealer_id`.  
   - Elimina todas las políticas INSERT de DirectoryContacts y DirectoryCustomers y crea solo **dircontacts_insert** y **dircustomers_insert** con la condición que permite org + portal.

2. **20260209_dealer_roles_permissions.sql**  
   - Inserta permisos en Permissions (directory.read, directory.write, sales.read, sales.write, quotes.edit, quotes.approve, quotes.manage) ON CONFLICT DO NOTHING.  
   - Asigna permisos a dealer_member y dealer_manager en AppUserRolePermissions.

---

## 10. Verificación en Supabase (SQL)

Ejecutar en SQL Editor:

```sql
-- Políticas INSERT en DirectoryContacts
SELECT polname, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polrelid = 'public."DirectoryContacts"'::regclass
  AND polcmd = 'a';

-- Definición de is_org_user_member (debe incluir DealerUsers)
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'is_org_user_member';

-- Definición de current_dealer_id
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'current_dealer_id';
```

Archivo de verificación en el repo: **database/migrations/VERIFY_directory_insert_rls.sql**.

---

## 11. Logs en el navegador

- **Antes del INSERT:** `[DirectoryContacts][REAL_INSERT_PAYLOAD]` → comprobar que `organization_id` y, si aplica, `dealer_id` estén presentes.
- **En error:** `[DirectoryContacts][INSERT_ERROR]` y el log adicional con `organization_id` y `dealer_id` del payload.

Si organization_id está presente y el error sigue siendo RLS, el fallo está en la base (políticas o funciones). Si organization_id es null, el fallo está en el frontend/contexto o en la lectura de DealerUsers.

---

## 12. Resumen de archivos clave

| Archivo | Rol |
|---------|-----|
| src/pages/directory/ContactNew.tsx | Formulario; llama createContact(formData) sin organization_id. |
| src/hooks/useDirectoryContacts.ts | build payload (organization_id, dealer_id desde contexto + DealerUsers), INSERT, logs. |
| src/context/OrganizationContext.tsx | Proporciona activeOrganizationId (para portal puede venir de DealerUsers en otro flujo). |
| src/hooks/useAccessContext.ts | canEditDirectory = (userType === 'portal'); no consulta AppUserRolePermissions. |
| database/migrations/20260209_fix_directory_insert_rls_portal.sql | Ajuste RLS INSERT DirectoryContacts/Customers y funciones. |
| database/migrations/20260209_dealer_roles_permissions.sql | Permisos dealer_member / dealer_manager. |
| database/migrations/VERIFY_directory_insert_rls.sql | Consultas de verificación de políticas y funciones. |

Con este documento se puede seguir el flujo de punta a punta y comprobar permisos, columnas y lógica en cada capa para localizar el problema.
