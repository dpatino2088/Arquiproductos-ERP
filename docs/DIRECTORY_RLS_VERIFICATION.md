# Verificación RLS Directory (DirectoryContacts / DirectoryCustomers)

Script y notas para depurar "new row violates row-level security policy" al crear contactos/clientes (portal vs internal).

## 1) Obtener WITH CHECK completo de las policies INSERT

Ejecutar en SQL (Supabase o psql):

```sql
-- DirectoryContacts: expresión WITH CHECK de dircontacts_insert
SELECT polname, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polrelid = 'public."DirectoryContacts"'::regclass
  AND polname = 'dircontacts_insert';

-- DirectoryCustomers: expresión WITH CHECK de dircustomers_insert
SELECT polname, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polrelid = 'public."DirectoryCustomers"'::regclass
  AND polname = 'dircustomers_insert';
```

Comprobar que la expresión incluye `dealer_id IS NULL OR dealer_id = public.current_dealer_id(organization_id)` en la rama portal.

## 2) Verificar el usuario que falla por email

Sustituir `:email` por el email del usuario (ej. `'dpv2088@gmail.com'`).

```sql
-- Como DealerUser (portal)
SELECT u.id, u.email,
       du.id AS dealer_user_row_id, du.organization_id, du.dealer_id, du.role, du.status, du.deleted
FROM auth.users u
LEFT JOIN public."DealerUsers" du ON du.user_id = u.id
WHERE lower(u.email) = lower(:email);

-- Como OrganizationUser (internal)
SELECT u.id, u.email,
       ou.organization_id, ou.role, ou.status, ou.deleted
FROM auth.users u
LEFT JOIN public."OrganizationUsers" ou ON ou.user_id = u.id
WHERE lower(u.email) = lower(:email);
```

Interpretación: si el usuario es solo portal, tendrá fila en DealerUsers y `dealer_id`/`organization_id`; si es internal, fila en OrganizationUsers. Si falla el insert, confirmar que `is_org_user_member(organization_id)` o `current_dealer_id(organization_id)` deberían ser true/not null para ese usuario y esa org.

## 3) QA / Verificación post-migración (20260209)

```sql
-- 1) Confirmar que la función existe con param (p_org_id uuid)
SELECT proname, pg_get_function_arguments(oid) AS args
FROM pg_proc
JOIN pg_namespace n ON n.oid = pg_proc.pronamespace
WHERE n.nspname = 'public' AND proname = 'is_org_user_member';

-- 2) Confirmar que la policy tiene dealer_id IS NULL OR dealer_id = ...
SELECT polname, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polrelid = 'public."DirectoryContacts"'::regclass AND polname = 'dircontacts_insert';

-- 3) Lo mismo para DirectoryCustomers
SELECT polname, pg_get_expr(polwithcheck, polrelid) AS with_check
FROM pg_policy
WHERE polrelid = 'public."DirectoryCustomers"'::regclass AND polname = 'dircustomers_insert';
```

## 4) QA: simular JWT y probar current_dealer_id en SQL

En el SQL Editor (Supabase o psql), simular el usuario autenticado y llamar a `current_dealer_id`:

```sql
-- Sustituir <AUTH_USER_ID> por auth.users.id del usuario portal (ej. el que falla al crear contacto).
-- Sustituir <ORG_ID> por organization_id de ese DealerUser.
SELECT set_config('request.jwt.claims', '{"sub":"<AUTH_USER_ID>"}', true);

SELECT public.current_dealer_id('<ORG_ID>'::uuid);
-- Debe devolver el dealer_id (uuid) del DealerUser; si devuelve NULL, el usuario no es portal en esa org o status/deleted no cumple.
```

## 5) Si la UI sigue fallando: revisar payload de insert

El insert a `DirectoryContacts` (y `DirectoryCustomers`) **debe incluir siempre `organization_id` (NOT NULL)**. En el frontend:

- En DEV, la consola ya loguea antes del insert: `[useDirectoryContacts] Insert payload (pre-insert):` con `organization_id`, `dealer_id`, `contact_name`, `contact_email`.
- Comprobar que `organization_id` no llega `null` ni vacío. Si llega null, el WITH CHECK de RLS falla (rama `organization_id IS NOT NULL AND is_org_user_member(organization_id)`).

## Nota

- No usar DROP FUNCTION en `is_org_user_member` ni en `current_dealer_id`: muchas policies RLS dependen de ellas. Solo CREATE OR REPLACE.
- No renombrar el parámetro: Postgres no permite cambiar el nombre del input con CREATE OR REPLACE; debe mantenerse `(p_org_id uuid)`.
- Migración que aplica el fix: `database/migrations/20260209_fix_directory_insert_rls_portal.sql`.
