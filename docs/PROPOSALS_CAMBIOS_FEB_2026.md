# Proposals – Cambios realizados (Feb 2026)

**Resumen para el equipo** – Documento de handoff de lo implementado.

---

## 1. Hardening de base de datos

### 1.1 Migración `20260209_proposal_hardening.sql`

- **Enum `custom_category`**
  - Estandarización en `delivery` (no `transportation`).
  - Si la columna usa `proposal_custom_line_category` (MVP): se añaden valores `delivery` y `service` al enum, y se migran filas `transportation` → `delivery`.
  - Si usa `proposal_custom_category` (V2): ya incluye esos valores, no hay cambios.

- **Columnas `subtotal_amount` y `total_amount` en `Proposals`**
  - Se añaden con `ADD COLUMN IF NOT EXISTS` si no existen.

- **Compatibilidad MVP/V2 en `ProposalLines`**
  - Se añaden `qty`, `quantity`, `override_mode`, `deleted` cuando falten para que la función de totales funcione en ambos esquemas.

- **Función `public.recalc_proposal_totals(p_proposal_id uuid)`**
  - Recalcula `subtotal_amount` y `total_amount` desde `ProposalLines` (deleted = false).
  - Líneas custom: `qty * unit_price`.
  - Líneas from_quote: base desde `QuoteLines` (msrp o unit_msrp×quantity) y aplica override_mode (inherit, discount_pct, markup_pct, fixed_unit_price, fixed_line_total).
  - Total = subtotal × (1 − global_discount_pct/100) + global_fee_amount.

- **Triggers**
  - `ProposalLines`: AFTER INSERT/UPDATE/DELETE → `recalc_proposal_totals(proposal_id)`.
  - `Proposals`: AFTER UPDATE OF `global_discount_pct`, `global_fee_amount` → `recalc_proposal_totals(id)`.

- **Backfill**
  - Ejecución única sobre todas las Proposals no borradas para rellenar subtotal y total.

---

## 2. Tipos y UI

### 2.1 `src/types/proposals.ts`

- `ProposalCustomCategory`: `'installation' | 'delivery' | 'service' | 'other'`.
- Comentario aclarando que el estándar en BD es `delivery` (no `transportation`).

### 2.2 UI

- La UI ya usaba solo los valores válidos; no se cambiaron componentes salvo lo mínimo necesario.

---

## 3. Vista de impresión (`ProposalPrint`)

### 3.1 Header estilo Receipt

- Título principal.
- Datos: Proposal number, Quote number, Date, Valid until.
- Logo del dealer arriba a la derecha (o placeholder si no hay logo).
- Secciones **From** (dealer/org) y **Bill to** (cliente/contacto) en dos columnas.
- Total destacado y fecha.

### 3.2 Tabla interna (`mode=internal`)

Columnas:

| # | Area | Position | Product type | Collection | System drive | Measurements | Accessories | Qty | MSRP | Total |
|---|------|----------|--------------|------------|--------------|--------------|-------------|-----|------|-------|

- **Measurements**: desde `ConfiguredProduct.config_snapshot.measurements` o fallback a `QuoteLine.width_m` y `QuoteLine.height_m`.
- **Accessories**: desde `config_snapshot.accessories`, con formateo tolerante a arrays y objetos.
- Uso de `formatDimensionsDisplayCompact` (mismo helper que QuoteLines).

### 3.3 Tabla cliente (`mode=customer`)

- Sin columna Measurements.
- Columnas: #, Description, Qty, Unit price, Amount.

---

## 4. ConfiguredProduct en Proposals

### 4.1 `useProposalDetail` (`src/hooks/useProposals.ts`)

- **QuoteLines select**: se incluye `configured_product_id`.
- **Carga en batch de ConfiguredProducts**: para todas las QuoteLines con `configured_product_id`, se hace `from('ConfiguredProducts').select('id, config_snapshot').in('id', ids)`.
- **`configuredProductsMap`**: `Record<string, { config_snapshot }>` por id de ConfiguredProduct.
- **Merge en `quoteLinesMap`**: cada QuoteLine con `configured_product_id` recibe `config_snapshot` en su entrada.

### 4.2 `QuoteLineInfoForPDF`

- Nuevos campos: `configured_product_id`, `config_snapshot`.

### 4.3 `ProposalPrint` (modo internal)

- Para cada línea from_quote:
  - `snap = ql.config_snapshot ?? configuredProductsMap[ql.configured_product_id]?.config_snapshot`.
  - **Measurements**: `formatDimensionsDisplayCompact(snap?.measurements ?? { width_m, height_m })` (multi-panel soportado).
  - **Accessories**: `formatAccessoriesFromSnapshot(snap?.accessories)`.

### 4.4 Tolerancia en formateo

- **Accessories**: acepta `string[]`, `{ name, qty }[]`, objetos `{ [key]: value }`; si no hay datos, muestra `"—"`.
- **Measurements**: depende del tipo de producto; se usa lo disponible y fallback a `"—"`.

---

## 5. Snapshot vs datos en vivo

- El contenido de la Proposal (producto, medidas, precios base de líneas from_quote) se obtiene leyendo **QuoteLines en vivo**.
- No hay snapshot persistido de Quote/QuoteLines en la Proposal.
- Si se quiere fijar el contenido “tal como al crear la propuesta”, haría falta persistir una copia al crear o confirmar la Proposal.
- Detalles en `docs/PROPOSALS_ESTADO_ACTUAL.md` (secciones 3.3 y 6.6).

---

## 6. Archivos tocados

| Archivo | Cambios |
|---------|---------|
| `database/migrations/20260209_proposal_hardening.sql` | Nueva migración (enum, recalc_proposal_totals, triggers) |
| `database/migrations/20260210_proposals_snapshot_on_sent.sql` | Nueva migración (quote_line_snapshot, sent_at, freeze_proposal_snapshot, trigger) |
| `src/types/proposals.ts` | Comentario sobre `delivery`, `ProposalLine.quote_line_snapshot`, `QuoteLineSnapshot`, `Proposal.sent_at` |
| `src/hooks/useProposals.ts` | `configured_product_id`, carga ConfiguredProducts, `configuredProductsMap`, merge `config_snapshot` |
| `src/pages/sales/ProposalPrint.tsx` | Header Receipt, logo, tabla interna con Measurements/Accessories; preferir `quote_line_snapshot` cuando existe |
| `docs/PROPOSALS_ESTADO_ACTUAL.md` | Sección 3.3 y 6.6 sobre snapshot vs datos en vivo |

---

## 7. Freeze snapshot on sent (Feb 2026)

### 7.1 Migración `20260210_proposals_snapshot_on_sent.sql`

- **ProposalLines.quote_line_snapshot** (jsonb null): snapshot de QuoteLine + ConfiguredProduct cuando la proposal pasa a 'sent'.
- **Proposals.sent_at** (timestamptz null): fecha en que se marcó como sent.
- **Proposals.snapshot_version** (int default 1): versión del esquema de snapshot.
- **Función `freeze_proposal_snapshot(p_proposal_id uuid)`**: captura snapshot en ProposalLines.quote_line_snapshot. Idempotente: solo actualiza líneas donde quote_line_snapshot es null.
- **Trigger**: AFTER UPDATE OF status ON Proposals, cuando OLD.status='draft' AND NEW.status='sent' → llama a freeze_proposal_snapshot(NEW.id).
- **Backfill**: ejecución única para proposals ya en 'sent'/'accepted' sin snapshot.

### 7.2 ProposalPrint

- Si `line.quote_line_snapshot` existe: usa snapshot (name, sku, qty, area, position, product_type, collection, drive_type, measurements, accessories, base prices).
- Si no: fallback al flujo actual (QuoteLines + ConfiguredProducts en vivo).

### 7.3 Pruebas manuales documentadas

1. Crear proposal en draft, imprimir internal (debe usar datos en vivo).
2. Marcar como "Mark as Sent".
3. Modificar QuoteLine en DB (ej. cambiar name o measurements) para simular cambio posterior.
4. Imprimir internal de nuevo: debe seguir mostrando el snapshot (no los valores actuales de QuoteLine).

---

## 8. Descarga directa de PDF (Feb 2026)

- **Antes:** Los botones "PDF - Interno" y "PDF - Cliente" abrían una vista web (ProposalPrint) con `window.print()`.
- **Ahora:** Descargan directamente un archivo PDF usando jsPDF y `generateProposalPDF`.
- **Variantes:** `internal` (tabla con #, Area, Position, Product, Collection, Drive, Measurements, Accessories, Qty, MSRP, Total) y `customer` (tabla simplificada sin medidas).
- La ruta `/sales/proposals/:id/print` sigue disponible para impresión desde el navegador si se accede directamente.

---

## 9. Pendientes / notas

1. **Migraciones**: ejecutar `20260209_proposal_hardening.sql` y `20260210_proposals_snapshot_on_sent.sql` en el entorno.
2. **ProposalDetail**: usa `handleDownloadPDF` para descarga directa de PDF; mantiene `quoteLinesMap` y `configuredProductsMap` para construir datos.
3. **Accessories**: el formateo es tolerante; si `config_snapshot.accessories` tiene otro formato, se mostrará lo que se pueda o `"—"`.
4. **Batch load de ConfiguredProducts**: se mantiene como fallback cuando no hay quote_line_snapshot.

---

*Documento generado para handoff al equipo. Feb 2026.*
