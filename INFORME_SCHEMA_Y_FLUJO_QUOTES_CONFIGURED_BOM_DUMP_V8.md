# Informe (DUMP v8): Schema y flujo Quote → ConfiguredProduct → BOM

Fuente: `backups/2026-02_02_v8_full.sql` (DUMP v8).  
Objetivo: Documento técnico para el equipo con **tablas/columnas reales** y el **flujo end-to-end**.

---

## 1) Entidades principales (source of truth por capa)

- **`public."Quotes"`**: encabezado comercial (cliente, estado, moneda).
- **`public."QuoteLines"`**: líneas de cotización (dimensiones, snapshots de costos/MSRP, vínculo al configurado).
- **`public."ConfiguredProducts"`**: **snapshot completo** del producto configurado (config JSON + BOM template + totales calculados).
- **`public."BOMTemplates"`** + `public."BOMTemplateSlots"` + `public."BOMComponents"`: definición de BOM por ProductType.
- **`public."BOMInstances"`** + `public."BOMInstanceLines"`: BOM **instanciado** para una `QuoteLine` (qué piezas y cantidades quedaron).

Tablas de soporte para pricing:
- **`public."CatalogItems"`**: maestro de SKUs (incluye roll/fabric, y componentes).
- **`public."CatalogItemsMSRP"`**: costos y MSRP calculados por SKU (incluye `total_cost`, `msrp`, etc).

Tablas auxiliares (no imprescindibles para el flujo v8, pero existentes):
- **`public."QuoteLineComponents"`**: snapshot/registro de componentes y selecciones por línea.
- **`public."QuoteLineBOMSelections"`**: persistencia de selecciones de padres por línea (motor/drive/tube/etc).  
  Nota: en el dump v8 existe, pero hay funciones que la usan junto a tablas inexistentes (ver “Riesgos”).

---

## 2) Tablas clave y columnas (DUMP v8)

### 2.1 `public."Quotes"`

Columnas (principales):
- **`id`** uuid (PK)
- **`organization_id`** uuid
- **`quote_no`** text
- **`status`** `public.quote_status` (default `'draft'`)
- **`tracking_status`** `public.sales_order_tracking_status` (solo cuando `status='approved'`)
- **`customer_id`** uuid (nullable)
- **`contact_id`** uuid (nullable)
- **`company_id`** uuid (nullable)
- **`currency`** text (default `'USD'`)
- **`deleted`** boolean
- **`created_at`**, **`updated_at`**

Constraint:
- `quotes_tracking_status_only_when_approved`

FKs (relevante):
- `fk_quotes_company` → `public."Companies"(id)` ON DELETE SET NULL

---

### 2.2 `public."QuoteLines"`

Columnas (principales para configured/BOM/pricing):
- **IDs/relación**
  - **`id`** uuid (PK)
  - **`organization_id`** uuid
  - **`quote_id`** uuid (NOT NULL)
  - **`company_id`** uuid (nullable)
  - **`product_type_id`** uuid (nullable)
  - **`configured_product_id`** uuid (nullable)  ← vínculo al snapshot configurado
  - **`bom_template_id`** uuid (nullable) ← FK a template elegido
- **Medidas / atributos**
  - **`quantity`** numeric(12,4)
  - **`width_m`**, **`height_m`** numeric(12,4)
  - **`area`** text, **`position`** text
  - **`hardware_color`** text
  - **`cassette`** boolean
  - **`side_channel`** boolean
  - **`drive_type`** text (manual/motor)
- **Roll/fabric**
  - **`catalog_item_id`** uuid (roll/fabric)
  - **`collection_name`**, **`variant_name`** text
  - **`roll_width_m`** numeric(12,4)
  - **`fabric_pricing_mode`**, **`roll_type`**, etc.
- **Snapshots pricing**
  - **`roll_cost_snapshot`** numeric
  - **`bom_cost_snapshot`** numeric
  - **`roll_msrp_snapshot`** numeric
  - **`bom_msrp_snapshot`** numeric
  - **`total_cost`** numeric(12,4)
  - **`msrp`** numeric(12,4)
  - **`net_price`** numeric(12,4)
  - **`pricing_locked`** boolean
  - **`last_priced_at`** timestamptz

FKs (relevantes en dump v8):
- `fk_quote_lines_bom_template` → `public."BOMTemplates"(id)` ON DELETE SET NULL

Triggers (relevantes):
- `trg_quote_lines_generate_bom_instance` **AFTER INSERT** ejecuta `public.trg_quote_lines_generate_bom_instance_fn()`
- `trg_quote_lines_set_company_id` (before insert/update …)
- `trg_quote_lines_validate_company` (before insert/update …)

---

### 2.3 `public."ConfiguredProducts"` (snapshot del configurador)

Columnas (principales):
- **IDs/relación**
  - **`id`** uuid (PK)
  - **`organization_id`** uuid
  - **`quote_id`** uuid (nullable)
  - **`product_type_id`** uuid (NOT NULL)
  - **`bom_template_id`** uuid (NOT NULL) ← template seleccionado
- **Config snapshot**
  - **`config_snapshot`** jsonb (NOT NULL, default `{}`)
  - **`metadata`** jsonb
- **Dimensiones**
  - **`width_mm`**, **`height_mm`** numeric(12,4)
  - **`quantity`** numeric(12,4)
  - **`hardware_color`** text
- **Roll mirror**
  - **`roll_catalog_item_id`** uuid
  - **`roll_sku`**, **`roll_collection_name`**, **`roll_variant_name`** text
  - **`roll_width`** numeric(12,4)
- **Selecciones mirror (padres)**
  - `bottom_bar_item_id`, `bottom_bar_sku`
  - `headbox_item_id`, `headbox_sku`
  - `side_channel_item_id`, `side_channel_sku`
  - `bottom_channel_item_id`, `bottom_channel_sku`
  - `motor_item_id`, `motor_sku`
  - `drive_item_id`, `drive_sku`
  - `tube_item_id`, `tube_sku`
  - `operating_type` text
- **Totales MSRP**
  - **`roll_msrp_total`** numeric(12,4)
  - **`bom_total`** numeric(12,4)
  - **`roll_plus_bom_total`** numeric(12,4)
  - **`accessories_total`** numeric(12,4)
  - **`labor_pct`** numeric(5,2)
  - **`labor_amount`** numeric(12,4)
  - **`total_msrp`** numeric(12,4)
- **Totales COST**
  - **`roll_total_cost`** numeric(12,4)
  - **`bom_total_cost`** numeric(12,4)
- **Auditoría**
  - `created_at`, `updated_at`, `deleted`

FKs (dump v8):
- `configuredproducts_bom_template_fkey` → `public."BOMTemplates"(id)` ON DELETE RESTRICT
- `configuredproducts_product_type_fkey` → `public."ProductTypes"(id)` ON DELETE RESTRICT
- `configuredproducts_quote_fkey` → `public."Quotes"(id)` ON DELETE SET NULL
- `configuredproducts_roll_item_fkey` → `public."CatalogItems"(id)` ON DELETE SET NULL
- `configuredproducts_organization_fkey` → `public."Organizations"(id)` ON DELETE RESTRICT

---

### 2.4 `public."BOMTemplates"`

Columnas:
- **`id`** uuid (PK)
- **`organization_id`** uuid
- **`product_type_id`** uuid
- **`code`** text (UNIQUE por `organization_id, code`)
- **`name`** text
- **`hardware_color`** text (nullable)
- **`is_active`** boolean (default true, nullable en dump)
- **`sort_order`** int
- **`description`** text
- **`metadata`** jsonb
- **`archived`** boolean, **`deleted`** boolean
- **`created_at`**, **`updated_at`**

---

### 2.5 `public."BOMTemplateSlots"` (slots PADRE del template)

Columnas:
- **`id`** uuid (PK)
- **`organization_id`** uuid
- **`bom_template_id`** uuid
- **`item_role`** text (p.ej. `bottom_bar`, `tube`, `motor`, `drive`, `headbox`, …)
- **`required`** boolean (default true)
- **`catalog_item_id`** uuid (SKU “default”/fijo si aplica)
- **`qty`** numeric(12,4)
- **`selection_mode`** text (`user_select` | `fixed` | `none_allowed`)
- `fixed_catalog_item_id` uuid
- `slot_sku` text
- `notes` text
- `deleted`, `archived`
- `created_at`, `updated_at`

---

### 2.6 `public."BOMComponents"` (reglas por rol, qty, dependencias)

Columnas (relevantes):
- **`id`** uuid (PK)
- **`organization_id`** uuid
- **`bom_template_id`** uuid
- **`component_role`** text
- **`component_item_id`** uuid (nullable; requerido cuando `component_mode='fixed'`)
- **`slot_id`** uuid (nullable)  ← link a `BOMTemplateSlots`
- **`parent_component_id`** uuid (nullable)  ← para jerarquía padre→hijo
- **Qty rules**
  - `qty_type` text (`fixed`, `per_width`, `per_height`, `per_area`, …)
  - `qty_value` numeric
  - `qty_delta_mm` numeric
  - `waste_pct` numeric
  - `qty_spacing_mm`, `qty_min`
- **Otros**
  - `uom` text
  - `auto_select` boolean
  - `sku_resolution_rule` text
  - `depends_on_role` text
  - `cut_axis`, `cut_delta_mm`
  - `sort_order` int
  - `component_mode` `public.bom_component_mode` (auto/select/fixed/optional…)
  - `is_required` boolean
  - `component_scope` text
  - `metadata` jsonb
  - `deleted`, `archived`, `created_at`, `updated_at`

---

### 2.7 `public."BOMInstances"` (instancia por QuoteLine)

Columnas:
- **`id`** uuid (PK)
- **`organization_id`** uuid
- **`quote_line_id`** uuid (NOT NULL)
- **`bom_template_id`** uuid (NOT NULL)
- **`configured_product_id`** uuid (nullable)
- `deleted`, `archived`
- `created_at`, `updated_at`

---

### 2.8 `public."BOMInstanceLines"` (líneas resueltas del BOM)

Columnas:
- **`id`** uuid (PK)
- **`organization_id`** uuid
- **`bom_instance_id`** uuid (NOT NULL)
- **`bom_component_id`** uuid (nullable)
- **`resolved_part_id`** uuid (nullable) ← FK a `CatalogItems`
- **`part_role`** text
- **`qty`** numeric(12,4)
- **`uom`** text
- `cut_length_mm`, `cut_width_mm`, `cut_height_mm`
- `unit_cost_exw`, `total_cost_exw`
- `deleted`, `archived`
- `created_at`

Vista útil:
- `public."BOMInstanceLinesOrdered"`: join con `CatalogItems` y `BOMComponents` para ordenar por rol.

---

### 2.9 `public."CatalogItems"` + `public."CatalogItemsMSRP"`

`CatalogItems` (mínimo relevante):
- `id` uuid, `organization_id` uuid
- `sku` text, `name` text
- `unit_of_measure` text
- `cost_exw` numeric
- `is_roll` boolean, `roll_type` enum, `roll_width_m` numeric, `collection_name`, `variant_name`
- `is_active` boolean

`CatalogItemsMSRP` (pricing “calculado” por SKU):
- `catalog_item_id` uuid (PK)
- `organization_id` uuid
- `cost_exw`, `import_tax_cost`, `shipping_cost`, **`total_cost`**
- `shipping_pct`, `import_tax_pct`, `minimum_margin_pct`, `msrp_pct_sale_out`
- **`dealer_price`**, **`msrp`**
- `sku`, `name`, `collection_name`, `variant_name`, `unit_of_measure`
- `updated_at`

---

### 2.10 Tablas auxiliares

`public."QuoteLineComponents"`:
- `organization_id`, `quote_line_id`
- `component_role` text, `kind` text, `source` text
- `catalog_item_id` uuid (nullable)
- `qty`, `unit_cost_exw`
- `payload` jsonb
- `deleted`, `archived`, `created_at`, `updated_at`

`public."QuoteLineBOMSelections"`:
- `organization_id`, `quote_line_id`, `component_role`, `catalog_item_id`
- UNIQUE: (`quote_line_id`, `component_role`)
- FKs:
  - `QuoteLineBOMSelections_quote_line_id_fkey` → `public."QuoteLines"(id)` ON DELETE CASCADE
  - `QuoteLineBOMSelections_catalog_item_id_fkey` → `public."CatalogItems"(id)`

---

## 3) Flujo end-to-end (Quote → Configured → QuoteLine → BOM)

### 3.1 Crear Quote
1) Insert en `public."Quotes"`.
2) Se maneja estado (`status`) y moneda (`currency`).

### 3.2 Configurar producto (antes de crear QuoteLine)
1) El configurador construye un **`config_snapshot`** (JSONB).
2) Se resuelve un **`bom_template_id`** que represente exactamente la combinación (color + bottom_bar + tube + motor/drive + opcionales).
3) Se inserta un **`public."ConfiguredProducts"`** con:
   - `bom_template_id`, `product_type_id`, medidas, roll, selecciones mirror
   - `config_snapshot` completo
4) Se ejecuta `public.calculate_configured_product_totals(configured_product_id)` para llenar:
   - `roll_msrp_total`, `bom_total`, `roll_plus_bom_total`, `total_msrp`
   - `roll_total_cost`, `bom_total_cost`

RPC del dump v8:
- `public.create_configured_product_and_bom_preview(p_org_id, p_product_type_id, p_config_snapshot, p_quote_id, p_quote_line_id)`
  - Crea `ConfiguredProducts`.
  - **No crea BOMInstance** si `p_quote_line_id` es NULL.

### 3.3 Crear QuoteLine (snapshot comercial)
1) Insert en `public."QuoteLines"` con:
   - `quote_id`, medidas, `catalog_item_id` (roll), `drive_type`, etc.
   - `configured_product_id`
   - `bom_template_id`
   - snapshots (`roll_*_snapshot`, `bom_*_snapshot`, `msrp`, `total_cost`, …) tomados de `ConfiguredProducts`

2) **BOM Instance**
Hay 2 mecanismos en el dump v8:

- **A) Trigger en QuoteLines (fallback automático)**  
  Trigger: `trg_quote_lines_generate_bom_instance` AFTER INSERT → `trg_quote_lines_generate_bom_instance_fn()`:
  - Si ya existe `BOMInstances` para la línea, no hace nada.
  - Si `new.bom_template_id is not null`, **NO autogenera**.
  - Si `bom_template_id` es NULL, intenta resolver `product_type_id` (desde `QuoteLines` o desde `ConfiguredProducts`) y llama:
    - `public.generate_bom_instance_for_quote_line(new.organization_id, new.id, v_product_type_id)`

- **B) BOM explícito desde ConfiguredProducts (recomendado para consistencia)**  
  RPC: `public.create_bom_instance_for_configured_product(p_org_id, p_quote_line_id, p_configured_product_id, p_product_type_id)`  
  Internamente llama `public.generate_bom_from_slots_for_configured_product(...)`:
  - **Requiere** `quote_line_id` NOT NULL.
  - Usa `ConfiguredProducts.bom_template_id` y `ConfiguredProducts.config_snapshot`.
  - Inserta `BOMInstances` y luego `BOMInstanceLines` iterando `BOMTemplateSlots` (PADRES) y expandiendo HIJOS vía `CatalogItemComponents`.

### 3.4 Pricing “congelado”
- `ConfiguredProducts` se recalcula (totals) con `calculate_configured_product_totals`.
- `QuoteLines` guarda snapshots (`*_snapshot`, `msrp`, `total_cost`, …) para no depender de cambios futuros en `CatalogItemsMSRP`.

---

## 4) Matching de BOMTemplate (funciones del dump v8)

### 4.1 `select_best_bom_template_for_configured_product(p_org_id, p_product_type_id, p_config_snapshot)`
Función que:
- Lee `hardware_color`, `bottom_bar_sku`, `tube_sku`, `motor_sku`/`drive_sku`, etc desde `config_snapshot`.
- Filtra/scorea templates comprobando existencia de slots en `BOMTemplateSlots` + `CatalogItems.sku`.
- Prioriza operating type:
  - `motor` si hay `motor_sku`
  - `manual` si hay `drive_sku`

### 4.2 `select_best_bom_template_v2_strict(p_org, p_product_type, p_config)`
Otra función “estricta” (v2) que exige:
- `tube_id` y `bottom_bar_id`
- XOR entre `drive_id` y `motor_id`

### 4.3 `select_exact_bom_template_for_quote_line(...)` (⚠️ riesgo)
En el dump v8 existe, pero **hace JOIN con `public."BOMTemplateComponents"`**, tabla que **no existe** en el mismo dump (en v8 se usa `BOMComponents` + `BOMTemplateSlots`).  
Esto es una fuente de errores típicos de “relation does not exist”.

---

## 5) Riesgos / inconsistencias detectadas (relevantes para re-arquitectura)

- **Drift de schema entre DB real y dump**:
  - Se han visto errores en runtime tipo: `column t.is_active does not exist` (funciones que construyen SQL dinámico).
  - Aunque `BOMTemplates.is_active` existe en el dump v8, puede faltar en el entorno real, o puede variar el alias/SQL.

- **Función “exact match” rota**:
  - `select_exact_bom_template_for_quote_line` referencia `BOMTemplateComponents` (inexistente).

- **Doble motor de matching**:
  - RPC `create_configured_product_and_bom_preview` resuelve template por su cuenta (vía `select_best_bom_template_for_configured_product`).
  - En frontend puede resolverse template de otra forma.
  - Recomendación: **unificar** la fuente de verdad del template (idealmente DB strict + “candidate_template_ids” cuando aplique).

---

## 6) Recomendación de reestructuración (para reducir tiempo y bugs)

- **`ConfiguredProducts` como source-of-truth** de configuración + pricing:
  - Se crea/actualiza durante el configurador.
  - `QuoteLines` se crea/finaliza desde `ConfiguredProducts` (snapshots).
- **BOMInstances siempre explícito** vía `create_bom_instance_for_configured_product` después de crear QuoteLine:
  - Evitar depender del trigger `trg_quote_lines_generate_bom_instance` (solo dejarlo como fallback legacy).
- **Un solo mecanismo de matching**:
  - Preferible: `select_best_bom_template_v2_strict` (IDs) o una versión estricta equivalente basada en `BOMComponents`/`BOMTemplateSlots`.
  - Permitir “candidate templates” provenientes del filtrado progresivo para eliminar ambigüedad.

