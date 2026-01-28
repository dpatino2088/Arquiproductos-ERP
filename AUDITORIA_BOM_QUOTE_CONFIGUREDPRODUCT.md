# Auditoría: BOM, Quote y ConfiguredProduct

**Objetivo:** Identificar qué columnas se usan y cuáles no, y de dónde se obtienen/calculan los datos.

---

## 1. BOMInstanceLines

### 1.1 Columnas existentes (según migraciones y tipos)

| Columna | Tipo | En código | Origen del valor |
|---------|------|-----------|------------------|
| `id` | uuid | ✅ | generado |
| `organization_id` | uuid | ✅ | de BOMInstances o parámetro |
| `bom_instance_id` | uuid | ✅ | FK al BOMInstance |
| `part_role` | text | ✅ | de BOMComponents / QuoteLineComponents |
| `resolved_part_id` | uuid | ✅ | CatalogItem elegido (puede ser NULL en algunos flujos) |
| `bom_component_id` | uuid | ⚠️ | referenciado en tipos; poco usado en inserts |
| `qty` | numeric | ✅ | de BOMComponents o QuoteLineComponents |
| `uom` | text | ✅ | CatalogItems.unit_of_measure o 'ea'/'each' |
| `cut_length_mm` | numeric | ⚠️ | **Casi siempre NULL** en inserts. Se rellena por triggers/funciones de engineering rules. |
| `cut_width_mm` | numeric | ⚠️ | **Casi siempre NULL** en inserts. Mismo caso que cut_length_mm. |
| `cut_height_mm` | numeric | ⚠️ | **Casi siempre NULL** en inserts. |
| `unit_cost_exw` | numeric | ✅ | CatalogItems.cost_exw, o `get_unit_cost_in_uom`, o QuoteLineComponents.unit_cost_exw |
| `total_cost_exw` | numeric | ✅ | **Calculado:** `qty * unit_cost_exw` (triggers/INSERT) o se pasa explícito |
| `deleted` | boolean | ✅ | false por defecto |
| `created_at` | timestamptz | ✅ | default |

### 1.2 Desalineación posible: `unit_cost_acu` / `total_cost_acu`

En **Supabase** se ven a veces `unit_cost_acu` y `total_cost_acu`. En el código se usan **siempre** `unit_cost_exw` y `total_cost_exw`. Hay que confirmar en el esquema real de la base si existen columnas `*_acu`; si sí, o se migran a `*_exw` o el frontend debe alinearse.

### 1.3 Columnas que el código pide pero que **no están en el esquema** de BOMInstanceLines

En `ApprovedBOMList.tsx` el `select` incluye:

- `resolved_sku` → **no existe** en BOMInstanceLines; se obtiene de CatalogItems vía `resolved_part_id`.
- `category_code` → **no existe**; se obtiene de CatalogItems.
- `description` → **no existe**; se obtiene de CatalogItems.

Esas columnas fallarán si la tabla no las tiene; el código asume que vienen en la fila o las rellena con `catalogItemById.get(resolved_part_id)`.

### 1.4 Dónde se escriben BOMInstanceLines

| Archivo | Operación | Columnas que se escriben |
|---------|-----------|---------------------------|
| `bomInstance.ts` (`upsertBomLine`, `upsertBomLines`) | INSERT/UPDATE | organization_id, bom_instance_id, part_role, resolved_part_id, bom_component_id, qty, uom, cut_* , unit_cost_exw, total_cost_exw, deleted |
| `createQuoteLineFromRollerConfig.ts` | INSERT (accesorios) | organization_id, bom_instance_id, resolved_part_id, part_role, qty, uom, unit_cost_exw, deleted. **No escribe** total_cost_exw, cut_* |
| Triggers/funciones SQL (`generate_bom_from_quote_line_components`, `203_update_bom_trigger_call_engineering_rules`, etc.) | INSERT | part_role, resolved_part_id, qty, uom, unit_cost_exw, total_cost_exw, cut_* (cuando aplica), organization_id, deleted |

### 1.5 Dónde se calcula `unit_cost_exw` y `total_cost_exw`

- **Triggers/funciones (PL/pgSQL):** `get_unit_cost_in_uom(resolved_part_id, uom, ...)`; si es 0/NULL, se usa `QuoteLineComponents.unit_cost_exw`.  
  `total_cost_exw = qty * unit_cost_exw`.
- **Frontend (bomInstance, createQuoteLineFromRollerConfig):** usa `CatalogItems.cost_exw` o `QuoteLineComponents.unit_cost_exw`; a veces solo `unit_cost_exw`, y `total_cost_exw` puede quedar en NULL si no lo rellena un trigger.

---

## 2. BOMInstances

### 2.1 Columnas y uso

| Columna | En código | Origen |
|---------|-----------|--------|
| `id` | ✅ | generado |
| `organization_id` | ✅ | parámetro |
| `quote_line_id` | ✅ | **Requerido** en el flujo “desde QuoteLine”. Constraint reciente: no crear BOMInstance sin quote_line_id. |
| `bom_template_id` | ✅ | matchBOMTemplate o parámetro |
| `configured_product_id` | ⚠️ | Opcional; para draft/preview antes de tener QuoteLine. En migraciones recientes ya no se crea BOMInstance en el preview (quote_line_id NULL). |
| `deleted` | ✅ | false por defecto |
| `created_at`, `updated_at` | ✅ | default |

### 2.2 Origen de datos

- `bomInstance.getOrCreateBomInstanceForQuoteLine`: lee por `organization_id`, `quote_line_id`, `deleted=false`. Inserta con `organization_id`, `quote_line_id`, `bom_template_id`, `deleted`.
- El RPC `create_configured_product_and_bom_preview` **ya no** crea BOMInstance en el preview; el BOMInstance se crea cuando existe `quote_line_id` (después de crear el QuoteLine).

---

## 3. QuoteLines

### 3.1 Columnas usadas en el código (lectura/escritura)

| Columna | Lectura | Escritura | Origen / Notas |
|---------|---------|-----------|----------------|
| `id` | ✅ | (generado) | |
| `organization_id` | ✅ | ✅ | |
| `quote_id` | ✅ | ✅ | |
| `product_type_id` | ✅ | ✅ | ConfiguredProduct o config |
| `product_type` | ✅ | ✅ | ej. 'configured' |
| `quantity` | ✅ | ✅ | |
| `width_m`, `height_m` | ✅ | ✅ | desde mm (width_mm/1000, height_mm/1000) |
| `area` | ✅ | ✅ | QuoteLineComponents (option) o config |
| `position` | ✅ | ✅ | idem |
| `bom_template_id` | ✅ | ✅ | matchBOMTemplate / createQuoteLineFromConfiguredProduct |
| `discount_pct` | ✅ | ✅ | |
| `roll_cost_snapshot` | ✅ | ✅ | **ConfiguredProducts.roll_total_cost** (o 0) |
| `bom_cost_snapshot` | ✅ | ✅ | **ConfiguredProducts.bom_total_cost** (o 0) |
| `roll_msrp_snapshot` | ✅ | ✅ | **ConfiguredProducts.roll_msrp_total** |
| `bom_msrp_snapshot` | ✅ | ✅ | **ConfiguredProducts.bom_total** (BOM total que incluye hardware; en nomenclatura de ConfiguredProducts suele ser `bom_total`) |
| `labor_pct` | ✅ | ✅ | ConfiguredProducts.labor_pct |
| `total_cost` | ✅ | ✅ | `roll_cost_snapshot + bom_cost_snapshot` |
| `msrp` | ✅ | ✅ | **ConfiguredProducts.roll_plus_bom_total** o `roll_msrp_snapshot + bom_msrp_snapshot` |
| `net_price` | ✅ | ✅ | `msrp * (1 - discount_pct/100)` |
| `pricing_locked` | ✅ | ✅ | false al crear |
| `last_priced_at` | ✅ | ✅ | now() |
| `pricing_version` | ✅ | ✅ | 1 |
| `collection_name` | ✅ | ✅ | Catalog/config |
| `variant_name` | ✅ | ✅ | Catalog/config |
| `metadata` | ✅ | ✅ | p. ej. `configured_product_id` |
| `catalog_item_id` | ✅ | (legacy) | En tipos; en flujo ConfiguredProduct puede ser null. |
| `created_at` | ✅ | (default) | |

### 3.2 Columnas en tipos (catalog.ts) que pueden no usarse o ser legacy

- `list_unit_price_snapshot`, `unit_price_snapshot` → en comentarios del código: “QuoteLines NO tiene list_unit_price_snapshot ni unit_price_snapshot”; se usa `msrp` y snapshots `roll_*`/`bom_*`.
- `measure_basis_snapshot`, `roll_width_m_snapshot`, `fabric_pricing_mode_snapshot`, `computed_qty`, `unit_cost_snapshot`, `total_unit_cost_snapshot`, `margin_*`, `discount_*`, `line_total`, etc. → revisar si existen en la tabla real y si alguna ruta de Quote/Manufacturing las llena.

### 3.3 Origen de los totales y precios en QuoteLines

- **Desde ConfiguredProduct (flujo principal):**  
  - `createQuoteLineFromConfiguredProduct` llama a `recalculateConfiguredProductTotals(configuredProductId)` (RPC `calculate_configured_product_totals`).  
  - Luego lee `ConfiguredProducts` y toma:  
    - `roll_msrp_total` → `roll_msrp_snapshot`  
    - `bom_total` → `bom_msrp_snapshot`  
    - `roll_plus_bom_total` → `msrp`  
    - `roll_total_cost` → `roll_cost_snapshot`  
    - `bom_total_cost` → `bom_cost_snapshot`  
  - `total_cost = roll_cost_snapshot + bom_cost_snapshot`; `net_price = msrp * (1 - discount_pct/100)`.

- **En UI (useQuoteLines):**  
  - `msrp = line.msrp || (line.roll_msrp_snapshot + line.bom_msrp_snapshot)`  
  - `total_cost = line.total_cost || (line.roll_cost_snapshot + line.bom_cost_snapshot)`  
  - Se documenta que **no** se recalcula desde ConfiguredProducts; QuoteLines es snapshot.

---

## 4. QuoteLineComponents

### 4.1 Columnas usadas

| Columna | Uso | Origen |
|---------|-----|--------|
| `id` | ✅ | generado |
| `quote_line_id` | ✅ | |
| `organization_id` | ✅ | |
| `catalog_item_id` | ✅ | item elegido (fabric, accesorio, drive, etc.) |
| `component_role` | ✅ | 'fabric', 'accessory', 'drive', 'tube', 'motor', 'bottom_bar', 'headbox', etc. |
| `kind` | ✅ | 'selection' | 'option' |
| `source` | ✅ | 'accessory', 'selection', etc. |
| `qty` | ✅ | 1 o lo elegido |
| `unit_cost_exw` | ✅ | CatalogItems.cost_exw al insertar |
| `payload` | ✅ | Opciones (area, position, drive_type, hardware_color, etc.) |
| `deleted` | ✅ | false |

### 4.2 Rol en los cálculos

- **BOM / triggers:** leen QuoteLineComponents para generar BOMInstanceLines (part_role, resolved_part_id, qty, uom, unit_cost_exw, total_cost_exw).
- **Pricing en QuoteNew:** usa `unit_cost_exw` y `qty` de accesorios para totales.
- **createQuoteLineFromRollerConfig / createQuoteLineFromConfiguredProduct:** insertan opciones (area, position, drive_type, etc.) en `QuoteLineComponents` con `kind='option'` y `payload`.

---

## 5. ConfiguredProducts

### 5.1 Columnas usadas en lectura/escritura

| Columna | Lectura | Escritura | Origen / Cálculo |
|---------|---------|-----------|------------------|
| `id` | ✅ | (generado) | |
| `organization_id` | ✅ | ✅ | |
| `quote_id` | ✅ | ✅ | opcional |
| `bom_template_id` | ✅ | ✅ | matchBOMTemplate (frontend) |
| `product_type_id` | ✅ | ✅ | |
| `roll_catalog_item_id` | ✅ | ✅ | config (variantId / fabric_catalog_item_id) |
| `roll_sku`, `roll_collection_name`, `roll_variant_name`, `roll_width` | ✅ | ✅ | CatalogItems del roll o fallback en createConfiguredProductPreview |
| `width_mm`, `height_mm`, `quantity` | ✅ | ✅ | config |
| `hardware_color` | ✅ | ✅ | config |
| `bottom_bar_item_id`, `bottom_bar_sku` | ✅ | ✅ | config |
| `headbox_*`, `side_channel_*`, `bottom_channel_*` | ✅ | ✅ | config |
| `motor_item_id`, `motor_sku` | ✅ | ✅ | config |
| `drive_item_id`, `drive_sku` | ✅ | ✅ | config |
| `tube_item_id`, `tube_sku` | ✅ | ✅ | config |
| `operating_type` | ✅ | ✅ | config |
| `config_snapshot` | ✅ | ✅ | JSON completo del config |
| `roll_msrp_total` | ✅ | ✅ | **RPC `calculate_configured_product_totals`** (o 0 en fallback) |
| `bom_total` | ✅ | ✅ | **RPC** (suma BOM + labor, nomenclatura interna “bom”) |
| `roll_plus_bom_total` | ✅ | ✅ | **RPC** |
| `labor_pct` | ✅ | ✅ | **RPC** |
| `accessories_total` | ✅ | ✅ | **RPC** |
| `total_msrp` | ✅ | ✅ | **RPC** |
| `roll_total_cost`, `bom_total_cost` | ✅ | ✅ | **RPC** (usados al pasar a QuoteLines como roll_cost_snapshot, bom_cost_snapshot) |
| `deleted` | ✅ | ✅ | false |
| `quote_line_id` | ⚠️ | ✅ | Opcional; se actualiza después de crear QuoteLine. |

### 5.2 Columnas que el fallback de createConfiguredProductPreview escribe con 0

Si el RPC `create_configured_product_and_bom_preview` falla por schema, el fallback inserta:  
`roll_msrp_total`, `bom_total`, `roll_plus_bom_total`, `labor_pct`, `accessories_total`, `total_msrp` en **0** y luego llama a `recalculateConfiguredProductTotals`.  
Si esa RPC también falla, los totales se quedan en 0.

### 5.3 Origen de los totales en ConfiguredProducts

- **RPC `calculate_configured_product_totals`** (y la lógica dentro de `create_configured_product_and_bom_preview` cuando crea/actualiza ConfiguredProducts):  
  - Roll: anchos, qty, CatalogItems, CatalogItemsMSRP, etc.  
  - BOM: BOMInstanceLines (cuando existen) o equivalencia desde BOMComponents + config.  
  - Labor, accesorios, total_msrp, costes, etc. según la implementación actual del RPC.

- **getConfiguredProduct:** `select('*')`, `deleted=false`.  
  Cualquier columna existente en la tabla se lee; las que usa `createQuoteLineFromConfiguredProduct` son las indicadas arriba (roll_*_total, bom_total, roll_plus_bom_total, labor_pct, roll_total_cost, bom_total_cost).

---

## 6. Flujo resumido: de dónde sale cada cálculo

```
Config (UI)
    → matchBOMTemplate() → bom_template_id
    → createConfiguredProductPreview (RPC o fallback)
        → ConfiguredProducts (totales vía calculate_configured_product_totals)
    → createQuoteLineFromConfiguredProduct
        → recalcula ConfiguredProducts
        → Lee ConfiguredProducts (roll_*_total, bom_total, roll_*_cost, bom_*_cost, labor_pct)
        → INSERT QuoteLines (snapshots: roll_*_snapshot, bom_*_snapshot, msrp, total_cost, net_price, labor_pct)
        → Crea BOMInstance (getOrCreateBomInstanceForQuoteLine) con quote_line_id, bom_template_id
        → Triggers/funciones generan BOMInstanceLines desde QuoteLineComponents (o desde BOMComponents+config)
            → unit_cost_exw: get_unit_cost_in_uom o QuoteLineComponents.unit_cost_exw o CatalogItems.cost_exw
            → total_cost_exw: qty * unit_cost_exw
            → cut_*: engineering rules cuando aplica (en muchos casos quedan NULL)
```

---

## 7. Columnas que conviene revisar o unificar

### 7.1 BOMInstanceLines

- **`unit_cost_acu` / `total_cost_acu`** (vistos en Supabase) vs **`unit_cost_exw` / `total_cost_exw`** en código: confirmar schema real y unificar nombre.
- **`resolved_sku`, `category_code`, `description`:** no son columnas de BOMInstanceLines; ApprovedBOMList las pide en el `select`. Si la vista/DB no las agrega, el `select` puede fallar; hoy se compensa con `catalogItemById`. Recomendable: quitar esas columnas del `select` y usar solo `resolved_part_id` + join o mapa de CatalogItems.
- **`cut_length_mm`, `cut_width_mm`, `cut_height_mm`:** casi siempre NULL en código; los triggers/engineering rules son los que deberían rellenarlos. Revisar si esas funciones están activas y para qué `part_role`.

### 7.2 QuoteLines

- **`list_unit_price_snapshot`, `unit_price_snapshot`** y otros snapshots/margins del tipo en `catalog.ts`:** verificar si la tabla los tiene y qué flujos los escriben; si no, sacarlos del tipo o marcarlos legacy para no asumir que existen.
- **`catalog_item_id`:** en flujo ConfiguredProduct a veces no se setea; confirmar si es nullable y si Manufactura/Reports lo necesitan.

### 7.3 ConfiguredProducts

- **`roll_total_cost`, `bom_total_cost`:** se usan al pasar a QuoteLines; comprobar que `calculate_configured_product_totals` (o el RPC de preview) los persista.
- **`metadata`:** en tipos existe; en createConfiguredProductPreview (fallback) no se escribe. Ver si hay rutas que lo lean.

---

## 8. RPCs y funciones SQL que afectan los cálculos

| Función / RPC | Tablas que toca | Qué calcula / hace |
|---------------|------------------|---------------------|
| `create_configured_product_and_bom_preview` | ConfiguredProducts | Crea CP; ya no crea BOMInstance en preview. Totales vía lógica interna o delegando. |
| `calculate_configured_product_totals` | ConfiguredProducts | roll_msrp_total, bom_total, roll_plus_bom_total, labor_pct, accessories_total, total_msrp, roll_total_cost, bom_total_cost. |
| `get_unit_cost_in_uom` | (lectura CatalogItems, UoM, etc.) | unit_cost_exw por UoM. |
| `generate_bom_from_quote_line_components` y triggers asociados | BOMInstances, BOMInstanceLines | Crea/actualiza BOM desde QuoteLineComponents; unit_cost_exw, total_cost_exw, cut_* cuando aplica. |
| `select_best_bom_template_for_configured_product` | (lectura BOMTemplates, BOMComponents) | Selección de template; en el flujo actual el frontend suele usar `matchBOMTemplate` y pasar `bom_template_id` en `config_snapshot`. |

---

## 9. Siguientes pasos recomendados

1. **Schema real:** Ejecutar en la base algo como:
   - `\d "BOMInstanceLines"`, `\d "QuoteLines"`, `\d "ConfiguredProducts"` (o el equivalente en tu SQL) y cotejar con esta auditoría (nombres `*_acu` vs `*_exw`, columnas que no existen, etc.).
2. **ApprovedBOMList:** Ajustar el `select` de BOMInstanceLines para no pedir `resolved_sku`, `category_code`, `description`; obtenerlos de CatalogItems por `resolved_part_id`.
3. **Tipos `catalog.ts` (QuoteLine):** Alinear con columnas reales de QuoteLines y marcar o eliminar las que no existan o no se usen.
4. **Documentar RPCs:** Revisar el código de `calculate_configured_product_totals` y de los triggers de BOM para anotar exactamente de dónde sale cada total y cada `unit_cost_exw`/`total_cost_exw` (y cut_* si aplica).

Si quieres, el siguiente paso puede ser: (a) un script SQL de auditoría que liste columnas de cada tabla, o (b) cambios concretos en `ApprovedBOMList` y en los tipos de `QuoteLine`/`BOMInstanceLine`.
