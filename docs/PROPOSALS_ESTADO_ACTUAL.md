# Proposals – Estado actual y guía para el equipo

**Última actualización:** Feb 2026

---

## 1. Resumen

El módulo **Sales → Proposals** permite generar propuestas comerciales a partir de una Quote. Una Proposal es un documento editable (overrides por línea, líneas custom, descuento/fee global) que **no modifica** la Quote. El flujo está operativo: lista, detalle, creación desde Quote, dos formatos de impresión y logo del dealer.

---

## 2. Tablas y esquema

### 2.1 `Proposals` (cabecera)

| Columna | Tipo | Descripción |
|--------|------|-------------|
| id | uuid | PK |
| organization_id | uuid | FK Organizations |
| quote_id | uuid | FK Quotes (origen) |
| dealer_id | uuid | FK Dealers |
| customer_id | uuid | FK DirectoryCustomers (copiado del Quote, editable) |
| contact_id | uuid | FK DirectoryContacts (copiado del Quote, editable) |
| proposal_no | text | Ej: `QT-000001-P1` |
| status | enum | draft, sent, accepted, rejected, cancelled |
| version_no | int | Por quote_id (1, 2, 3…) |
| currency | text | Default USD |
| global_discount_pct | numeric | Descuento global (%) |
| global_fee_amount | numeric | Fee fijo |
| notes, valid_until | text/date | |
| subtotal_amount, total_amount | numeric | Opcionales; pueden venir de trigger/sync |
| created_by_user_id / created_by_portal_user_id | uuid | Auditoría |
| deleted, created_at, updated_at | | |

- **Relación:** 1 Quote → N Proposals (por versión).
- **Índice único:** `(quote_id, version_no)` WHERE deleted = false.

### 2.2 `ProposalLines` (líneas)

| Columna | Tipo | Uso |
|--------|------|-----|
| id, proposal_id, organization_id, dealer_id | | |
| line_type | enum | `from_quote` \| `custom` |
| quote_line_id | uuid | Obligatorio si line_type = from_quote (FK QuoteLines) |
| override_mode | enum | inherit, discount_pct, markup_pct, fixed_unit_price, fixed_line_total |
| discount_pct, markup_pct, fixed_unit_price, fixed_line_total | numeric | Según override_mode |
| description, qty, unit_price, custom_category | | Para line_type = custom |
| sort_order, deleted, created_at, updated_at | | |

- **from_quote:** precio base del QuoteLine (msrp o unit_msrp×qty); el override aplica sobre ese base.
- **custom:** descripción + qty + unit_price; categoría (installation, delivery, service, other).
- **Trigger:** valida que `quote_line_id` pertenezca al Quote de la Proposal.

### 2.3 `Dealers.logo_url`

- **Migración:** `20260208_dealers_logo_url.sql` añade `logo_url` (text) a `Dealers`.
- **Uso:** URL pública del logo (p. ej. Supabase Storage). Se muestra en detalle de Proposal y en vista de impresión/PDF (esquina superior izquierda).

---

## 3. Flujo actual

### 3.1 Crear Proposal desde Quote

1. Usuario abre **Quote** (ej. `/sales/quotes/:id/edit`).
2. Botón **"Create Proposal"** / **"Create New Version"**.
3. `createProposalFromQuote(quoteId)` en `useProposals.ts`:
   - Lee Quote (organization_id, dealer_id, customer_id, contact_id, currency, quote_no).
   - Calcula siguiente `version_no` para ese quote_id.
   - Inserta **Proposal** (customer_id y contact_id copiados del Quote).
   - Inserta **ProposalLines** con line_type = from_quote, quote_line_id = cada QuoteLine, override_mode = inherit, sort_order conservado.
4. Redirección a `/sales/proposals/:id`.

### 3.2 Lista de Proposals (`/sales/proposals`)

- **Datos:** `useProposalsList()` → Proposals + DirectoryCustomers (nombre) + Quotes (quote_no).
- **Fallback cliente:** Si la Proposal no tiene `customer_id` pero sí `quote_id`, se muestra el customer_name del Quote.
- **Columnas:** Proposal/Quote, Status, Customer, Total, Date, Actions (Ver, Ir a Quote).
- **Filtros:** chips por status (Draft, Sent, Accepted, Rejected, Cancelled).
- **Búsqueda:** por número, cliente, quote.
- **Total:** viene de `Proposals.total_amount`; si es null se muestra "—". No se recalcula en tiempo real en la lista.

### 3.3 Detalle de Proposal (`/sales/proposals/:id`)

- **Datos:** `useProposalDetail(proposalId)` → Proposal, ProposalLines, **QuoteLines en vivo** (por quote_line_id), Quote, DirectoryCustomers, DirectoryContacts.
- **Contenido de líneas from_quote:** Los detalles (nombre producto, medidas, precios base) se leen **desde QuoteLines en tiempo real**, no hay snapshot persistido. Si la Quote o sus QuoteLines se editan o borran después, la vista de la Proposal refleja el estado actual. Si se quisiera que la Proposal muestre siempre el contenido “tal como estaba al crear la propuesta”, haría falta persistir una copia (snapshot) al crear/editar la Proposal.
- **Fallback cliente/contacto:** Si la Proposal no tiene customer_id/contact_id, se usan los del Quote.
- **Header:** Proposal No, Status, Valid until, Notes, Global discount %, Fee. Logo del dealer (si `Dealers.logo_url`) a la izquierda.
- **Líneas:**
  - **from_quote:** producto (name/sku), medidas (width_m × height_m), qty (solo lectura), base (msrp o unit_msrp×qty), override (dropdown + un solo input según modo), line total. Si no hay base → "—" y tooltip de aviso.
  - **custom:** descripción, categoría, qty, unit price, line total. Validación: descripción no vacía, qty/unit_price válidos (si no, borde rojo y "Generate PDF" deshabilitado en el pasado; ahora la acción es imprimir).
- **Totales:** Subtotal, descuento global (%), fee, total. Moneda desde `proposal.currency`. Aviso si total = 0 y hay líneas from_quote (base price missing).
- **Acciones:** Save (header), Mark as Sent, Mark as Accepted, **PDF - Interno (Detalle)**, **PDF - Cliente (Simplificado)** (abren pestaña de impresión).

### 3.4 Vista de impresión (`/sales/proposals/:id/print?mode=internal|customer`)

- **Sin Layout:** la ruta se renderiza sin sidebar/topbar (pestaña limpia).
- **Datos:** mismo `useProposalDetail`; opcional Organization name y logo del dealer.
- **mode=internal:** tabla tipo Quote Lines: #, Product, Collection, System Drive, Measurements, Qty, Base, Override, Line total; custom al final con categoría.
- **mode=customer:** tabla simplificada: #, Description, Qty, Unit price, Line total; sin medidas.
- **Totales y disclaimer:** Subtotal, discount, fee, total (con currency). Customer: "Prices valid until …"; Internal: "Internal use only."
- **Impresión:** botón "Print" visible en pantalla; al imprimir (`window.print()`) el botón se oculta vía CSS. No hay servidor PDF; es HTML + impresión del navegador.

### 3.5 Logo del dealer

- **Dealer Detail (Settings):** después de "Dealer Users", sección **Dealer Logo** con componente **ImageUpload** (mismo que Items): drag and drop o clic, subida a Supabase Storage **bucket `catalog-images`**, path `dealer-logos/{organizationId}/{dealerId}/{timestamp}-{random}.{ext}`. La URL se guarda en `Dealers.logo_url`.
- **Proposal:** en detalle y en print se carga `Dealers.logo_url` por `proposal.dealer_id` y se muestra en la esquina superior izquierda.
- **Dónde está guardada la imagen:** ver [DEALER_LOGO_STORAGE.md](./DEALER_LOGO_STORAGE.md) (bucket, path, CORS, políticas).

---

## 4. Archivos relevantes

| Área | Archivos |
|------|----------|
| **Hook / datos** | `src/hooks/useProposals.ts` (list, detail, createProposalFromQuote) |
| **Tipos** | `src/types/proposals.ts` |
| **Lista** | `src/pages/sales/Proposals.tsx` |
| **Detalle** | `src/pages/sales/ProposalDetail.tsx` |
| **Impresión** | `src/pages/sales/ProposalPrint.tsx` |
| **Rutas** | `src/App.tsx` (proposals, proposal-detail, proposal-print sin Layout) |
| **Creación desde Quote** | `src/pages/sales/QuoteNew.tsx` (CreateProposalButton + createProposalFromQuote) |
| **Logo dealer** | `src/pages/settings/DealerProfileForm.tsx` (ImageUpload), `src/components/ui/ImageUpload.tsx` |
| **Migraciones** | `database/migrations/20260207_proposals_mvp.sql`, `20260208_dealers_logo_url.sql` |

---

## 5. Lo que está funcionando

- Crear Proposal desde Quote (customer/contact copiados).
- Lista con filtros, búsqueda, paginación, customer (con fallback desde Quote), total (desde BD).
- Detalle con líneas from_quote y custom, overrides, totales, avisos de base price.
- Mark as Sent / Mark as Accepted (cambio de status).
- Dos formatos de impresión (interno y cliente) en nueva pestaña; impresión vía navegador.
- Logo del dealer: subida por drag and drop en Dealer Detail, visualización en Proposal y en print.

---

## 6. Qué puede hacer falta para el equipo

### 6.1 Total en lista

- **Situación:** La columna Total usa `Proposals.total_amount`. Si ese campo no se actualiza en BD, en la lista puede verse "—".
- **Opciones:**  
  - **A)** Trigger o job que recalcule y actualice `subtotal_amount` / `total_amount` al guardar Proposal o ProposalLines.  
  - **B)** Calcular total en el front solo para la lista (requiere cargar ProposalLines y QuoteLines para cada Proposal; puede ser costoso).  
  - **C)** Dejar como está y documentar que total_amount debe rellenarse por proceso batch o trigger si se desea ver en lista.

### 6.2 Storage y RLS para dealer logos

- Los logos se suben al bucket `catalog-images` con prefijo `dealer-logos/{orgId}/{dealerId}/`.
- **Comprobar:** políticas RLS del bucket que permitan a la org (o al dealer) escribir/leer en ese prefijo. Si el bucket solo tenía políticas para paths de catálogo, puede hacer falta una política para `dealer-logos/*`.

### 6.3 Sincronizar total_amount al guardar

- Si se quiere que `Proposals.total_amount` refleje siempre el total calculado (subtotal - discount + fee), hace falta:
  - O bien un trigger en `ProposalLines` y en `Proposals` (al cambiar global_discount_pct / global_fee_amount) que recalcule y actualice `Proposals.subtotal_amount` y `Proposals.total_amount`.
  - O bien que el front, al guardar header o líneas, llame a un RPC que recalcule y actualice la Proposal.

### 6.4 Quote Approved eliminado

- La pestaña/ruta "Quote Approved" se eliminó. Si en el futuro se quiere un listado de Quotes aprobadas, habría que recuperar una vista o ruta equivalente (sin reutilizar el componente antiguo si ya no existe).

### 6.5 PDF servidor (opcional)

- Hoy no se usa el endpoint `/api/proposals/[id]/pdf`; la “impresión” es HTML + `window.print()`.
- Si se requiere PDF generado en servidor (ej. para enviar por email o adjuntar), haría falta implementar ese endpoint (p. ej. con una lib de PDF) y, si aplica, enlazarlo desde el botón "PDF - Cliente" o similar.

### 6.6 Snapshot vs datos en vivo

- Hoy **no hay snapshot** de Quote/QuoteLines en la Proposal: el detalle (producto, medias, precios base) se obtiene leyendo QuoteLines en vivo. Para que la Proposal muestre siempre el contenido fijado en el momento de creación, habría que persistir una copia (p. ej. en ProposalLines o en una tabla de snapshot) al crear o confirmar la Proposal.

### 6.7 Permisos (canWrite)

- El detalle usa `canWrite` para habilitar/deshabilitar edición y acciones (Save, Mark as Sent, Mark as Accepted). Generate PDF / imprimir está disponible aunque no se pueda editar. Revisar que RLS de Proposals y ProposalLines esté alineado con el rol (org vs dealer) que se usa para `canWrite`.

---

## 7. Checklist rápido para nuevos desarrollos

- [ ] Si se añaden columnas a Proposals/ProposalLines, actualizar `src/types/proposals.ts` y los `select` en `useProposals.ts`.
- [ ] Si se cambia el cálculo de totales, mantener consistencia entre ProposalDetail, ProposalPrint y cualquier trigger que escriba total_amount.
- [ ] Proposals no modifican Quote ni QuoteLines; solo referencian quote_id y quote_line_id.
- [ ] Logo dealer: path en storage `dealer-logos/{organizationId}/{dealerId}/...`; bucket `catalog-images`; política de storage para ese prefijo si hace falta.
