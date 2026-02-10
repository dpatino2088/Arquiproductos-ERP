# Esquema: dealer_id y user en Directory, Sales y DealerUsers

Verificación según **backups/2026-02_07_V8_full.sql** (dump). En este dump **DirectoryContacts** y **DirectoryCustomers** **sí tienen** `dealer_id` y columnas de usuario/creador.

---

## 1. DirectoryContacts

| Columna | Tipo | Notas |
|---------|------|--------|
| **dealer_id** | uuid | FK a Dealers. Nullable. Índices: idx_dircontacts_company, idx_directorycustomers_company_id. |
| **created_by_user_id** | uuid | FK a auth.users. Quién creó (usuario interno). |
| **created_by_portal_user_id** | uuid | FK a DealerUsers. Quién creó (portal/dealer). |
| created_by_email | text | |
| created_by_dealer_id | uuid | |
| updated_by_user_id | uuid | |
| updated_by_dealer_id | uuid | |
| created_by_app_user_id | uuid | |
| updated_by_app_user_id | uuid | |

Triggers: `trg_dircontacts_set_dealer` (set dealer_id desde portal user), `trg_directorycontacts_set_created_by`, etc.  
FK: `DirectoryContacts_company_id_fkey` → Dealers(id).

---

## 2. DirectoryCustomers

| Columna | Tipo | Notas |
|---------|------|--------|
| **dealer_id** | uuid | FK a Dealers. Nullable. Índices: idx_dircustomers_company, idx_directorycustomers_company_id, idx_directorycustomers_org_company. |
| **created_by_user_id** | uuid | FK a auth.users. |
| **created_by_portal_user_id** | uuid | FK a DealerUsers. |
| created_by_email | text | |
| created_by_dealer_id | uuid | |
| updated_by_user_id | uuid | |
| updated_by_dealer_id | uuid | |

Triggers: `trg_directorycustomers_set_dealer`, `trg_directorycustomers_set_created_by`.  
FK: `DirectoryCustomers_company_id_fkey` → Dealers(id).

---

## 3. Quotes (Sales)

| Columna | Tipo | Notas |
|---------|------|--------|
| **dealer_id** | uuid | Nullable. Usado para scope dealer vs org. |
| **created_by_user_id** | uuid | Usuario interno que creó. |
| **created_by_portal_user_id** | uuid | DealerUsers id si lo creó un portal user. |
| created_by_email | text | |
| created_by_dealer_id | uuid | |
| updated_by_user_id | uuid | |
| updated_by_dealer_id | uuid | |

Índices y RLS usan `dealer_id` para filtrar por dealer.

---

## 4. Proposals (Sales)

| Columna | Tipo | Notas |
|---------|------|--------|
| **dealer_id** | uuid NOT NULL | Obligatorio. |
| **created_by_user_id** | uuid | |
| **created_by_portal_user_id** | uuid | |
| created_by_dealer_id | uuid | |
| updated_by_user_id | uuid | |
| updated_by_dealer_id | uuid | |

Constraint: `proposals_created_by_exactly_one_chk` (uno de created_by_user_id o created_by_portal_user_id).

---

## 5. SalesOrders (Sale Order)

| Columna | Tipo | Notas |
|---------|------|--------|
| **dealer_id** | uuid | Debe coincidir con Quotes.dealer_id (trigger enforce_salesorders_dealer_matches_quote). |
| **created_by_user_id** | uuid | |
| created_by_email | text | |
| created_by_dealer_id | uuid | |
| updated_by_user_id | uuid | |
| updated_by_dealer_id | uuid | |

RLS: políticas por `dealer_id` y `current_user_dealer_ids` / `is_internal_org_user`.

---

## 6. DealerUsers

| Columna | Tipo | Notas |
|---------|------|--------|
| **id** | uuid | PK. Identificador del registro portal (no es “user id” de auth). |
| **user_id** | uuid | FK a auth.users. Usuario de Supabase Auth. |
| **dealer_id** | uuid | FK a Dealers. Dealer al que pertenece este portal user. |
| organization_id | uuid | |
| portal_user_email | text | |
| role | text | member | member_manager |

En la UI de Supabase a veces se muestran menos columnas; en el dump **DealerUsers** tiene `user_id` y `dealer_id`.

---

## Resumen

- **DirectoryContacts:** en el dump **tiene** `dealer_id`, `created_by_user_id`, `created_by_portal_user_id`.
- **DirectoryCustomers:** en el dump **tiene** `dealer_id`, `created_by_user_id`, `created_by_portal_user_id`.
- **Quotes:** **tiene** `dealer_id`, `created_by_user_id`, `created_by_portal_user_id`.
- **Proposals:** **tiene** `dealer_id` (NOT NULL), `created_by_user_id`, `created_by_portal_user_id`.
- **SalesOrders:** **tiene** `dealer_id`, `created_by_user_id`, `created_by_dealer_id`, etc.
- **DealerUsers:** **tiene** `user_id` (auth), `dealer_id` (Dealers).

Si en tu base **production** DirectoryContacts o DirectoryCustomers no tienen `dealer_id`, puede ser:

1. Un dump anterior al que se añadieron esas columnas.
2. Migraciones no aplicadas (por ejemplo las que añaden `dealer_id` o `created_by_*` a Directory*).

Para comprobar en production (Supabase SQL):

```sql
-- ¿DirectoryContacts tiene dealer_id?
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'DirectoryContacts'
  AND column_name IN ('dealer_id', 'created_by_user_id', 'created_by_portal_user_id');

-- ¿DirectoryCustomers tiene dealer_id?
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'DirectoryCustomers'
  AND column_name IN ('dealer_id', 'created_by_user_id', 'created_by_portal_user_id');
```

Si esas columnas no aparecen, hay que aplicar las migraciones que las añaden (o revisar el historial de migraciones del proyecto).

---

## RLS Directory (Contactos / Clientes)

- **INSERT**: Las políticas `dircontacts_insert` y `dircustomers_insert` permiten insertar si el usuario es miembro de la org vía **is_org_user_member(organization_id)** (OrganizationUsers o DealerUsers) o si es portal y `dealer_id = current_dealer_id(organization_id)`. Migración **20260218_directory_rls_insert_fix_portal.sql** cambió la rama "org member" de `is_org_member` a `is_org_user_member` para que los usuarios portal (DealerUsers) puedan crear contactos/clientes sin violar RLS. Los triggers `trg_dircontacts_set_dealer` y `trg_directorycustomers_set_dealer` rellenan `dealer_id` en BEFORE INSERT para usuarios portal.
