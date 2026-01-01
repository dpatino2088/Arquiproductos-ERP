# 📋 Resumen Técnico Detallado: Sistema BOM (Bill of Materials)

## 🎯 Objetivo del Documento

Este documento explica **cómo funciona y se calcula el BOM** en el sistema ERP Adaptio, dirigido al equipo de ingeniería para diagnóstico y resolución de problemas.

---

## 🏗️ Arquitectura General del Sistema BOM

### Flujo de Datos Principal

```
Quote (Cotización)
  ↓ [Status: 'approved']
SaleOrder (Orden de Venta)
  ↓
SaleOrderLine (Línea de Orden)
  ↓
BomInstance (Instancia de BOM)
  ↓
BomInstanceLines (Líneas de BOM - Componentes)
```

### Tablas Principales

1. **`Quotes`** - Cotizaciones
2. **`QuoteLines`** - Líneas de cotización (productos configurados)
3. **`QuoteLineComponents`** - Componentes generados para cada línea
4. **`SaleOrders`** - Órdenes de venta (creadas automáticamente al aprobar Quote)
5. **`SaleOrderLines`** - Líneas de orden de venta
6. **`BomInstances`** - Instancias de BOM (una por SaleOrderLine)
7. **`BomInstanceLines`** - Componentes finales del BOM (materiales a fabricar)
8. **`BOMTemplates`** - Plantillas de BOM por tipo de producto
9. **`BOMComponents`** - Componentes definidos en las plantillas

---

## 🔄 Proceso de Generación de BOM

### Fase 1: Configuración del Producto en Quote

Cuando un usuario configura un producto en una Quote (ej: Roller Shade), se guarda en `QuoteLines` con:

- `product_type_id` - Tipo de producto (Roller Shade, Dual Shade, etc.)
- `width_m`, `height_m` - Dimensiones en metros
- `qty` - Cantidad
- `drive_type` - 'manual' | 'motor'
- `bottom_rail_type` - 'standard' | 'wrapped'
- `cassette` - boolean
- `cassette_type` - 'standard' | 'recessed' | 'surface'
- `side_channel` - boolean
- `side_channel_type` - 'side_only' | 'side_and_bottom'
- `hardware_color` - 'white' | 'black' | 'silver' | 'bronze'
- `catalog_item_id` - Item de catálogo (tela/variante)

### Fase 2: Generación de Componentes (QuoteLineComponents)

**Función:** `generate_configured_bom_for_quote_line()`

**Ubicación:** `database/migrations/134_create_generate_configured_bom_function.sql`

**Proceso:**

1. **Busca BOMTemplate** por `product_type_id`:
   ```sql
   SELECT * FROM "BOMTemplates"
   WHERE product_type_id = p_product_type_id
   AND organization_id = p_organization_id
   AND deleted = false
   AND active = true
   ```

2. **Itera sobre BOMComponents** del template:
   - Filtra por `block_condition` (condiciones de activación)
   - Filtra por `hardware_color` si `applies_color = true`
   - Resuelve `catalog_item_id`:
     - Si `component_item_id` está definido → usa ese
     - Si `auto_select = true` → resuelve por regla (ej: tubo por ancho)

3. **Calcula Cantidades**:
   - **UOM = 'm' (metros lineales)**: 
     - Componentes horizontales (tube, rail, cassette): `qty_per_unit × width_m`
     - Componentes verticales (side_channel): `height_m × 2`
   - **UOM = 'sqm' (metros cuadrados)**:
     - Tela: `qty_per_unit × (width_m × height_m)`
   - **UOM = 'ea' (unidades)**:
     - Accesorios: `qty_per_unit`
   - **Multiplica por cantidad del QuoteLine**: `component_qty × qty`

4. **Inserta en QuoteLineComponents**:
   ```sql
   INSERT INTO "QuoteLineComponents" (
       organization_id,
       quote_line_id,
       catalog_item_id,
       qty,
       unit_cost_exw,
       component_role,
       source
   ) VALUES (...)
   ```

**Ejemplo de Block Condition:**
```json
{
  "drive_type": "motor",
  "cassette": true,
  "cassette_type": "recessed"
}
```
Solo se activa si el producto tiene motor + cassette recessed.

### Fase 3: Aprobación de Quote → Creación de BOM

**Trigger:** `trg_on_quote_approved_create_operational_docs`

**Función:** `on_quote_approved_create_operational_docs()`

**Ubicación:** `database/migrations/177_complete_operational_flow_quote_to_bom.sql`

**Proceso Automático:**

1. **Crea SaleOrder** (si no existe):
   - Genera número: `SO-000001` (usando `OrganizationCounters`)
   - Copia datos de Quote: customer_id, currency, totals, notes

2. **Crea SaleOrderLines** (una por QuoteLine):
   - Copia: qty, width_m, height_m, catalog_item_id, product_type_id
   - Copia: drive_type, bottom_rail_type, cassette, side_channel, hardware_color
   - Copia precios: `unit_price_snapshot`, `line_total`

3. **Crea BomInstance** (una por SaleOrderLine):
   - `status = 'locked'` (BOM congelado)
   - FK: `sale_order_line_id`, `quote_line_id`

4. **Crea BomInstanceLines** (desde QuoteLineComponents):
   - **Fuente:** `QuoteLineComponents` donde `source = 'configured_component'`
   - **Normaliza UOM:** 
     - Longitud → `'m'` (canonical)
     - Otros → `'ea'` (canonical)
   - **Calcula Costos:**
     - `unit_cost_exw` = `get_unit_cost_in_uom(catalog_item_id, canonical_uom, org_id)`
     - `total_cost_exw` = `qty × unit_cost_exw`
   - **Deriva Category:**
     - `category_code` = `derive_category_code_from_role(component_role)`
     - Valores: 'fabric', 'tube', 'motor', 'bracket', 'cassette', 'side_channel', 'bottom_channel', 'accessory'
   - **Congela Descripción:** `item_name` del CatalogItem al momento de aprobación

**Características Importantes:**

- **Re-entrant:** Si se vuelve a aprobar, solo crea lo que falta (no duplica)
- **Frozen Snapshot:** Los costos y descripciones se congelan al momento de aprobación
- **ON CONFLICT DO NOTHING:** Si ya existe una BomInstanceLine, no la actualiza (snapshot inmutable)

---

## 🔧 Funciones de Soporte

### 1. `normalize_uom_to_canonical(p_uom text)`

**Propósito:** Normaliza UOM a forma canónica.

**Lógica:**
- Unidades de longitud (`'MTS'`, `'M'`, `'METER'`, `'YD'`, `'FT'`) → `'m'`
- Todo lo demás → `'ea'`

**Uso:** Asegura consistencia en `BomInstanceLines.uom`

### 2. `get_unit_cost_in_uom(p_catalog_item_id, p_target_uom, p_organization_id)`

**Propósito:** Convierte costo unitario a UOM objetivo.

**Lógica:**
1. Obtiene `cost_exw` y `cost_uom` de `CatalogItems`
2. Si `cost_uom = target_uom` → retorna `cost_exw`
3. Busca conversión en tabla `UomConversions`
4. Si no encuentra, usa conversiones simples:
   - `yd → m`: dividir por 0.9144
   - `ft → m`: dividir por 3.28084
5. Si no hay conversión → retorna `cost_exw` (asume mismo costo)

**Uso:** Calcula `BomInstanceLines.unit_cost_exw` en UOM canónica

### 3. `derive_category_code_from_role(p_component_role text)`

**Propósito:** Deriva código de categoría desde `component_role`.

**Lógica (case-insensitive):**
- `'%fabric%'` → `'fabric'`
- `'%tube%'` → `'tube'`
- `'%motor%'` o `'%drive%'` → `'motor'`
- `'%bracket%'` → `'bracket'`
- `'%cassette%'` → `'cassette'`
- `'%side_channel%'` o `'%side channel%'` → `'side_channel'`
- `'%bottom_channel%'` o `'%bottom channel%'` → `'bottom_channel'`
- Otros → `'accessory'`

**Uso:** Asigna `BomInstanceLines.category_code` para agrupación

### 4. `get_next_counter_value(p_organization_id, p_key text)`

**Propósito:** Genera números secuenciales thread-safe (ej: SO-000001).

**Lógica:**
- Usa tabla `OrganizationCounters` con `ON CONFLICT DO UPDATE`
- Incrementa `last_value` de forma atómica
- Retorna el nuevo valor

**Uso:** Genera `SaleOrders.sale_order_no`

---

## 📊 Estructura de Datos Detallada

### BOMTemplates

```sql
CREATE TABLE "BOMTemplates" (
    id uuid PRIMARY KEY,
    organization_id uuid NOT NULL,
    product_type_id uuid NOT NULL,  -- FK a ProductTypes
    template_name text,
    active boolean DEFAULT true,
    deleted boolean DEFAULT false,
    ...
);
```

**Relación:** 1 BOMTemplate por `product_type_id` (ej: Roller Shade tiene un template)

### BOMComponents

```sql
CREATE TABLE "BOMComponents" (
    id uuid PRIMARY KEY,
    bom_template_id uuid NOT NULL,  -- FK a BOMTemplates
    organization_id uuid NOT NULL,
    component_item_id uuid,  -- FK a CatalogItems (opcional)
    component_role text,  -- 'tube', 'fabric', 'motor', etc.
    qty_per_unit numeric,
    uom text,  -- 'm', 'sqm', 'ea'
    block_condition jsonb,  -- Condiciones de activación
    applies_color boolean DEFAULT false,
    hardware_color text,  -- 'white', 'black', etc.
    auto_select boolean DEFAULT false,
    sku_resolution_rule text,  -- 'width_rule_42_65_80'
    sequence_order integer,
    ...
);
```

**Campos Clave:**

- **`block_condition`**: JSONB con condiciones:
  ```json
  {
    "drive_type": "motor",
    "cassette": true,
    "cassette_type": "recessed"
  }
  ```
  Solo se incluye si TODAS las condiciones coinciden.

- **`applies_color`**: Si `true`, el componente solo se incluye si `hardware_color` coincide.

- **`auto_select`**: Si `true`, resuelve `component_item_id` automáticamente:
  - `sku_resolution_rule = 'width_rule_42_65_80'`:
    - Ancho < 0.042m → busca SKU con `'%TUBE%42%'`
    - Ancho < 0.065m → busca SKU con `'%TUBE%65%'`
    - Ancho >= 0.065m → busca SKU con `'%TUBE%80%'`

### BomInstanceLines

```sql
CREATE TABLE "BomInstanceLines" (
    id uuid PRIMARY KEY,
    bom_instance_id uuid NOT NULL,  -- FK a BomInstances
    resolved_part_id uuid NOT NULL,  -- FK a CatalogItems
    resolved_sku text,
    part_role text,  -- 'tube', 'fabric', etc.
    qty numeric NOT NULL,
    uom text NOT NULL,  -- Canonical: 'm' o 'ea'
    description text,  -- Frozen: item_name al momento de aprobación
    unit_cost_exw numeric(12,4),  -- Frozen: costo en UOM canónica
    total_cost_exw numeric(12,4),  -- Frozen: qty × unit_cost_exw
    category_code text,  -- 'fabric', 'tube', 'motor', etc.
    cut_length_mm numeric,  -- Ajustes dimensionales (Engineering Rules)
    cut_width_mm numeric,
    cut_height_mm numeric,
    calc_notes text,  -- Notas de cálculo
    ...
);
```

**Constraints:**

- **UNIQUE:** `(bom_instance_id, resolved_part_id, part_role, uom) WHERE deleted = false`
  - Previene duplicados en el mismo BOM

**Campos Dimensionales (Engineering Rules):**

- `cut_length_mm`, `cut_width_mm`, `cut_height_mm`: Dimensiones finales después de ajustes
- `calc_notes`: Notas sobre cómo se calcularon (ej: "Ajustado por Engineering Rule: tube_overhang")

---

## 🎯 Reglas de Cálculo de Cantidades

### Componentes Lineales (UOM = 'm')

**Fórmula Base:**
```
qty = qty_per_unit × dimension × quote_line_qty
```

**Dimensiones por Rol:**

| Component Role | Dimensión Usada | Fórmula |
|----------------|-----------------|---------|
| `tube`, `rail`, `cassette`, `profile` | `width_m` | `qty_per_unit × width_m × qty` |
| `side_channel` | `height_m × 2` | `height_m × 2 × qty` |
| Otros verticales | `height_m` | `qty_per_unit × height_m × qty` |

**Ejemplo:**
- Tube con `qty_per_unit = 1`, `width_m = 2.5m`, `qty = 3`
- Resultado: `1 × 2.5 × 3 = 7.5m`

### Componentes de Área (UOM = 'sqm')

**Fórmula:**
```
qty = qty_per_unit × (width_m × height_m) × quote_line_qty
```

**Ejemplo:**
- Tela con `qty_per_unit = 1`, `width_m = 2.5m`, `height_m = 3.0m`, `qty = 2`
- Resultado: `1 × (2.5 × 3.0) × 2 = 15.0 sqm`

### Componentes Unitarios (UOM = 'ea')

**Fórmula:**
```
qty = qty_per_unit × quote_line_qty
```

**Ejemplo:**
- Motor con `qty_per_unit = 1`, `qty = 3`
- Resultado: `1 × 3 = 3 ea`

---

## 🔍 Diagnóstico de Problemas Comunes

### Problema 1: BOM no se genera al aprobar Quote

**Checklist:**

1. **Verificar Trigger:**
   ```sql
   SELECT * FROM pg_trigger 
   WHERE tgname = 'trg_on_quote_approved_create_operational_docs';
   ```

2. **Verificar que Quote tiene QuoteLines:**
   ```sql
   SELECT COUNT(*) FROM "QuoteLines" 
   WHERE quote_id = '<quote_id>' AND deleted = false;
   ```

3. **Verificar que QuoteLines tienen QuoteLineComponents:**
   ```sql
   SELECT ql.id, COUNT(qlc.id) as component_count
   FROM "QuoteLines" ql
   LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
       AND qlc.deleted = false AND qlc.source = 'configured_component'
   WHERE ql.quote_id = '<quote_id>' AND ql.deleted = false
   GROUP BY ql.id;
   ```

4. **Verificar logs del trigger:**
   - Revisar `RAISE NOTICE` en función `on_quote_approved_create_operational_docs()`
   - Buscar en logs de Supabase: `🔔 Trigger fired`, `✅ Quote loaded`, etc.

### Problema 2: BOM solo tiene tela, faltan otros componentes

**Causas Posibles:**

1. **BOMTemplate no tiene BOMComponents configurados:**
   ```sql
   SELECT bt.id, bt.template_name, COUNT(bc.id) as component_count
   FROM "BOMTemplates" bt
   LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id 
       AND bc.deleted = false
   WHERE bt.product_type_id = '<product_type_id>'
   GROUP BY bt.id, bt.template_name;
   ```

2. **Block Conditions no coinciden:**
   - Verificar `block_condition` en `BOMComponents`
   - Comparar con valores en `QuoteLines`:
     ```sql
     SELECT drive_type, cassette, cassette_type, side_channel, hardware_color
     FROM "QuoteLines"
     WHERE id = '<quote_line_id>';
     ```

3. **Color no coincide:**
   - Verificar `applies_color = true` y `hardware_color` en `BOMComponents`
   - Comparar con `hardware_color` en `QuoteLine`

### Problema 3: Cantidades incorrectas en BomInstanceLines

**Verificar:**

1. **Cálculo de dimensiones:**
   ```sql
   SELECT 
       ql.width_m, ql.height_m, ql.qty,
       qlc.qty as component_qty,
       qlc.component_role,
       qlc.uom
   FROM "QuoteLines" ql
   INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
   WHERE ql.id = '<quote_line_id>';
   ```

2. **Verificar `qty_per_unit` en BOMComponents:**
   ```sql
   SELECT component_role, qty_per_unit, uom
   FROM "BOMComponents"
   WHERE bom_template_id = '<bom_template_id>';
   ```

3. **Fórmula esperada vs. real:**
   - Para lineales: `qty_per_unit × width_m × qty`
   - Para área: `qty_per_unit × (width_m × height_m) × qty`
   - Para unitarios: `qty_per_unit × qty`

### Problema 4: Costos en cero o NULL

**Verificar:**

1. **CatalogItems tiene `cost_exw`:**
   ```sql
   SELECT id, sku, cost_exw, cost_uom
   FROM "CatalogItems"
   WHERE id IN (
       SELECT resolved_part_id 
       FROM "BomInstanceLines" 
       WHERE unit_cost_exw IS NULL OR unit_cost_exw = 0
   );
   ```

2. **Función `get_unit_cost_in_uom` funciona:**
   ```sql
   SELECT public.get_unit_cost_in_uom(
       '<catalog_item_id>',
       'm',  -- o 'ea'
       '<organization_id>'
   );
   ```

3. **UomConversions existe (si aplica):**
   ```sql
   SELECT * FROM "UomConversions"
   WHERE organization_id = '<organization_id>';
   ```

### Problema 5: Componentes duplicados en BomInstanceLines

**Causa:** Violación de constraint UNIQUE

**Verificar:**
```sql
SELECT 
    bom_instance_id,
    resolved_part_id,
    part_role,
    uom,
    COUNT(*) as duplicate_count
FROM "BomInstanceLines"
WHERE deleted = false
GROUP BY bom_instance_id, resolved_part_id, part_role, uom
HAVING COUNT(*) > 1;
```

**Solución:** El trigger usa `ON CONFLICT DO NOTHING`, pero si hay duplicados previos, pueden persistir. Eliminar duplicados manualmente.

---

## 🔄 Flujo Completo Ejemplo

### Escenario: Roller Shade Motorizado con Cassette

**1. Usuario configura producto:**
- Product Type: Roller Shade
- Dimensiones: 2.5m × 3.0m
- Cantidad: 2
- Drive: Motor
- Cassette: Sí, Recessed
- Side Channel: Sí, Both
- Hardware Color: White

**2. Se guarda QuoteLine:**
```sql
INSERT INTO "QuoteLines" (
    product_type_id, width_m, height_m, qty,
    drive_type, cassette, cassette_type, 
    side_channel, side_channel_type, hardware_color
) VALUES (
    '<roller_shade_id>', 2.5, 3.0, 2,
    'motor', true, 'recessed',
    true, 'side_and_bottom', 'white'
);
```

**3. Se llama `generate_configured_bom_for_quote_line()`:**

- Busca BOMTemplate para Roller Shade
- Itera BOMComponents:
  - **Tube (auto_select)**: 
    - Ancho 2.5m → regla '80'
    - Busca SKU `'%TUBE%80%'` → encuentra `'TUBE-80-WH'`
    - Qty: `1 × 2.5 × 2 = 5.0m`
  - **Fabric**:
    - Qty: `1 × (2.5 × 3.0) × 2 = 15.0 sqm`
  - **Motor (block_condition: drive_type='motor')**:
    - Coincide → incluye
    - Qty: `1 × 2 = 2 ea`
  - **Cassette (block_condition: cassette=true, cassette_type='recessed')**:
    - Coincide → incluye
    - Qty: `1 × 2.5 × 2 = 5.0m`
  - **Side Channel (block_condition: side_channel=true)**:
    - Coincide → incluye
    - Qty: `3.0 × 2 × 2 = 12.0m` (height × 2 units × qty)

**4. Se insertan QuoteLineComponents:**
- 6 componentes insertados con `source = 'configured_component'`

**5. Usuario aprueba Quote:**
- Trigger `trg_on_quote_approved_create_operational_docs` se ejecuta

**6. Se crea SaleOrder:**
- Número: `SO-000123`
- Status: `'draft'`

**7. Se crea SaleOrderLine:**
- Copia datos de QuoteLine

**8. Se crea BomInstance:**
- Status: `'locked'`
- FK: `sale_order_line_id`, `quote_line_id`

**9. Se crean BomInstanceLines:**
- 6 líneas insertadas desde QuoteLineComponents
- UOM normalizado: lineales → `'m'`, unitarios → `'ea'`
- Costos calculados y congelados
- Category codes asignados

---

## 📝 Notas Técnicas Importantes

### 1. Frozen Snapshots

Los datos en `BomInstanceLines` son **inmutables** después de la aprobación:
- `unit_cost_exw`, `total_cost_exw`: Congelados al momento de aprobación
- `description`: Congelado (item_name del CatalogItem al momento de aprobación)
- Si el costo del CatalogItem cambia después, **NO afecta** los BOMs ya aprobados

### 2. Re-entrant Design

El trigger es **idempotente**:
- Si se vuelve a aprobar un Quote, solo crea lo que falta
- Usa `ON CONFLICT DO NOTHING` para evitar duplicados
- Permite recuperación de datos si se eliminan accidentalmente

### 3. UOM Normalization

Todas las UOM se normalizan a forma canónica:
- **Longitud:** `'m'` (metros)
- **Otros:** `'ea'` (each/unidad)

Esto asegura consistencia en cálculos y agregaciones.

### 4. Engineering Rules (Ajustes Dimensionales)

Los campos `cut_length_mm`, `cut_width_mm`, `cut_height_mm` en `BomInstanceLines` se calculan por funciones de Engineering Rules (fuera del scope de este documento, pero mencionado para referencia).

---

## 🛠️ Queries Útiles para Diagnóstico

### Verificar BOM completo de un Quote

```sql
SELECT 
    q.quote_no,
    ql.id as quote_line_id,
    sol.id as sale_order_line_id,
    bi.id as bom_instance_id,
    bil.id as bom_line_id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.unit_cost_exw,
    bil.total_cost_exw,
    bil.category_code
FROM "Quotes" q
INNER JOIN "QuoteLines" ql ON ql.quote_id = q.id AND ql.deleted = false
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id AND sol.deleted = false
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE q.id = '<quote_id>'
ORDER BY ql.id, bil.category_code, bil.part_role;
```

### Verificar componentes faltantes

```sql
-- Comparar QuoteLineComponents vs BomInstanceLines
SELECT 
    qlc.component_role,
    qlc.qty as qlc_qty,
    bil.qty as bil_qty,
    CASE 
        WHEN bil.id IS NULL THEN 'FALTA EN BOM'
        WHEN qlc.qty != bil.qty THEN 'CANTIDAD DIFERENTE'
        ELSE 'OK'
    END as status
FROM "QuoteLineComponents" qlc
LEFT JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
LEFT JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id 
    AND bil.resolved_part_id = qlc.catalog_item_id
    AND bil.part_role = qlc.component_role
WHERE qlc.quote_line_id = '<quote_line_id>'
    AND qlc.deleted = false
    AND qlc.source = 'configured_component';
```

### Verificar BOMTemplate y sus componentes

```sql
SELECT 
    bt.template_name,
    bc.component_role,
    bc.qty_per_unit,
    bc.uom,
    bc.block_condition,
    bc.applies_color,
    bc.hardware_color,
    bc.auto_select,
    bc.sku_resolution_rule,
    ci.sku as component_sku
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE bt.product_type_id = '<product_type_id>'
    AND bt.deleted = false
    AND bt.active = true
ORDER BY bc.sequence_order;
```

---

## 📚 Referencias

- **Función principal de generación:** `database/migrations/134_create_generate_configured_bom_function.sql`
- **Trigger de aprobación:** `database/migrations/177_complete_operational_flow_quote_to_bom.sql`
- **Función de generación para MO:** `database/migrations/129_create_generate_bom_for_quote_line_function.sql` (si existe)

---

**Última actualización:** Diciembre 2024  
**Versión del documento:** 1.0





