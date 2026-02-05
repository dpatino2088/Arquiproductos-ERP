# Dónde se calcula el BOM del Breakdown

## 1. Backend (fuente de verdad)

El total del Breakdown (Roll + BOM + labor + accesorios) se calcula en la base de datos en:

**Archivo:** `database/migrations/20260204_bom_preview_snapshot.sql`  
**Función:** `build_bom_preview_snapshot(p_org_id, p_configured_product_id, p_bom_template_id)`

### Construcción de ítems (precios por línea)

- **Líneas ~116-155:** Ítem de **roll/fabric**: MSRP desde `CatalogItemsMSRP`, `line_total = qty * unit_price`.
- **Líneas ~157-334:** Ítems **BOM** (padres e hijos): para cada `BOMComponents` del template con `parent_component_id IS NULL`, se resuelve el `component_item_id` (selección del usuario o default), se obtiene MSRP de `CatalogItemsMSRP`, se calcula `qty` según `qty_type` (per_width, per_height, per_m2, fixed) y `line_total = qty * unit_price`. Los hijos se añaden en `children` con su propio `line_total`.

### Cálculo de totales (a partir de `v_items`)

- **Líneas 348-352:** `v_roll_msrp_total` = suma de `line_total` de ítems con `kind = 'roll'`.
- **Líneas 359-369:** `v_bom_sum` (BOM total) = suma de `line_total` de ítems con `kind = 'parent'` + suma de `line_total` de sus `children`.
- **Líneas 376-386:** Labor y accesorios desde `ConfiguredProducts`; luego  
  `v_total_msrp := v_roll_msrp_total + v_bom_sum + v_labor_amount + v_accessories_total`.
- **Líneas 387-406:** Se arma el JSONB `totals` (incluye `total_msrp`, `roll_msrp_total`, `bom_total`, etc.) y el objeto que se devuelve tiene `totals` e `items`.

Ese resultado es el **bom_preview_snapshot** que se guarda en `ConfiguredProducts.bom_preview_snapshot` y se devuelve en la RPC `create_configured_product_and_bom_preview`.

---

## 2. Cuándo se llama a `build_bom_preview_snapshot`

- En **create_configured_product_and_bom_preview** (mismo archivo, líneas ~550-558): después de insertar el `ConfiguredProduct` y llamar a `calculate_configured_product_totals`, se llama a `build_bom_preview_snapshot` y se hace `UPDATE ConfiguredProducts SET bom_preview_snapshot = v_preview_snapshot`.
- En el frontend, eso ocurre **solo cuando el usuario hace clic en "Add to Quote"** en el configurador: se llama a `createConfiguredProductPreview()` en `src/lib/bom/createConfiguredProductPreview.ts`, que invoca la RPC `create_configured_product_and_bom_preview`. La respuesta incluye `bom_preview_snapshot` con ese `totals.total_msrp`.

---

## 3. Frontend – dónde se muestra el Breakdown

**Archivo:** `src/pages/sales/curtain-config/ReviewStep.tsx`

- **Origen del total mostrado:**
  - Si existe **config.bom_preview_snapshot** (válido, con `version === '1'` e `items.length > 0`):
    - **snapshotTotal** = `bomPreviewSnapshot.totals.total_msrp` (líneas 194-200).
    - **breakdownTotal** = ese `snapshotTotal` (líneas 438-445).
  - Si **no** hay snapshot válido:
    - Se usa el fallback **loadBreakdown()** (líneas 211-434): se cargan componentes desde `BOMComponents` y precios desde `CatalogItems`/MSRP, se construye `breakdownLines` y **breakdownTotal** = suma de `line.totalPrice` de esas líneas.

- **Dónde se pinta en UI:**
  - Con snapshot: en el pie de tabla se muestra “Total MSRP” = `snapshotTotals.total_msrp` (líneas 707-752).
  - Sin snapshot: se muestra “Subtotal (BOM):” = `breakdownTotal` (líneas 756-762).

Importante: en el paso Review, **antes** de hacer clic en “Add to Quote”, normalmente **no** hay `bom_preview_snapshot` en el config (el preview se crea al hacer clic). Entonces el total que ves en esa pantalla suele venir del **fallback** (loadBreakdown). El total que debe persistirse en la QuoteLine es el que devuelve **build_bom_preview_snapshot** en el momento del “Add to Quote”.

---

## 4. Resumen del flujo del valor que debe guardarse

1. Usuario hace clic en **Add to Quote** → se llama `createConfiguredProductPreview()` → RPC **create_configured_product_and_bom_preview**.
2. En la RPC se crea el `ConfiguredProduct`, se llama **build_bom_preview_snapshot** y se guarda el resultado en `ConfiguredProducts.bom_preview_snapshot`.
3. La RPC devuelve ese `bom_preview_snapshot` (con `totals.total_msrp`).
4. El frontend envía ese config (con snapshot) a `onComplete`; en **QuoteNew** se llama a **commit_configured_product_to_quote_line**, que lee `ConfiguredProducts.bom_preview_snapshot` (y sus `totals`) y debe escribir **QuoteLines.msrp** = ese `total_msrp`.
5. Además, tras el commit, el frontend hace un patch de la QuoteLine recién creada con el `total_msrp` del preview en memoria por si la RPC no persistió bien.

Si el MSRP en la QuoteLine sigue en 0, las causas probables son:  
- Que en **commit_configured_product_to_quote_line** no se esté leyendo bien `bom_preview_snapshot.totals.total_msrp` (p. ej. snapshot vacío o con otra estructura), o  
- Que el **ConfiguredProduct** que se lee en el commit sea otro o no tenga aún el `bom_preview_snapshot` actualizado (orden de operaciones / transacciones).
