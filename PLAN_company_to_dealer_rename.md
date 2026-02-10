# Plan: Company → Dealer (DB + UI)

Objetivo: Renombrar todo **Company / company_id** a **Dealer / dealer_id** (y **CompanyPortalUsers** → **DealerUsers**) para evitar confusión con "Organization".

---

## 1. Base de datos

### 1.1 Tablas y columnas

| Antes | Después |
|-------|---------|
| `Companies` | `Dealers` |
| `company_no` | `dealer_no` |
| `company_name` | `dealer_name` |
| `company_email` | `dealer_email` |
| `company_phone` | `dealer_phone` |
| `CompanyPortalUsers` | `DealerUsers` |
| `company_id` (en DealerUsers y resto) | `dealer_id` |

**Organizations:** `next_company_no` → `next_dealer_no`, `company_no_prefix` → `dealer_no_prefix`. Constraint `organizations_company_no_prefix_chk` → `organizations_dealer_no_prefix_chk`.

**Tablas con `company_id` → `dealer_id`:** Quotes, QuoteLines, SalesOrders, ManufacturingOrders, OrderList, DirectoryCustomers, DirectoryContacts.

**Migración de cierre (20260207_company_users_and_branches_dealer_id.sql):**
- `company_users.company_id` → `dealer_id` (FK a Dealers).
- `branches.company_id` → `dealer_id` (FK a Dealers), si la tabla existe.

### 1.2 Funciones

| Antes | Después |
|-------|---------|
| `next_company_no(p_org_id)` | `next_dealer_no(p_org_id)` |
| `set_company_no()` | `set_dealer_no()` |
| `is_company_member(p_company_id)` | `is_dealer_member(p_dealer_id)` |
| `is_company_owner_or_admin(p_company_id)` | `is_dealer_owner_or_admin(p_dealer_id)` |
| `is_company_portal_user(p_company_id)` | `is_dealer_portal_user(p_dealer_id)` |
| `is_company_portal_user_with_write(p_company_id)` | `is_dealer_portal_user_with_write(p_dealer_id)` |
| `get_current_portal_user_company_id()` | `get_current_portal_user_dealer_id()` |
| `get_auth_context()` columna `company_id` | `dealer_id` |
| `get_current_portal_user()` columna `company_id` | `dealer_id` |
| `commit_configured_product_to_quote_line(..., p_company_id, ...)` | `p_dealer_id` |
| `delete_company_portal_user(...)` | `delete_dealer_user(...)` |
| `can_read_company_portal_user(p_portal_row_id)` | **Se elimina** (policy DealerUsers usa lógica inlined) |
| `quote_lines_set_company_id()` | `quote_lines_set_dealer_id()` |
| `quote_lines_validate_company()` | `quote_lines_validate_dealer()` |
| `set_quote_line_company_id()` | **Se elimina** (lógica en `quote_lines_set_dealer_id()`; no existe set_quote_line_dealer_id) |
| `tg_set_company_id_from_portal_user()` | `tg_set_dealer_id_from_portal_user()` |
| `directorycontacts_fill_org_id()` (referencia Companies) | Referencia `Dealers` |
| `enforce_mo_company_matches_salesorder()` | `enforce_mo_dealer_matches_salesorder()` |
| `enforce_orderlist_company_matches_salesorder()` | `enforce_orderlist_dealer_matches_salesorder()` |
| `enforce_salesorders_company_matches_quote()` | `enforce_salesorders_dealer_matches_quote()` |

### 1.3 Triggers

- `trg_companies_set_company_no` → `trg_dealers_set_dealer_no` (en `Dealers`)
- `trg_quote_lines_set_company_id` → `trg_quote_lines_set_dealer_id`
- `trg_quote_lines_validate_company` → `trg_quote_lines_validate_dealer`
- **`trg_set_quote_line_company_id`** → **Se elimina** (lo cubre `trg_quote_lines_set_dealer_id`)
- `trg_quotes_set_company` → `trg_quotes_set_dealer`
- `trg_dircontacts_set_company` / `trg_dircustomers_set_company` / `trg_directorycustomers_set_company` → usar `tg_set_dealer_id_from_portal_user`
- **`trg_directorycontacts_fill_org_id`** → **Recrear** con evento `UPDATE OF dealer_id, organization_id` (función ya referencia Dealers)

### 1.4 RLS

- **Drop** policies antiguas por nombre: `companies_*`, `companyportalusers_*`, **`portal_users_write_owner_admin`**, `quotes_portal_*`, `dircontacts_*` / `dircustomers_*`; luego crear nuevas.
- Policies en `Companies` → `Dealers` usando `is_dealer_member` / `is_dealer_owner_or_admin`.
- Policies en `CompanyPortalUsers` → `DealerUsers` usando `dealer_id` y `is_dealer_*`.
- DirectoryCustomers / DirectoryContacts: condiciones con `dealer_id` e `is_dealer_member`.
- Quotes: condiciones con `dealer_id` e `is_dealer_portal_user*`.

---

## 2. Frontend (UI)

### 2.1 Hooks y store

- `useCompanies` → `useDealers` (tabla `Dealers`)
- `useCompanyPortalUsers` → `useDealerUsers` (tabla `DealerUsers`)
- `useActiveCompany` → `useActiveDealer`
- Store `company-store` → `dealer-store`

### 2.2 Tipos

- `Company` → `Dealer`
- `CompanyPortalUser` → `DealerUser`
- `CreateCompanyInput` / `UpdateCompanyInput` → `CreateDealerInput` / `UpdateDealerInput`

### 2.3 Páginas y rutas

- DealerList, DealerProfileForm, CompaniesSettings: ya usan “Dealer” en UI; cambiar datos a `Dealers` / `dealer_id`.
- QuoteNew y flujo de cotización: `company_id` → `dealer_id`, RPC `commit_configured_product_to_quote_line` con `p_dealer_id`.

### 2.4 Auth / portal

- AuthGate, authContext, SetPassword, portalAccess: leer `dealer_id` y usar `get_current_portal_user_dealer_id()` donde corresponda.
- Llamadas a `get_auth_context`: usar columna `dealer_id` en lugar de `company_id`.
- Eliminación de usuario portal: RPC `delete_dealer_user` en lugar de `delete_company_portal_user`.

---

## 3. Orden de ejecución

1. **Migración SQL** (un solo archivo o por fases): renombres de tablas/columnas, nuevas funciones, triggers, RLS, y reemplazo de `delete_company_portal_user` por `delete_dealer_user`.
2. **Migración de cierre**: ejecutar `20260207_company_users_and_branches_dealer_id.sql` para `company_users` y `branches`.
3. **Frontend**: actualizar hooks, store, tipos, páginas y auth/portal para usar Dealers, DealerUsers y `dealer_id` en todo el flujo. Members.tsx, company-store (CompanyUser.dealer_id), useBranches: usar `dealer_id`. useCompanies y useCompanyPortalUsers: @deprecated, usar useDealers/useDealerUsers.
