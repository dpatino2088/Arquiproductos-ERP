# Plan de Acción: Resolver BOM con Solo Telas

## 🔍 Problema Identificado
Al completar el workflow de Quote → Sale Order → Manufacturing Order, el BOM solo muestra las telas (fabrics), faltan los demás componentes:
- ❌ Motor/Drive
- ❌ Tube
- ❌ Brackets
- ❌ Bottom Bar
- ❌ Hardware (end caps, etc.)
- ❌ Cassette components
- ❌ Side channel components
- ✅ Fabric (sí aparece)

## 🎯 Objetivo
Que el BOM muestre TODOS los componentes necesarios para fabricar el producto, no solo la tela.

---

## 📋 Plan de Diagnóstico y Resolución

### PASO 1: Verificar que SaleOrderLines tiene toda la configuración
**Objetivo**: Confirmar que cuando se crea el Sale Order, se guardan TODOS los datos de configuración.

**Acción**:
```sql
SELECT 
  sol.id,
  sol.product_type_id,
  sol.drive_type,
  sol.cassette,
  sol.cassette_type,
  sol.side_channel,
  sol.side_channel_type,
  sol.hardware_color,
  sol.bottom_rail_type,
  sol.metadata
FROM "SaleOrderLines" sol
WHERE sol.sale_order_id = 'TU_SALE_ORDER_ID'
  AND sol.deleted = false;
```

**Esperado**:
- `drive_type`: 'motor' o 'manual'
- `cassette`: true/false
- `hardware_color`: 'white', 'black', etc.
- `metadata`: JSON con configuración adicional

**Si falta**: Hay que corregir cómo se guardan los SaleOrderLines desde QuoteLines.

---

### PASO 2: Verificar que existe BOMTemplate para el ProductType
**Objetivo**: Confirmar que hay un BOMTemplate configurado para el ProductType del producto.

**Acción**:
```sql
-- 1. Ver qué ProductType tiene el SaleOrderLine
SELECT 
  sol.product_type_id,
  pt.code,
  pt.name
FROM "SaleOrderLines" sol
  LEFT JOIN "ProductTypes" pt ON pt.id = sol.product_type_id
WHERE sol.sale_order_id = 'TU_SALE_ORDER_ID'
  AND sol.deleted = false;

-- 2. Ver si existe BOMTemplate para ese ProductType
SELECT 
  bt.id,
  bt.name,
  bt.product_type_id,
  bt.active,
  COUNT(bc.id) as components_count
FROM "BOMTemplates" bt
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.product_type_id = 'PRODUCT_TYPE_ID_FROM_STEP_1'
  AND bt.deleted = false
GROUP BY bt.id, bt.name, bt.product_type_id, bt.active;
```

**Esperado**:
- Debe existir al menos 1 BOMTemplate activo
- Debe tener múltiples componentes (fabric, drive, tube, brackets, etc.)

**Si falta**: Hay que crear o corregir el BOMTemplate.

---

### PASO 3: Verificar BOMComponents del Template
**Objetivo**: Confirmar que el BOMTemplate tiene TODOS los componentes configurados.

**Acción**:
```sql
SELECT 
  bc.id,
  bc.component_role,
  bc.block_type,
  bc.block_condition,
  bc.applies_color,
  bc.hardware_color,
  bc.auto_select,
  bc.qty_per_unit,
  bc.uom,
  ci.sku,
  ci.item_name
FROM "BOMComponents" bc
  LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE bc.bom_template_id = 'BOM_TEMPLATE_ID_FROM_STEP_2'
  AND bc.deleted = false
ORDER BY bc.sequence_order;
```

**Esperado**:
- `component_role` = 'fabric' (✅ este funciona)
- `component_role` = 'operating_system_drive' (motor o manual)
- `component_role` = 'tube'
- `component_role` = 'bracket'
- `component_role` = 'bottom_bar'
- `component_role` = 'cassette' (si aplica)
- `component_role` = 'side_channel' (si aplica)

**Si faltan**: Hay que agregar los componentes faltantes al BOMTemplate.

---

### PASO 4: Verificar BomInstances y BomInstanceLines
**Objetivo**: Confirmar que se crearon BomInstances y que se generaron las líneas correctamente.

**Acción**:
```sql
-- 1. Ver BomInstances creadas
SELECT 
  bi.id,
  bi.sale_order_line_id,
  bi.bom_template_id,
  bi.metadata
FROM "BomInstances" bi
WHERE bi.sale_order_line_id IN (
  SELECT id FROM "SaleOrderLines" 
  WHERE sale_order_id = 'TU_SALE_ORDER_ID' 
  AND deleted = false
)
AND bi.deleted = false;

-- 2. Ver las líneas generadas para cada BomInstance
SELECT 
  bil.id,
  bil.bom_instance_id,
  bil.category_code,
  bil.component_role,
  bil.resolved_part_id,
  bil.qty,
  bil.uom,
  bil.description,
  ci.sku,
  ci.item_name
FROM "BomInstanceLines" bil
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE bil.bom_instance_id IN (
  SELECT id FROM "BomInstances" 
  WHERE sale_order_line_id IN (
    SELECT id FROM "SaleOrderLines" 
    WHERE sale_order_id = 'TU_SALE_ORDER_ID' 
    AND deleted = false
  )
  AND deleted = false
)
AND bil.deleted = false
ORDER BY bil.component_role;
```

**Esperado**:
- Múltiples líneas con diferentes `component_role`
- Todas las categorías deben estar presentes

**Si solo hay fabric**: El problema está en la función `generate_configured_bom`.

---

### PASO 5: Revisar la función generate_configured_bom
**Objetivo**: Verificar que la función está aplicando TODAS las reglas de selección.

**Acción**: Revisar la última versión de la función en:
- `database/migrations/174_sync_uom_from_catalog_items.sql`
- O la migración más reciente que modifique `generate_configured_bom`

**Verificar**:
1. ¿Lee correctamente `drive_type` de SaleOrderLine?
2. ¿Aplica reglas de `block_type` y `block_condition`?
3. ¿Aplica reglas de `hardware_color`?
4. ¿Maneja cassette y side_channel correctamente?

---

### PASO 6: Testing Manual con SQL
**Objetivo**: Probar la función manualmente para ver qué genera.

**Acción**:
```sql
-- Llamar manualmente a la función con datos de prueba
SELECT generate_configured_bom(
  p_sale_order_line_id := 'TU_SALE_ORDER_LINE_ID',
  p_organization_id := 'TU_ORGANIZATION_ID'
);

-- Ver el resultado
SELECT * FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id IN (
  SELECT id FROM "BomInstances" 
  WHERE sale_order_line_id = 'TU_SALE_ORDER_LINE_ID'
  AND deleted = false
)
AND bil.deleted = false;
```

---

## 🔧 Posibles Causas y Soluciones

### Causa 1: SaleOrderLines no tiene configuración completa
**Síntoma**: Campos como `drive_type`, `cassette`, `hardware_color` son NULL o vacíos.

**Solución**:
1. Corregir `handleProductConfigComplete` en `QuoteNew.tsx`
2. Asegurar que TODOS los campos se guardan en `QuoteLines`
3. Corregir la conversión de `QuoteLines` → `SaleOrderLines`

### Causa 2: BOMTemplate no tiene componentes configurados
**Síntoma**: BOMComponents solo tiene `component_role='fabric'`.

**Solución**:
1. Ejecutar migración de seed: `database/migrations/182_seed_bom_templates_shades.sql`
2. O crear manualmente los componentes faltantes

### Causa 3: Función generate_configured_bom tiene bug
**Síntoma**: La función no aplica las reglas de `block_condition` o `hardware_color` correctamente.

**Solución**:
1. Revisar la última versión de la función
2. Corregir la lógica de filtrado
3. Probar con datos reales

### Causa 4: BomComponents no están vinculados a CatalogItems
**Síntoma**: `component_item_id` es NULL o el CatalogItem no existe.

**Solución**:
1. Verificar que existen CatalogItems para cada componente (drives, tubes, brackets, etc.)
2. Actualizar `component_item_id` en BOMComponents

---

## 🎬 Siguiente Paso Inmediato

**EMPEZAR CON PASO 1**: Ejecutar el SQL de diagnóstico para ver qué datos tiene el SaleOrderLine.

¿Puedes compartir el `sale_order_id` del Sale Order que creaste para que podamos ejecutar los diagnósticos?








