# Informe: Flujo completo de Quote y origen de los BOM

**Objetivo:** Documentar para el equipo todo el proceso y flujo de **Quote** (cotización) y **de dónde se toman los BOM** (Bill of Materials) que se asocian a las líneas de cotización.

---

## 1. Resumen ejecutivo

- **Quote** es la cabecera de la cotización (`Quotes`). Cada Quote tiene **QuoteLines** (líneas de producto).
- Cada **QuoteLine** puede tener un **BOMInstance** (instancia de lista de materiales) asociado, generado a partir de un **BOMTemplate**.
- Los **BOM** se obtienen de:
  1. **BOMTemplates**: plantillas por tipo de producto (roller, dual-shade, etc.) y opciones (color, manual/motor, etc.).
  2. **Selección en UI**: el usuario elige tipo de producto y, si aplica, un template concreto; o se auto-selecciona cuando solo hay uno.
  3. **Base de datos**: la función `select_best_bom_template_for_quote_line` elige el template que mejor coincide con las opciones guardadas en la línea (color, cassette, drive, etc.).

---

## 2. Flujo de Quote (cabecera)

### 2.1 Creación de un nuevo Quote

| Paso | Dónde | Qué ocurre |
|------|------|------------|
| 1 | **QuoteNew.tsx** | Usuario rellena cabecera: `quote_no`, `customer_id`, `status` (draft/approved), `company_id` (opcional; si no se envía se obtiene de `CompanyPortalUsers` para usuario portal). |
| 2 | **useQuotes.ts** → `createQuote()` | Se llama a `supabase.from('Quotes').insert({ ...quoteData, organization_id, company_id })`. |
| 3 | **Supabase** | Se inserta una fila en `Quotes` y se devuelve el `id`. |
| 4 | **QuoteNew.tsx** | Se guarda `quoteId` en estado y se pasa a “modo edición” del mismo quote; el usuario puede añadir líneas. |

**Archivos clave:**

- `src/pages/sales/QuoteNew.tsx` (formulario y llamada a `createQuote`).
- `src/hooks/useQuotes.ts` (función `createQuote` en `useCreateQuote()`).

### 2.2 Actualización de un Quote existente

- **useQuotes.ts** → `updateQuote(id, quoteData)`.
- `supabase.from('Quotes').update(quoteData).eq('id', id).eq('organization_id', activeOrganizationId)`.

---

## 3. Flujo de QuoteLine (líneas de cotización)

Hay **dos flujos** según si la línea viene de un **ConfiguredProduct** (configurador con preview) o no.

### 3.1 Flujo A: Con ConfiguredProduct (snapshots)

Cuando el usuario configuró el producto en el configurador y existe `configured_product_id`, y **no** se está editando una línea ya existente:

| Paso | Dónde | Qué ocurre |
|------|------|------------|
| 1 | **QuoteNew.tsx** | Se llama a `createQuoteLineFromConfiguredProduct()` con `quoteId`, `configuredProductId`, `bom_template_id` (del config), cantidad, descuento, etc. |
| 2 | **createQuoteLineFromConfiguredProduct.ts** | Se recalcula el ConfiguredProduct en servidor (`recalculateConfiguredProductTotals`). |
| 3 | Mismo archivo | Se lee el ConfiguredProduct y se preparan snapshots (roll_msrp_total, bom_total, roll_total_cost, bom_total_cost, etc.). |
| 4 | Mismo archivo | Se **inserta primero** la **QuoteLine** en `QuoteLines` (con `bom_template_id`, snapshots iniciales, medidas, etc.). Se obtiene `quote_line_id`. |
| 5 | Mismo archivo | Si hay `bom_template_id`, se llama al RPC **`create_bom_instance_for_configured_product`** con `p_org_id`, `p_quote_line_id`, `p_configured_product_id`, `p_product_type_id`. |
| 6 | Base de datos | Se crea **BOMInstance** (y BOMInstanceLines) asociado a esa QuoteLine. |
| 7 | Mismo archivo | Se vuelve a recalcular el ConfiguredProduct y se **actualiza la QuoteLine** con los snapshots finales (roll_msrp_snapshot, bom_msrp_snapshot, total_cost, etc.). |
| 8 | QuoteNew.tsx | Se refrescan líneas y se termina; **no** se ejecuta el flujo de generación de BOM manual (generate_bom_from_slots). |

**Origen del BOM en este flujo:**  
El **bom_template_id** viene del **config del configurador** (ProductConfigurator / pasos de producto). Ese template ya fue elegido o auto-seleccionado en la UI antes de guardar. El RPC `create_bom_instance_for_configured_product` usa ese template (y el ConfiguredProduct) para generar el BOMInstance.

**Archivos clave:**

- `src/lib/quotes/createQuoteLineFromConfiguredProduct.ts`
- `src/pages/sales/QuoteNew.tsx` (bloque “shouldUseSnapshotService” ~1144–1180)

### 3.2 Flujo B: Sin ConfiguredProduct (flujo legacy / inserción directa)

Cuando **no** hay `configured_product_id` o se está **editando** una línea ya existente:

| Paso | Dónde | Qué ocurre |
|------|------|------------|
| 1 | **QuoteNew.tsx** | Se construye `quoteLineData` (medidas, collection_name, variant_name, hardware_color, cassette, drive_type, **bom_template_id** si viene en el config, etc.) y se filtra con `allowedQuoteLineFields`. |
| 2 | QuoteNew.tsx | Si es edición: `supabase.from('QuoteLines').update(...).eq('id', editingLineId)`. Si es alta: `supabase.from('QuoteLines').insert({ ...sanitizedQuoteLineData, organization_id }).select('id').single()` → se obtiene `finalLineId`. |
| 3 | QuoteNew.tsx | Se guarda el roll como QuoteLineComponent (fabric) si aplica (incl. RPC `upsert_fabric_quote_line_component`). |
| 4 | QuoteNew.tsx | **Guardado de opciones en QuoteLineComponents:** se hace soft-delete de `kind='option'` anteriores y se insertan filas con `kind='option'` para: hardware_color, drive_type, cassette, side_channel, bottom_rail_type, tube_type (payload JSONB). |
| 5 | QuoteNew.tsx | **Guardado de selecciones en QuoteLineComponents:** se insertan filas con `kind='selection'` para: fabric, motor, drive, bottom_bar, headbox, tube, side_channel, bottom_channel (catalog_item_id + payload). |
| 6 | QuoteNew.tsx | Si hay `productTypeId`, se llama al RPC **`generate_bom_from_slots`** con `p_org_id`, `p_quote_line_id`, `p_product_type_id`. |
| 7 | Base de datos | **`generate_bom_from_slots`** internamente: llama a **`select_best_bom_template_for_quote_line`** para elegir el BOMTemplate; crea BOMInstance y BOMInstanceLines a partir de BOMTemplateSlots y de las selecciones/opciones en QuoteLineComponents. |
| 8 | QuoteNew.tsx | Si la RPC devuelve `bomInstanceId`, se calcula el precio del BOM con `priceFromBOMInstance` y se actualiza la QuoteLine con roll_msrp_snapshot, bom_msrp_snapshot, msrp, total_cost, etc. |

**Origen del BOM en este flujo:**  
- **bom_template_id** puede venir ya en el config (normalizado desde el configurador) y guardarse en la QuoteLine.  
- La función **`select_best_bom_template_for_quote_line(org_id, product_type_id, quote_line_id)`** lee **QuoteLines** (hardware_color, cassette, side_channel, drive_type, etc.) y **QuoteLineComponents** (options y selections) y devuelve el **BOMTemplate** que mejor coincide (p. ej. por color, condiciones de bloqueo, tipo de operación). Ese template es el que usa **generate_bom_from_slots** para crear el BOMInstance.

**Archivos clave:**

- `src/pages/sales/QuoteNew.tsx` (bloque ~1208–1750: insert/update QuoteLine, QuoteLineComponents, luego `generate_bom_from_slots` y pricing).

---

## 4. De dónde se toman los BOM (resumen)

### 4.1 Tablas y conceptos

| Concepto | Tabla / Objeto | Descripción |
|----------|----------------|-------------|
| **Plantilla BOM** | **BOMTemplates** | Plantilla por organización, product_type_id, opcionalmente color/código. Define “qué roles de componente” lleva ese tipo de producto. |
| **Slots del template** | **BOMTemplateSlots** | Por cada BOMTemplate: item_role (tube, drive, motor, headbox, etc.), catalog_item_id (opcional), required. Pueden ser “auto” o fijos. |
| **Instancia BOM** | **BOMInstances** | Una instancia por QuoteLine (quote_line_id obligatorio). Apunta a bom_template_id. |
| **Líneas de la instancia** | **BOMInstanceLines** | Por cada componente: resolved_part_id (CatalogItem), part_role, qty, uom, cost, etc. |

### 4.2 Origen del bom_template_id

1. **En el configurador (UI)**  
   - **ProductConfigurator** / **curtain-config** (p. ej. ProductStep): el usuario elige **ProductType** (roller-shade, dual-shade, etc.).  
   - Se cargan los **BOMTemplates** para ese `product_type_id` (organización, activos, no archivados).  
   - Si el usuario elige explícitamente un template en un desplegable, se guarda en el config como **bom_template_id**.  
   - Si solo hay **un** template para ese tipo de producto, se puede auto-seleccionar y quedar en el config como **bom_template_id**.  
   - Al guardar la línea, ese **bom_template_id** se pasa a:
     - **Flujo A:** `createQuoteLineFromConfiguredProduct` → se guarda en la QuoteLine y lo usa `create_bom_instance_for_configured_product`.
     - **Flujo B:** se guarda en la QuoteLine y puede ser usado por la lógica de BOM; además, **select_best_bom_template_for_quote_line** puede elegir/confirmar template según opciones guardadas.

2. **En base de datos (matching)**  
   - **select_best_bom_template_for_quote_line(p_org_id, p_product_type_id, p_quote_line_id)**  
   - Lee opciones de la QuoteLine y de **QuoteLineComponents** (kind='option' y 'selection').  
   - Evalúa qué **BOMTemplate** coincide mejor (p. ej. por hardware_color, cassette, side_channel, drive_type, block_conditions en el template).  
   - Devuelve el **id** del BOMTemplate elegido.  
   - Usado por **generate_bom_from_slots** cuando se genera el BOM en el flujo sin ConfiguredProduct (o cuando no hay template pre-elegido en la UI).

### 4.3 Cómo se generan las líneas del BOM (BOMInstanceLines)

- **Con ConfiguredProduct:** el RPC **create_bom_instance_for_configured_product** (y la lógica que usa por debajo, p. ej. generate_bom_from_slots_for_configured_product) crea BOMInstance y líneas a partir del BOMTemplate del ConfiguredProduct y de las opciones/selecciones ya guardadas en el ConfiguredProduct / QuoteLineComponents.
- **Sin ConfiguredProduct:** **generate_bom_from_slots**:
  1. Obtiene el template con **select_best_bom_template_for_quote_line**.
  2. Crea un registro en **BOMInstances** (organization_id, quote_line_id, bom_template_id).
  3. Para cada **BOMTemplateSlot** del template (y según opciones como operation_type):
     - Si en **QuoteLineComponents** hay una **selección** (kind='selection') para ese role, usa ese **catalog_item_id**.
     - Si no, puede usar el catalog_item_id del slot o resolver por role + opciones (p. ej. color, tipo de operación).
  4. Inserta las filas en **BOMInstanceLines** (resolved_part_id, part_role, qty, uom, cost, etc.).

Así, los **BOM** “vienen” de:

- **BOMTemplates** (definición por tipo de producto y opciones).
- **BOMTemplateSlots** (roles y, opcionalmente, ítems por defecto).
- **QuoteLineComponents** (opciones y selecciones de SKU del usuario) para resolver los **CatalogItems** finales en **BOMInstanceLines**.

---

## 5. Trigger en QuoteLines (BOM automático)

Existe un trigger **AFTER INSERT** en **QuoteLines**:

- **Función:** `trg_quote_lines_generate_bom_instance_fn`
- **Efecto:** Tras insertar una QuoteLine, llama a **`generate_bom_instance_for_quote_line(NEW.organization_id, NEW.id, v_product_type_id)`**.
- **product_type_id** se resuelve en este orden:  
  1) columna `QuoteLines.product_type_id`,  
  2) si no, `ConfiguredProducts.product_type_id` por `QuoteLines.configured_product_id`,  
  3) si no, primer BOMTemplate activo de la org (por prioridad/updated_at).

**Importante:** En el flujo con **ConfiguredProduct**, el frontend ya crea el BOMInstance vía **create_bom_instance_for_configured_product**; el trigger podría intentar generar **otro** BOM para la misma línea si no se evita (p. ej. por restricción un solo BOMInstance por quote_line_id). En el flujo **sin** ConfiguredProduct, el frontend usa **generate_bom_from_slots**; según el orden de ejecución y si el trigger corre después, podría haber solapamiento. Conviene que el equipo revise si el trigger debe seguir ejecutándose siempre o solo cuando el frontend no haya creado ya el BOM.

**Archivo del trigger:**  
`database/migrations/20260203_fix_trg_quote_lines_generate_bom_instance_active_column.sql`

---

## 6. Tabla QuoteLineComponents

- **Propósito:** Guardar opciones de configuración y selecciones de SKU por línea de cotización para que el servidor pueda:
  - Elegir el BOMTemplate correcto (`select_best_bom_template_for_quote_line`).
  - Resolver los componentes del BOM (generate_bom_from_slots / create_bom_instance_for_configured_product).

| Columna | Uso |
|---------|-----|
| **quote_line_id** | QuoteLine a la que pertenece. |
| **kind** | `'option'` (opciones: color, cassette, drive_type, etc.), `'selection'` (SKU elegido: fabric, motor, tube, etc.), `'override'`, `'accessory'`. |
| **component_role** | Rol del componente (hardware_color, drive_type, cassette, tube, motor, fabric, etc.). |
| **catalog_item_id** | En kind='selection' (y accesorios): ítem de catálogo elegido. |
| **payload** | JSON con el valor de la opción (p. ej. `{ "hardware_color": "White" }`, `{ "drive_type": "manual" }`). |

**Definición:** `database/migrations/20260203_create_quotelinecomponents_table.sql`  
**Inserción (flujo B):** `QuoteNew.tsx` (opciones ~1224–1335, selecciones ~1339–1436).

---

## 7. Diagrama de flujo simplificado

```
Usuario crea/edita Quote (cabecera)
         │
         ▼
   [Guardar Quote] ──► Quotes (insert/update)
         │
         ▼
   Usuario "Add Product" → ProductConfigurator
         │
         ├─► Elige ProductType → se cargan BOMTemplates
         ├─► Elige/auto bom_template_id, medidas, tela, opciones, SKUs
         ▼
   [Guardar línea]
         │
         ├─ ¿Hay configured_product_id y no es edición?
         │      SÍ ─► createQuoteLineFromConfiguredProduct
         │              │
         │              ├─► Insert QuoteLine (con bom_template_id)
         │              ├─► RPC create_bom_instance_for_configured_product
         │              ├─► BOMInstance + BOMInstanceLines
         │              └─► Update QuoteLine (snapshots finales)
         │
         └─ NO ─► Insert/Update QuoteLine
                   │
                   ├─► Insert QuoteLineComponents (options + selections)
                   ├─► RPC generate_bom_from_slots
                   │      │
                   │      ├─► select_best_bom_template_for_quote_line
                   │      ├─► BOMInstance + BOMInstanceLines
                   │      └─► priceFromBOMInstance → Update QuoteLine
                   └─► (Opcional) Trigger trg_quote_lines_generate_bom_instance
```

---

## 8. Archivos y RPCs de referencia

| Elemento | Ubicación |
|----------|-----------|
| Creación Quote | `src/hooks/useQuotes.ts` (`createQuote`), `src/pages/sales/QuoteNew.tsx` |
| Creación QuoteLine con ConfiguredProduct | `src/lib/quotes/createQuoteLineFromConfiguredProduct.ts` |
| Creación QuoteLine sin ConfiguredProduct + BOM | `src/pages/sales/QuoteNew.tsx` (bloque líneas + QuoteLineComponents + generate_bom_from_slots) |
| Config y bom_template_id en UI | `src/pages/sales/ProductConfigurator.tsx`, `src/pages/sales/curtain-config/ProductStep.tsx`, `src/pages/sales/product-config/config-contract.ts` |
| Preview ConfiguredProduct | `src/lib/bom/createConfiguredProductPreview.ts` |
| Roller BOM (otro flujo de línea) | `src/lib/bom/createQuoteLineFromRollerConfig.ts` (generate_bom_from_slots + QuoteLineComponents) |
| Trigger BOM en QuoteLines | `database/migrations/20260203_fix_trg_quote_lines_generate_bom_instance_active_column.sql` |
| Tabla QuoteLineComponents | `database/migrations/20260203_create_quotelinecomponents_table.sql` |
| RPCs BOM | `create_bom_instance_for_configured_product`, `generate_bom_from_slots`, `select_best_bom_template_for_quote_line`, `generate_bom_instance_for_quote_line` (en migraciones / backup SQL) |

---

## 9. Resumen para el equipo

- **Quote** = cabecera en `Quotes`; **QuoteLine** = líneas en `QuoteLines`; cada línea puede tener un **BOMInstance** en `BOMInstances` y sus **BOMInstanceLines**.
- **Origen de los BOM:**  
  - **BOMTemplates** + **BOMTemplateSlots** (definición por tipo de producto y opciones).  
  - **bom_template_id** viene de la UI (configurador) o de la función **select_best_bom_template_for_quote_line** según opciones guardadas en **QuoteLines** y **QuoteLineComponents**.
- **Dos flujos de línea:**  
  - **Con ConfiguredProduct:** crear QuoteLine → crear BOM con `create_bom_instance_for_configured_product` → actualizar snapshots.  
  - **Sin ConfiguredProduct:** crear/actualizar QuoteLine → guardar QuoteLineComponents (options + selections) → crear BOM con **generate_bom_from_slots** (que usa select_best_bom_template_for_quote_line y slots + selecciones).
- **QuoteLineComponents** son la fuente de verdad de opciones y SKUs elegidos por el usuario y alimentan la selección del template y la resolución de componentes del BOM.

Si quieres, el siguiente paso puede ser bajar esto a un diagrama de secuencia por flujo (A y B) o a una checklist de pruebas para validar que los BOM se generan como esperáis.
