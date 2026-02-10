# Revisión DUMP — Tabla de Dealers (para DealerTiers)

## Objetivo
Confirmar la tabla real de dealers en el esquema antes de implementar **DealerTiers** y la columna `dealer_tier_id`.

---

## Resultado: tabla de dealers

| Aspecto | Valor |
|--------|--------|
| **Tabla** | `public."Dealers"` |
| **Origen** | Renombrada desde `public."Companies"` en la migración `20260207_rename_company_to_dealer.sql`. |
| **Creación original** | `database/migrations/512_restructure_companies_portal_directory.sql` (como `Companies`). |

---

## Estructura relevante (Dealers)

- **PK:** `id` uuid (default `gen_random_uuid()`).
- **Organización:** `organization_id` uuid NOT NULL → `public."Organizations"(id)`.
- **Columnas de negocio (tras rename):**
  - `dealer_no`, `dealer_name`, `dealer_email`, `dealer_phone`
  - `status`, `deleted`, `created_at`, `updated_at`
- **Constraint:** `dealers_org_required` (CHECK `organization_id IS NOT NULL`).
- **RLS:** Habilitado; políticas por `organization_id` (`is_org_member`, `is_org_owner_or_admin`).

El hook **useDealers** y el front (DealerProfileForm, CompaniesSettings, etc.) usan esta tabla como **Dealers** (select/insert/update por `organization_id`).

No existe tabla alternativa tipo `DealerList`, `DirectoryDealers` ni `DirectoryCustomers` con `type=dealer` como tabla principal de dealers; la entidad “dealer” es **Dealers**.

---

## Uso en el código

- **Hooks:** `useDealers()` → `.from('Dealers')`, filtro por `organization_id`.
- **Otras tablas con FK a dealer:** Quotes, QuoteLines, SalesOrders, ManufacturingOrders, OrderList, DirectoryCustomers, DirectoryContacts, DealerUsers → todas referencian `public."Dealers"(id)` (como `dealer_id`).

---

## Conclusión para DealerTiers

- **Tabla donde agregar `dealer_tier_id`:** `public."Dealers"`.
- **Acción SQL recomendada:**
  ```sql
  ALTER TABLE public."Dealers"
    ADD COLUMN IF NOT EXISTS dealer_tier_id uuid NULL
    REFERENCES public."DealerTiers"(id);
  ```
- **Regla de negocio:** El tier vive en el Dealer; Quote/SalesOrder lo leen desde `Dealer.dealer_tier_id` → `DealerTiers.discount_pct`. Si `dealer_tier_id` es NULL, en runtime tratar como Bronze (por defecto, sin escribirlo en BD).

---

## Referencias en migraciones

| Archivo | Qué hace |
|---------|----------|
| `512_restructure_companies_portal_directory.sql` | Crea `Companies` (id, organization_id, company_*). |
| `20260207_rename_company_to_dealer.sql` | Renombra `Companies` → `Dealers`, columnas company_* → dealer_*, FKs y RLS. |
| `20260207_company_users_and_branches_dealer_id.sql` | company_users/branches.dealer_id → FK a `Dealers`. |

No hay que buscar otra tabla de dealers; **la tabla de dealers es `public."Dealers"`**.
