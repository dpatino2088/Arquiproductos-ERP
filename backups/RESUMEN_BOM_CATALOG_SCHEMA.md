# Resumen: Esquema BOM y Catalog (2026-01-19)

Este documento resume todas las estructuras relacionadas con **BOM (Bill of Materials)** y **Catalog** del dump SQL `2026-01-19full.sql`.

---

## 📦 TABLAS BOM

### 1. `BOMTemplates`
**Descripción:** Plantillas de BOM que definen la estructura de materiales para diferentes configuraciones de productos.

**Columnas principales:**
- `id` (uuid, PK)
- `organization_id` (uuid, NOT NULL)
- `product_type_id` (uuid, FK → ProductTypes)
- `code` (text, NOT NULL) - Código único por organización
- `name` (text, NOT NULL)
- `description` (text)
- `metadata` (jsonb, default '{}') - Almacena compatibilidad, prioridad, reglas
- `active` (boolean, default true)
- `deleted` (boolean, default false)
- `archived` (boolean, default false)
- `product_type` (text) - Campo legacy
- `headbox_type` (enum: 'none', 'cassette')
- `system_size` (enum: 's', 'm', 'l', 'xl')
- `color` (text)
- `side_channel_mode` (enum: 'none', 'side_only', 'side_plus_bottom')
- `operating_system` (enum: 'manual', 'motor')
- `is_active` (boolean, default true)

**Constraints:**
- `BOMTemplates_unique_code`: UNIQUE (`organization_id`, `code`)

**Índices:**
- `bomtemplates_fingerprint_unique`: UNIQUE sobre (`organization_id`, `product_type`, `headbox_type`, `system_size`, `color`, `side_channel_mode`, `operating_system`) WHERE `deleted = false`
- `idx_bomtemplates_org_type`: (`organization_id`, `product_type_id`) WHERE `deleted = false AND archived = false AND active = true`

---

### 2. `BOMComponents`
**Descripción:** Componentes individuales que forman parte de un `BOMTemplate`. Define qué items del catálogo se usan y cómo se calculan las cantidades.

**Columnas principales:**
- `id` (uuid, PK)
- `organization_id` (uuid, NOT NULL)
- `bom_template_id` (uuid, FK → BOMTemplates)
- `component_item_id` (uuid, FK → CatalogItems, nullable) - Item fijo si `component_mode = 'fixed'`
- `component_role` (text, NOT NULL) - Rol del componente (ej: 'tube', 'motor', 'drive')
- `qty_type` (text, default 'fixed') - Tipo de cálculo: 'fixed', 'per_width', 'per_height', 'per_area'
- `qty_value` (numeric(12,4), default 1)
- `qty_delta_mm` (numeric(12,4), default 0) - Ajuste en mm para cálculos
- `uom` (text, default 'ea') - Unidad de medida
- `waste_pct` (numeric(7,4), default 0) - Porcentaje de desperdicio
- `auto_select` (boolean, default true)
- `sku_resolution_rule` (text, default 'ROLE_AND_COLOR') - Regla para resolver SKU: 'ROLE_AND_COLOR', 'FABRIC_BY_COLLECTION_VARIANT'
- `depends_on_role` (text, nullable) - Rol del que depende este componente
- `cut_axis` (text, nullable) - Eje de corte: 'length', 'width', 'height'
- `cut_delta_mm` (numeric(12,4), default 0)
- `sort_order` (integer, default 0)
- `deleted` (boolean, default false)
- `archived` (boolean, default false)
- `component_mode` (enum, default 'auto') - 'select', 'fixed', 'auto', 'optional'

**Constraints:**
- `bomcomponents_component_role_check`: Valida que `component_role` esté en lista permitida (26 roles)
- `bomcomponents_depends_on_role_check`: Valida `depends_on_role` si no es NULL
- `bomcomponents_fixed_requires_item`: Si `component_mode = 'fixed'`, entonces `component_item_id` debe ser NOT NULL

**Índices:**
- `idx_bomcomponents_template`: (`organization_id`, `bom_template_id`) WHERE `deleted = false AND archived = false`
- `idx_bomcomponents_role`: (`organization_id`, `component_role`) WHERE `deleted = false AND archived = false`

---

### 3. `BOMInstances`
**Descripción:** Instancias generadas de BOM para una línea de cotización específica. Representa el BOM "resuelto" para un producto configurado.

**Columnas principales:**
- `id` (uuid, PK)
- `organization_id` (uuid, NOT NULL)
- `quote_line_id` (uuid, FK → QuoteLines, NOT NULL)
- `bom_template_id` (uuid, FK → BOMTemplates, NOT NULL)
- `deleted` (boolean, default false)
- `created_at`, `updated_at` (timestamps)

**Constraints:**
- `bominstances_unique_quote_line`: UNIQUE (`organization_id`, `quote_line_id`) WHERE `deleted = false`

---

### 4. `BOMInstanceLines`
**Descripción:** Líneas individuales de una instancia de BOM. Cada línea representa un componente resuelto con su cantidad calculada y costos.

**Columnas principales:**
- `id` (uuid, PK)
- `bom_instance_id` (uuid, FK → BOMInstances)
- `bom_component_id` (uuid, FK → BOMComponents, nullable)
- `resolved_part_id` (uuid, FK → CatalogItems, NOT NULL) - Item del catálogo resuelto
- `part_role` (text, NOT NULL) - Rol del componente
- `qty` (numeric(12,4), NOT NULL) - Cantidad calculada
- `uom` (text, NOT NULL) - Unidad de medida
- `cut_length_mm`, `cut_width_mm`, `cut_height_mm` (numeric(12,4), nullable) - Dimensiones de corte
- `unit_cost_exw` (numeric(12,4), nullable) - Costo unitario EXW
- `total_cost_exw` (numeric(12,4), nullable) - Costo total (unit_cost × qty)
- `created_at` (timestamp)

**Constraints:**
- `bominstancelines_part_role_check`: Valida que `part_role` esté en lista permitida

**Índices:**
- `idx_bominstancelines_instance`: (`bom_instance_id`)

---

### 5. `BOMTemplateSlots`
**Descripción:** Slots/espacios definidos en un template que pueden ser llenados con items específicos del catálogo.

**Columnas principales:**
- `id` (uuid, PK)
- `organization_id` (uuid, NOT NULL)
- `bom_template_id` (uuid, FK → BOMTemplates)
- `item_role` (text, NOT NULL) - Rol del item requerido
- `required` (boolean, default true)
- `catalog_item_id` (uuid, FK → CatalogItems, nullable) - Item específico si está predefinido
- `qty` (numeric(12,4), default 1)
- `notes` (text)
- `created_at`, `updated_at` (timestamps)

**Constraints:**
- `bomtemplateslots_item_role_check`: Valida que `item_role` esté en lista permitida

**Índices:**
- `bomtemplateslots_template_idx`: (`bom_template_id`)
- `bomtemplateslots_role_idx`: (`item_role`)

---

## 📚 TABLAS CATALOG

### 1. `CatalogItems`
**Descripción:** Tabla principal del catálogo. Almacena todos los items (componentes, telas, accesorios, etc.).

**Columnas principales:**
- `id` (uuid, PK)
- `organization_id` (uuid, NOT NULL)
- `sku` (text, NOT NULL) - SKU único por organización
- `name` (text, NOT NULL)
- `description` (text)
- `category_id` (uuid, FK → CatalogCategories, nullable)
- `image_url` (text)
- `measure_basis` (text, NOT NULL) - 'unit', 'linear', 'area'
- `unit_of_measure` (text, NOT NULL) - 'ea', 'm', 'm2', etc.
- `is_fabric` (boolean, default false)
- `is_roll` (boolean, default false)
- `roll_type` (enum, nullable) - 'fabric', 'window_film', 'vinyl', 'mesh', 'paper', 'other' (solo si `is_roll = true`)
- `roll_collection_id` (uuid, nullable)
- `collection_name` (text, nullable) - Para items tipo roll
- `variant_name` (text, nullable) - Variante/color para items tipo roll
- `roll_width` (numeric(12,4), nullable)
- `fabric_pricing_mode` (text, nullable) - 'per_linear_m', 'per_sqm'
- `color` (text, nullable) - Para items no-roll (hardware)
- `item_role` (text, nullable, FK → CatalogItemRoles) - Rol del item (ej: 'motor', 'drive', 'tube', 'headbox')
- `cost_exw` (numeric(12,4), nullable) - Costo EXW (Ex Works)
- `manufacturer` (text, nullable)
- `manufacturer_id` (uuid, FK → Manufacturers, nullable)
- `is_active` (boolean, default true)
- `created_at`, `updated_at` (timestamps)

**Constraints:**
- `CatalogItems_organization_id_sku_key`: UNIQUE (`organization_id`, `sku`)
- `catalogitems_roll_type_requires_is_roll`: Si `roll_type` no es NULL, entonces `is_roll` debe ser true

**Índices:**
- `catalogitems_org_idx`: (`organization_id`)
- `catalogitems_category_idx`: (`organization_id`, `category_id`)
- `catalogitems_manufacturer_id_idx`: (`organization_id`, `manufacturer_id`)
- `catalogitems_org_roll_collection_idx`: (`organization_id`, `roll_collection_id`)
- `idx_catalogitems_org_role`: (`organization_id`, `item_role`) WHERE `is_active = true`
- `idx_catalogitems_org_role_color`: (`organization_id`, `item_role`, `color`) WHERE `is_active = true AND is_roll = false`
- `idx_catalogitems_roll_lookup`: (`organization_id`, `collection_name`, `variant_name`) WHERE `is_active = true AND is_roll = true`

**Triggers:**
- `trg_catalogitems_sync_collection_name`: Sincroniza `collection_name` desde `roll_collection_id`
- `trg_catalogitems_sync_manufacturer`: Sincroniza `manufacturer_id` desde `manufacturer` (texto)
- `trg_enforce_active_item_role`: Valida que `item_role` esté activo en `CatalogItemRoles`
- `trig_items_msrp`: Calcula MSRP automáticamente cuando cambia `cost_exw` o `category_id`

---

### 2. `CatalogCategories`
**Descripción:** Categorías jerárquicas para organizar items del catálogo.

**Columnas principales:**
- `id` (uuid, PK)
- `organization_id` (uuid, NOT NULL)
- `name` (text, NOT NULL)
- `sort_order` (integer, default 0)
- `parent_id` (uuid, FK → CatalogCategories, nullable) - Para jerarquías
- `created_at`, `updated_at` (timestamps)

**Constraints:**
- `catalogcategories_parent_not_self`: `parent_id` no puede ser igual a `id`

**Índices:**
- `catalogcategories_org_idx`: (`organization_id`)
- `catalogcategories_parent_idx`: (`organization_id`, `parent_id`)
- `catalogcategories_org_parent_lowername_uidx`: UNIQUE (`organization_id`, `parent_id`, `lower(name)`)
- `catalogcategories_unique_siblings`: UNIQUE (`organization_id`, `parent_id`, `lower(name)`)

---

### 3. `CatalogItemProductTypes`
**Descripción:** Tabla de relación muchos-a-muchos entre `CatalogItems` y `ProductTypes`. Un item puede pertenecer a múltiples tipos de producto.

**Columnas principales:**
- `id` (uuid, PK)
- `organization_id` (uuid, NOT NULL)
- `catalog_item_id` (uuid, FK → CatalogItems)
- `product_type_id` (uuid, FK → ProductTypes)
- `created_at` (timestamp)

**Constraints:**
- `catalogitemproducttypes_unique`: UNIQUE (`organization_id`, `catalog_item_id`, `product_type_id`)

**Índices:**
- `catalogitemproducttypes_by_item`: (`organization_id`, `catalog_item_id`)
- `catalogitemproducttypes_by_type`: (`organization_id`, `product_type_id`)

---

### 4. `CatalogItemRoles`
**Descripción:** Catálogo maestro de roles permitidos para items (ej: 'motor', 'drive', 'tube', 'headbox', etc.).

**Columnas principales:**
- `role_code` (text, PK) - Código del rol (ej: 'motor', 'drive')
- `label` (text, NOT NULL) - Etiqueta legible
- `description` (text)
- `default_category_id` (uuid, FK → CatalogCategories, nullable)
- `sort_order` (integer, default 0)
- `active` (boolean, default true)
- `created_at`, `updated_at` (timestamps)

**Triggers:**
- `trg_catalog_item_roles_updated_at`: Actualiza `updated_at` automáticamente

---

### 5. `CatalogItemsMSRP`
**Descripción:** Tabla de cache para MSRP calculados. Almacena los resultados del cálculo de MSRP para evitar recalcular.

**Columnas principales:**
- `catalog_item_id` (uuid, PK, FK → CatalogItems)
- `organization_id` (uuid, NOT NULL)
- `category_id` (uuid, nullable)
- `cost_exw` (numeric(12,4), NOT NULL) - Costo base
- `import_tax_cost` (numeric(12,4), NOT NULL) - Costo de impuestos
- `shipping_cost` (numeric(12,4), NOT NULL) - Costo de envío
- `total_cost` (numeric(12,4), NOT NULL) - Costo total (cost_exw + tax + shipping)
- `msrp_sale_in` (numeric(12,4), NOT NULL) - MSRP para venta interna
- `msrp_sale_out` (numeric(12,4), NOT NULL) - MSRP para venta externa

**Índices:**
- `idx_catalogitemsmsrp_org`: (`organization_id`)
- `idx_catalogitemsmsrp_cat`: (`category_id`)

---

### 6. `CatalogRoleCategoryMap`
**Descripción:** Mapeo de roles a categorías por organización. Permite asignar categorías por defecto según el rol.

**Columnas principales:**
- `organization_id` (uuid, PK)
- `role_code` (text, PK, FK → CatalogItemRoles)
- `target_category_id` (uuid, FK → CatalogCategories, NOT NULL)
- `notes` (text)
- `updated_at` (timestamp)

---

### 7. `CatalogRoleRelations`
**Descripción:** Define relaciones entre roles (ej: 'motor' requiere 'adapter', 'tube' es parte de 'track').

**Columnas principales:**
- `id` (uuid, PK)
- `organization_id` (uuid, NOT NULL)
- `parent_role` (text, NOT NULL) - Rol padre
- `child_role` (text, NOT NULL) - Rol hijo
- `relation_type` (enum, NOT NULL) - 'part_of', 'install_requires', 'compatibility_optional'
- `conditions` (jsonb, default '{}') - Condiciones adicionales
- `qty_rule` (jsonb, default '{}') - Reglas de cantidad
- `active` (boolean, default true)
- `created_at`, `updated_at` (timestamps)

**Constraints:**
- `CatalogRoleRelations_organization_id_parent_role_child_role_key`: UNIQUE sobre (`organization_id`, `parent_role`, `child_role`, `relation_type`, `conditions`)

---

## 🔧 FUNCIONES BOM

### 1. `generate_bom_instance_for_quote_line(p_org_id, p_quote_line_id, p_product_type_id)`
**Tipo:** `plpgsql`  
**Retorna:** `uuid` (ID de la instancia creada)

**Descripción:** Genera una instancia de BOM para una línea de cotización. Resuelve el template más adecuado, calcula cantidades y costos, y crea las líneas de instancia.

**Proceso:**
1. Obtiene la configuración de la línea de cotización desde `QuoteLineComponents`
2. Selecciona el mejor template usando `select_best_bom_template()`
3. Soft-delete de instancias previas
4. Crea nueva instancia
5. Itera sobre `BOMComponents` del template:
   - Calcula cantidad según `qty_type` (fixed, per_width, per_height, per_area)
   - Aplica `waste_pct` si existe
   - Resuelve el item usando `resolve_component_item_id()`
   - Obtiene `cost_exw` del item
   - Inserta línea en `BOMInstanceLines` con dimensiones de corte y costos

---

### 2. `select_best_bom_template(p_org_id, p_product_type_id, p_config)`
**Tipo:** `plpgsql STABLE`  
**Retorna:** `uuid` (ID del template)

**Descripción:** Selecciona el mejor template de BOM basado en la configuración (JSONB). Usa scoring por compatibilidad en `metadata->'compat'`.

**Lógica:**
- Filtra templates activos, no eliminados, no archivados
- Calcula score contando matches en `metadata->'compat'` con `p_config`
- Ordena por: score DESC, priority DESC, updated_at DESC
- Retorna el primero o lanza excepción si no hay match

---

### 3. `select_best_bom_template_for_quote_line(p_org_id, p_product_type_id, p_quote_line_id)`
**Tipo:** `plpgsql STABLE`  
**Retorna:** `uuid` (ID del template)

**Descripción:** Versión legacy que obtiene opciones desde `QuoteLineComponents` y selecciona template. Similar a `select_best_bom_template()` pero lee desde la línea de cotización.

---

### 4. `resolve_component_item_id(p_org_id, p_component_role, p_sku_rule, p_quote_line_id, p_config, p_fixed_component_item_id, p_override_item_id)`
**Tipo:** `plpgsql STABLE`  
**Retorna:** `uuid` (ID del item resuelto)

**Descripción:** Resuelve qué `CatalogItem` usar para un componente dado. Prioriza override → fixed → resolución dinámica.

**Reglas de resolución:**
1. **Override:** Si `p_override_item_id` existe, retorna ese
2. **Fixed:** Si `p_fixed_component_item_id` existe, retorna ese
3. **Fabric:** Si `p_sku_rule = 'FABRIC_BY_COLLECTION_VARIANT'` o `component_role = 'fabric'`:
   - Busca por `collection_name` + `variant_name` en `CatalogItems` donde `is_roll = true`
4. **Hardware (ROLE_AND_COLOR):** 
   - Extrae `hardware_color` de `p_config`
   - Busca por `item_role` + `color` en `CatalogItems` donde `is_roll = false`
   - Valida que haya exactamente 1 match (evita ambigüedad)

---

### 5. `resolve_catalog_item_for_bom_component(p_org_id, p_quote_line_id, p_component_role, p_component_item_id)`
**Tipo:** `plpgsql STABLE`  
**Retorna:** `uuid` (ID del item)

**Descripción:** Función legacy para resolver items. Similar a `resolve_component_item_id()` pero más simple.

**Lógica:**
1. Si `p_component_item_id` existe, retorna ese
2. Si `component_role = 'fabric'`, busca por `collection_name` + `variant_name` desde `QuoteLines`
3. Si hay `hardware_color` en opciones, busca por `item_role` + `color`
4. Fallback: busca solo por `item_role`

---

### 6. `build_quote_line_config(p_org_id, p_quote_line_id)`
**Tipo:** `sql STABLE`  
**Retorna:** `jsonb`

**Descripción:** Construye un objeto JSONB con todas las opciones de configuración de una línea de cotización desde `QuoteLineComponents` donde `kind = 'option'`.

**Estructura retornada:**
```jsonb
{
  "hardware_color": {"hardware_color": "White"},
  "drive_type": {"drive_type": "motor"},
  "system_size": {"system_size": "standard_m"},
  ...
}
```

---

## 🔧 FUNCIONES CATALOG

### 1. `msrp_compute_for_item(item_id)`
**Tipo:** `plpgsql SECURITY DEFINER`  
**Retorna:** `void`

**Descripción:** Calcula MSRP (Manufacturer's Suggested Retail Price) para un item y lo guarda en `CatalogItemsMSRP`.

**Proceso:**
1. Obtiene `cost_exw`, `category_id`, `organization_id` del item
2. Obtiene `shipping_pct` y `global_import_tax_pct` desde `CostSettings`
3. Si hay `category_id`, obtiene `import_tax_pct` desde `ImportTaxRules` (override)
4. Obtiene `msrp_pct_sale_in` y `msrp_pct_sale_out` desde `CategoryMargins` (por categoría) o fallback a `CostSettings`
5. Calcula:
   - `import_tax_cost = cost_exw × import_tax_pct`
   - `shipping_cost = cost_exw × shipping_pct`
   - `total_cost = cost_exw + import_tax_cost + shipping_cost`
   - `msrp_sale_in = total_cost / (1 - msrp_pct_sale_in)`
   - `msrp_sale_out = msrp_sale_in / (1 - msrp_pct_sale_out)`
6. Guarda/actualiza en `CatalogItemsMSRP` (UPSERT por `catalog_item_id`)

**Triggers que la llaman:**
- `trig_items_msrp`: Se ejecuta cuando cambia `cost_exw` o `category_id` en `CatalogItems`
- `trig_catmargins_msrp`: Se ejecuta cuando cambian porcentajes en `CategoryMargins` (recalcula todos los items de esa categoría)

---

### 2. `get_category_id_by_path(p_org, p_path)`
**Tipo:** `plpgsql STABLE`  
**Retorna:** `uuid` (ID de categoría)

**Descripción:** Resuelve el ID de una categoría desde un path jerárquico (ej: "Components > Tracks").

**Lógica:**
- Divide el path por `>` (regex: `\s*>\s*`)
- Navega la jerarquía desde raíz (`parent_id IS NULL`) hasta la hoja
- Retorna NULL si no encuentra

---

### 3. `enforce_active_item_role()`
**Tipo:** `plpgsql TRIGGER`  
**Retorna:** `trigger`

**Descripción:** Valida que `item_role` en `CatalogItems` esté activo en `CatalogItemRoles` antes de insertar/actualizar.

**Trigger:**
- `trg_enforce_active_item_role`: BEFORE INSERT OR UPDATE OF `item_role` ON `CatalogItems`

---

### 4. `sync_catalogitem_collection_name_from_roll_collection()`
**Tipo:** `plpgsql TRIGGER`  
**Retorna:** `trigger`

**Descripción:** Sincroniza `collection_name` desde `roll_collection_id` cuando se inserta/actualiza un item tipo roll.

**Trigger:**
- `trg_catalogitems_sync_collection_name`: BEFORE INSERT OR UPDATE OF `roll_collection_id` ON `CatalogItems`

---

### 5. `sync_catalogitems_manufacturer()`
**Tipo:** `plpgsql TRIGGER`  
**Retorna:** `trigger`

**Descripción:** Sincroniza `manufacturer_id` desde el texto `manufacturer`. Crea el manufacturer si no existe (case-insensitive).

**Trigger:**
- `trg_catalogitems_sync_manufacturer`: BEFORE INSERT OR UPDATE OF `manufacturer`, `organization_id` ON `CatalogItems`

---

### 6. `catalogitems_set_to_base_factor()`
**Tipo:** `plpgsql TRIGGER`  
**Retorna:** `trigger`

**Descripción:** Calcula `to_base_m_factor` para items con `measure_basis = 'linear'` según `purchase_uom`:
- `'m'` → 1.0
- `'yd'` → 0.9144
- `'ft'` → 0.3048

---

## 🔗 RELACIONES Y FOREIGN KEYS

### BOM → Catalog
- `BOMComponents.component_item_id` → `CatalogItems.id`
- `BOMInstanceLines.resolved_part_id` → `CatalogItems.id`
- `BOMTemplateSlots.catalog_item_id` → `CatalogItems.id`

### BOM → ProductTypes
- `BOMTemplates.product_type_id` → `ProductTypes.id`

### Catalog → Catalog
- `CatalogItems.category_id` → `CatalogCategories.id`
- `CatalogCategories.parent_id` → `CatalogCategories.id`
- `CatalogItemProductTypes.catalog_item_id` → `CatalogItems.id`
- `CatalogItemProductTypes.product_type_id` → `ProductTypes.id`
- `CatalogItems.item_role` → `CatalogItemRoles.role_code`
- `CatalogItemsMSRP.catalog_item_id` → `CatalogItems.id` (ON DELETE CASCADE)
- `CatalogRoleCategoryMap.role_code` → `CatalogItemRoles.role_code`
- `CatalogRoleCategoryMap.target_category_id` → `CatalogCategories.id`

### Catalog → Otros
- `CatalogItems.manufacturer_id` → `Manufacturers.id`

---

## 📊 ÍNDICES CLAVE

### BOM
- `bominstances_unique_quote_line`: Garantiza una sola instancia activa por línea de cotización
- `bomtemplates_fingerprint_unique`: Garantiza templates únicos por fingerprint (combinación de atributos)
- `idx_bomtemplates_org_type`: Búsqueda rápida de templates por organización y tipo de producto
- `idx_bomcomponents_template`: Búsqueda rápida de componentes por template
- `idx_bomcomponents_role`: Búsqueda rápida de componentes por rol

### Catalog
- `CatalogItems_organization_id_sku_key`: SKU único por organización
- `idx_catalogitems_org_role`: Búsqueda rápida de items por organización y rol
- `idx_catalogitems_org_role_color`: Búsqueda rápida de hardware por rol y color
- `idx_catalogitems_roll_lookup`: Búsqueda rápida de telas por collection + variant
- `catalogitemproducttypes_unique`: Un item solo puede estar asociado una vez a un tipo de producto

---

## 🎯 ROLES PERMITIDOS (Component Roles)

Los siguientes roles están permitidos en `BOMComponents.component_role`, `BOMInstanceLines.part_role`, `BOMTemplateSlots.item_role`, y `CatalogItems.item_role`:

1. `tube` - Tubo
2. `track` - Riel
3. `bottom_bar` - Barra inferior
4. `bottom_channel` - Canal inferior
5. `hem_weight` - Peso de dobladillo
6. `side_channel` - Canal lateral
7. `top_rail` - Riel superior
8. `headbox` - Caja superior (cassette)
9. `bracket` - Soporte
10. `idler` - Polea
11. `drive` - Accionamiento manual
12. `motor` - Motor
13. `adapter` - Adaptador
14. `chain` - Cadena
15. `chain_stop` - Parada de cadena
16. `chain_tensioner` - Tensor de cadena
17. `wand` - Varilla
18. `end_cap` - Tapa final
19. `filler` - Relleno
20. `tape` - Cinta
21. `consumable` - Consumible
22. `fastener` - Sujeción
23. `accessory` - Accesorio
24. `carrier` - Portador
25. `belt` - Correa
26. `belt_connector` - Conector de correa

---

## 🔄 FLUJO DE GENERACIÓN DE BOM

1. **Usuario configura producto** en `ProductConfigurator`
2. **Se guarda configuración** en `QuoteLineComponents` (kind='option')
3. **Se crea/actualiza `QuoteLine`** con medidas y opciones básicas
4. **Se llama `generate_bom_instance_for_quote_line()`**:
   - Construye config desde `QuoteLineComponents`
   - Selecciona mejor template con `select_best_bom_template()`
   - Crea `BOMInstance`
   - Itera `BOMComponents` del template:
     - Calcula cantidad según tipo
     - Resuelve item con `resolve_component_item_id()`
     - Obtiene costos
     - Crea `BOMInstanceLine`
5. **Resultado:** `BOMInstance` con todas sus `BOMInstanceLines` listas para producción

---

## 💰 FLUJO DE CÁLCULO DE MSRP

1. **Se inserta/actualiza `CatalogItem`** con `cost_exw` o `category_id`
2. **Trigger `trig_items_msrp`** se ejecuta
3. **Se llama `msrp_compute_for_item()`**:
   - Obtiene costos base y porcentajes
   - Calcula impuestos y envío
   - Calcula MSRP sale_in y sale_out
   - Guarda en `CatalogItemsMSRP`
4. **Resultado:** MSRP disponible en `CatalogItemsMSRP` para cotizaciones

---

## 📝 NOTAS IMPORTANTES

1. **Soft Delete:** Todas las tablas BOM y Catalog usan `deleted = false` para soft delete. Los índices únicos incluyen `WHERE deleted = false`.

2. **Archived vs Deleted:** 
   - `deleted = true`: Item eliminado (no se muestra)
   - `archived = true`: Item archivado (se muestra pero no se usa en nuevos BOMs)

3. **Active vs Is_Active:**
   - `BOMTemplates.active`: Controla si el template está activo
   - `BOMTemplates.is_active`: Campo legacy (duplicado)
   - `CatalogItems.is_active`: Controla si el item está activo

4. **Metadata en BOMTemplates:**
   - `metadata->'compat'`: Define compatibilidad con configuraciones (ej: `{"hardware_color": ["White", "Black"], "drive_type": ["motor"]}`)
   - `metadata->'priority'`: Prioridad numérica para selección de template
   - `metadata->'rules'`: Reglas adicionales (ej: `{"tube_total_target_mm": 100}`)

5. **SKU Resolution Rules:**
   - `'ROLE_AND_COLOR'`: Busca por `item_role` + `color` (hardware)
   - `'FABRIC_BY_COLLECTION_VARIANT'`: Busca por `collection_name` + `variant_name` (telas)

6. **Quantity Types:**
   - `'fixed'`: Cantidad fija (`qty_value`)
   - `'per_width'`: Cantidad por ancho (`(width_mm + qty_delta_mm) / 1000 × qty_value`)
   - `'per_height'`: Cantidad por alto
   - `'per_area'`: Cantidad por área (`width_m × height_m × qty_value`)

---

## 🔐 RLS (Row Level Security)

**Nota:** El dump no muestra políticas RLS específicas para tablas BOM y Catalog, pero las tablas tienen RLS habilitado. Las políticas se definen en migraciones separadas.

---

**Última actualización:** 2026-01-19  
**Fuente:** `backups/2026-01-19full.sql`
