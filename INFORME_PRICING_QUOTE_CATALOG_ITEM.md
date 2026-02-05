# Informe: Dónde se calcula precio/costo de CatalogItem en Quotes / QuoteLines

**Objetivo:** Identificar la fuente actual de verdad para modificar el motor de pricing de telas/rollos con `roll_pricing_mode` y `CatalogItemConversions` (cost_exw_per_m / cost_exw_per_m2).

**Nota:** En el código actual **no existen** `CatalogItemConversions`, `roll_pricing_mode`, `cost_exw_per_m` ni `cost_exw_per_m2`. Existe `fabric_pricing_mode` en `CatalogItems` y se usa solo en BOM/componentes, no en el coste de la línea de cotización principal.

---

## 1) Funciones SQL relacionadas con pricing, costo o MSRP

### Coste de línea de cotización (QuoteLines → QuoteLineCosts)

| Función | Archivo | Cuándo se ejecuta |
|--------|---------|--------------------|
| **compute_quote_line_cost** | `database/migrations/55_update_compute_cost_with_bom.sql` (versión vigente; también existían 25, 28, 32, 34) | **Trigger** `trigger_quote_lines_compute_cost` en `"QuoteLines"` AFTER INSERT OR UPDATE OF `catalog_item_id`, `qty`, `computed_qty` (definido en `25_create_compute_quote_line_cost_function.sql`). También **llamada directa RPC** desde frontend: `supabase.rpc('compute_quote_line_cost', { p_quote_line_id, p_options })` en `QuoteNew.tsx`, `QuoteLineCostsSectionV1.tsx`, `useCosts.ts`. |

### Precio de línea de cotización (unit_price_snapshot, line_total)

| Función | Archivo | Cuándo se ejecuta |
|--------|---------|--------------------|
| **calculate_quote_line_price** | `database/migrations/46_create_calculate_quote_line_price_function.sql` | **Trigger** `trg_calculate_quote_line_price` en `"QuoteLines"` AFTER INSERT OR UPDATE OF `catalog_item_id`, `qty`, `computed_qty`. **Trigger** `trg_recalculate_price_on_cost_update` en `"QuoteLineCosts"` AFTER INSERT OR UPDATE OF `total_cost`, `base_material_cost` (recalcula precio cuando cambia el coste). |

### MSRP por ítem de catálogo (CatalogItemsMSRP)

| Función | Archivo | Cuándo se ejecuta |
|--------|---------|--------------------|
| **msrp_compute_for_item** | `database/migrations/20260136_remove_material_cost_from_catalogitemsmsrp.sql` | Llamada desde **trigger** `trig_recompute_msrp_on_catalog_item_change` (y otros triggers de recompute). Escribe en `CatalogItemsMSRP`: cost_exw, shipping_pct, import_tax_pct, total_cost, msrp_sale_in, msrp_sale_out. **No** se llama al insertar/actualizar QuoteLines; es por ítem de catálogo. |
| **recompute_catalog_item_msrp** | Mismo archivo | RPC/helper para recomputar MSRP de un ítem. |
| **sync_catalogitems_to_msrp** | Varias migraciones (ej. 20260129, 20260136) | Trigger que sincroniza filas CatalogItems → CatalogItemsMSRP. |

### Totales de cotización (Quote)

| Función | Archivo | Cuándo se ejecuta |
|--------|---------|--------------------|
| **calculate_quote_totals** | `database/migrations/52_create_calculate_quote_totals_function.sql` | **Trigger** `trg_recalculate_quote_totals` cuando cambian QuoteLines. Actualiza subtotal, discount_total, tax, total del Quote. |

### BOM y componentes (coste por componente; incluye telas como componente)

| Función | Archivo | Cuándo se ejecuta |
|--------|---------|--------------------|
| **get_unit_cost_in_uom** | `database/migrations/200_robust_uom_fabric_pricing_model.sql` | Convierte coste de ítem a una UOM objetivo. Usa **CatalogItems**: `cost_exw`, `cost_uom`, `is_fabric`, `roll_width_m`, `fabric_pricing_mode`. Se usa al poblar **BomInstanceLines** (trigger on quote approved) y en **generate_configured_bom_for_quote_line** / **generate_bom_from_slots** para calcular `unit_cost_exw` de cada componente. **No** se usa en `compute_quote_line_cost` para la línea principal. |
| **calculate_fabric_pricing_qty** | Mismo archivo | Convierte cantidad base (m²) a cantidad en UOM de pricing (m², m, yd, roll) según `fabric_pricing_mode` y `roll_width_m`. Usado en **populate_bom_line_base_pricing_fields** (BomInstanceLines). |
| **populate_bom_line_base_pricing_fields** | Mismo archivo | Rellena qty_base, qty_pricing, unit_cost_pricing, etc. en BomInstanceLines; usa `fabric_pricing_mode` y `roll_width_m` del CatalogItem. |
| **calculate_bom_price** | `database/migrations/54_create_calculate_bom_price_function.sql` | Calcula coste de un producto con BOM; usa **CatalogItems.cost_exw** y **measure_basis** por componente. **No** usa fabric_pricing_mode en esta función; la cantidad se calcula por UOM (m, m2, unit). |
| **generate_configured_bom_for_quote_line** / **generate_bom_from_slots** | Varias migraciones (174, 173, 186, 188, etc.) | Generan QuoteLineComponents y usan **get_unit_cost_in_uom** para asignar `unit_cost_exw` a cada componente (incluidas telas). |

### Triggers en QuoteLines (resumen)

- **trigger_quote_lines_compute_cost** → `compute_quote_line_cost(NEW.id)`  
- **trg_calculate_quote_line_price** → `calculate_quote_line_price(NEW.id)`  

El orden efectivo: primero coste, luego precio (por el orden de los triggers).

---

## 2) Resumen por función: nombre, archivo, cuándo se ejecuta

- **compute_quote_line_cost(uuid, jsonb)**  
  - Archivo vigente: `database/migrations/55_update_compute_cost_with_bom.sql`  
  - Se ejecuta: trigger en QuoteLines (catalog_item_id, qty, computed_qty) + RPC desde frontend.

- **calculate_quote_line_price(uuid)**  
  - Archivo: `database/migrations/46_create_calculate_quote_line_price_function.sql`  
  - Se ejecuta: trigger en QuoteLines (catalog_item_id, qty, computed_qty) y trigger en QuoteLineCosts (total_cost, base_material_cost).

- **msrp_compute_for_item(uuid)**  
  - Archivo: `database/migrations/20260136_remove_material_cost_from_catalogitemsmsrp.sql`  
  - Se ejecuta: triggers sobre CatalogItems / CategoryMargins / CostSettings / ImportTax; no por QuoteLines.

- **get_unit_cost_in_uom(catalog_item_id, target_uom, organization_id)**  
  - Archivo: `database/migrations/200_robust_uom_fabric_pricing_model.sql`  
  - Se ejecuta: al generar BOM (QuoteLineComponents / BomInstanceLines), no en compute_quote_line_cost para la línea principal.

- **calculate_bom_price(...)**  
  - Archivo: `database/migrations/54_create_calculate_bom_price_function.sql`  
  - Se ejecuta: desde **compute_quote_line_cost** cuando la línea tiene BOM (catalog_item_id es padre en BOMComponents).

---

## 3) Cómo se obtiene hoy el precio de una TELA / ROLL

### Caso: tela como **línea principal** de cotización (QuoteLine.catalog_item_id = ítem tela)

- **Coste (base_material_cost en QuoteLineCosts):**  
  En **compute_quote_line_cost** (55), rama **sin BOM** y **sin QuoteLineComponents** (o suma = 0):

  ```text
  SELECT id, cost_exw FROM "CatalogItems" WHERE id = v_quote_line_record.catalog_item_id;
  v_base_material_cost := cost_exw * GREATEST(computed_qty, qty, 1);
  ```

  **Columnas usadas:** solo **CatalogItems.cost_exw**.  
  No se usan: `measure_basis`, `fabric_pricing_mode`, `roll_width_m`, ni ninguna tabla de conversiones.

- **Interpretación:** El sistema trata `cost_exw` como “coste por unidad de cantidad”. El frontend envía para telas `computed_qty = width_m * height_m` (área en m²). Por tanto, el backend asume de hecho **cost_exw = coste por m²**. Si en catálogo el coste estuviera “por metro lineal”, la fórmula actual sería incorrecta.

### Caso: tela como **componente** de BOM (QuoteLineComponents / BomInstanceLines)

- **Unit cost del componente:**  
  Viene de **get_unit_cost_in_uom**(catalog_item_id, target_uom, org_id).  
  Esa función sí usa **CatalogItems**: `cost_exw`, `cost_uom`, `is_fabric`, `roll_width_m`, `fabric_pricing_mode` para convertir entre m, m², yd según la UOM objetivo.  
  Aquí el precio de tela **sí** depende de modo (per m, per m², etc.) y ancho de rollo.

### Precio de venta (unit_price_snapshot) de la línea

- **calculate_quote_line_price** obtiene el coste base así:
  1. Si existe **QuoteLineCosts**: `base_cost_per_unit = total_cost / GREATEST(computed_qty, qty, 1)`.
  2. Si no, fallback: **CatalogItems.cost_exw**.

  Luego aplica margen (categoría > ítem > 35%) y escribe `unit_price_snapshot`, etc. en QuoteLines.  
  Para telas como línea principal, el “coste base” que entra en el precio es, por tanto, el mismo que en compute_quote_line_cost: **cost_exw** (interpretado como por unidad de computed_qty, en práctica por m²).

---

## 4) ¿Pricing 100% SQL o parcialmente TypeScript?

- **Persistencia y fuente de verdad:**  
  **100% SQL** para lo que se guarda en BD:
  - QuoteLineCosts (base_material_cost, total_cost, etc.) → **compute_quote_line_cost**.
  - QuoteLines (unit_price_snapshot, line_total, etc.) → **calculate_quote_line_price** (trigger).

- **TypeScript (solo UI / borrador):**
  - **src/lib/pricing.ts**: `calculateQuoteLinePrice()` usa `catalogItem.cost_exw` (y opcionalmente labor, shipping, etc.) para calcular `totalUnitCost` y un precio neto con descuento por tipo de cliente y suelo de margen. Esto es para **mostrar** precio y total antes de guardar.
  - **QuoteNew.tsx** y **createQuoteLineFromRollerConfig.ts**: calculan `computedQty` (para área: width_m * height_m; para lineal: width_m o height_m), llaman a `calculateQuoteLinePrice({ cost_exw: catalogItem?.cost_exw, ... })` y rellenan snapshots al insertar/actualizar la línea. Tras guardar, los triggers SQL recalculan coste y precio en BD; el frontend puede llamar además `compute_quote_line_cost` por RPC tras guardar la línea.

Conclusión: el **cálculo que se persiste** es 100% SQL (triggers + funciones). TypeScript solo prepara datos y precios de vista; la verdad para coste/precio guardado está en **compute_quote_line_cost** y **calculate_quote_line_price**.

---

## 5) Punto exacto donde intervenir para roll_pricing_mode y CatalogItemConversions

### Objetivo

- Que el coste (y por tanto el precio) de una **tela/roll como línea de cotización** use:
  - **roll_pricing_mode** (ej. per_linear_meter / per_square_meter), y  
  - **CatalogItemConversions** (ej. cost_exw_per_m, cost_exw_per_m2) en lugar de un único `cost_exw` × computed_qty.

### Dónde intervenir (solo identificación, sin refactor)

1. **Función principal a tocar:**  
   **compute_quote_line_cost**  
   Archivo: `database/migrations/55_update_compute_cost_with_bom.sql` (o la migración que defina la versión vigente de esta función).

   **Bloque concreto:** rama **ELSE** (cuando no hay BOM), sub-bloque “fallback” cuando no hay QuoteLineComponents o la suma es 0:

   - Hoy: lee `CatalogItems.cost_exw` y hace `v_base_material_cost := cost_exw * GREATEST(computed_qty, qty, 1)`.
   - Aquí hay que:
     - Detectar si el ítem es tela/roll (p. ej. por categoría o flag).
     - Según **roll_pricing_mode** (o equivalente desde CatalogItems / CatalogItemConversions), elegir:
       - coste por m² (ej. **CatalogItemConversions.cost_exw_per_m2**) y multiplicar por `computed_qty` en m², o  
       - coste por metro lineal (ej. **CatalogItemConversions.cost_exw_per_m**) y multiplicar por cantidad en metros lineales (derivada de width_m, height_m, roll_width, etc.).
   - Si se mantiene compatibilidad con el modelo actual, seguir usando **CatalogItems.cost_exw** cuando no exista roll_pricing_mode / CatalogItemConversions.

2. **Función secundaria (coherencia de precio):**  
   **calculate_quote_line_price**  
   Archivo: `database/migrations/46_create_calculate_quote_line_price_function.sql`.

   - Hoy: base cost = total_cost de QuoteLineCosts / computed_qty, o fallback CatalogItems.cost_exw.
   - Si **compute_quote_line_cost** ya escribe correctamente `base_material_cost` y `total_cost` usando roll_pricing_mode y CatalogItemConversions, no es estrictamente necesario cambiar esta función para el “coste por unidad” (porque ya usará total_cost de QuoteLineCosts). Solo haría falta tocar si se quisiera un fallback explícito que también use cost_exw_per_m / cost_exw_per_m2 cuando no exista QuoteLineCosts.

3. **BOM / componentes (opcional para coherencia):**  
   **get_unit_cost_in_uom**  
   Archivo: `database/migrations/200_robust_uom_fabric_pricing_model.sql`.

   - Hoy: para telas usa `cost_exw`, `roll_width_m`, `fabric_pricing_mode` para convertir entre UOM.
   - Si se introduce **CatalogItemConversions** con cost_exw_per_m y cost_exw_per_m2, se puede hacer que esta función tome esos valores cuando existan (en lugar de derivar todo desde un único cost_exw), para que BOM y líneas principales usen la misma fuente de coste por m / por m².

### Resumen del punto exacto

- **Función:** `compute_quote_line_cost`.  
- **Archivo:** `database/migrations/55_update_compute_cost_with_bom.sql`.  
- **Lugar:** bloque que asigna `v_base_material_cost` cuando **no** hay BOM y **no** hay (o suma cero de) QuoteLineComponents: sustituir/ampliar la lógica “cost_exw * GREATEST(computed_qty, qty, 1)” por una que use **roll_pricing_mode** y **CatalogItemConversions** (cost_exw_per_m, cost_exw_per_m2) para telas/rollos, manteniendo el comportamiento actual para el resto de ítems.

---

## Anexo: Columnas de CatalogItems usadas hoy en pricing

| Columna        | Dónde se usa |
|----------------|--------------|
| cost_exw       | compute_quote_line_cost (línea principal), calculate_quote_line_price (fallback), get_unit_cost_in_uom (componentes), msrp_compute_for_item, calculate_bom_price, frontend (cost_exw en calculateQuoteLinePrice). |
| measure_basis  | calculate_bom_price (cantidades por componente); frontend para decidir computed_qty (area vs linear). No en compute_quote_line_cost. |
| roll_width_m   | get_unit_cost_in_uom, calculate_fabric_pricing_qty, populate_bom_line_base_pricing_fields (solo BOM/componentes). No en compute_quote_line_cost. |
| fabric_pricing_mode | get_unit_cost_in_uom, calculate_fabric_pricing_qty, populate_bom_line_base_pricing_fields (solo BOM/componentes). No en compute_quote_line_cost. |
| item_category_id | calculate_quote_line_price (margen por categoría). |
| default_margin_pct | calculate_quote_line_price (margen por ítem). |

**Conclusión:** Para la **línea de cotización principal** (una tela como producto de la línea), la única columna de coste usada en SQL es **cost_exw**. Ninguna columna de “modo” de pricing de tela ni conversiones se usa hoy en ese flujo.
