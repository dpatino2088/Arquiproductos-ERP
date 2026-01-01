# Auto-Select BOM Generation Implementation Notes

## ✅ Implementado (Migration 358)

### 1. Función Helper: `resolve_auto_select_sku()`
- **Ubicación**: `database/migrations/358_add_auto_select_support_to_bom_generation.sql`
- **Propósito**: Resuelve `catalog_item_id` para componentes auto-select
- **Parámetros**:
  - `p_component_role`: Role del componente (ej: 'bracket', 'tube')
  - `p_sku_resolution_rule`: Regla de resolución ('SKU_SUFFIX_COLOR', 'ROLE_AND_COLOR')
  - `p_hardware_color`: Color del hardware ('white', 'black', 'grey', 'silver', 'bronze')
  - `p_organization_id`: ID de la organización
  - `p_bom_template_id`: ID del template (opcional, para futuras mejoras)

### 2. Función Principal Actualizada: `generate_bom_for_manufacturing_order()`
- **Cambios principales**:
  1. **Mantiene comportamiento actual**: Los componentes fixed (con `component_item_id`) se procesan igual que antes desde `QuoteLineComponents`
  2. **Agrega soporte auto-select**: Procesa componentes de `BOMComponents` donde `auto_select = true` o `component_item_id IS NULL`
  3. **Block condition filtering**: Filtra componentes basado en `block_condition` (cassette, side_channel)
  4. **Cálculo de qty**: Soporta `fixed`, `per_width`, `per_area`
  5. **UOM**: Usa `CatalogItems.uom` como fuente primaria

### 3. Flujo de Procesamiento
```
1. Crear BomInstances (si no existen)
2. Para cada BomInstance:
   a. Procesar QuoteLineComponents (componentes fixed) → Crear BomInstanceLines
   b. Procesar BOMComponents con auto_select=true:
      - Verificar block_condition (cassette, side_channel)
      - Resolver catalog_item_id usando resolve_auto_select_sku()
      - Calcular qty según qty_type
      - Crear BomInstanceLine
3. Aplicar engineering rules (como antes)
```

## ⚠️ Limitaciones y Suposiciones

### 1. Mapeo de component_role → category_code
**Suposición**: El mapeo se hace mediante CASE statement basado en el nombre del role:
- `'fabric'` → `'fabric'`
- `'tube'` → `'tube'`
- `'motor'` → `'motor'`
- `'bracket'` → `'bracket'`
- Roles que contienen `'cassette'` → `'cassette'`
- Roles que contienen `'side_channel'` → `'side_channel'`
- Roles que contienen `'bottom_rail'` o `'bottom_channel'` → `'bottom_channel'`
- Otros → `'accessory'`

**Confirmar**: ¿Este mapeo es correcto? ¿Hay roles adicionales que deban mapearse?

### 2. Resolución de hardware_color
**Implementación actual**: Busca en el SKU usando patrones:
- `'white'` → SKU contiene `-W`, `WHITE`, o `WHT`
- `'black'` → SKU contiene `-BLK`, `BLACK`, o `BLK`
- `'grey'` / `'gray'` → SKU contiene `-GR`, `GREY`, o `GRAY`
- `'silver'` → SKU contiene `-SV` o `SILVER`
- `'bronze'` → SKU contiene `-BZ` o `BRONZE`

**Limitaciones**:
- ⚠️ No hay campo dedicado `hardware_color` en `CatalogItems`
- ⚠️ La búsqueda es por patrón en SKU, puede ser imprecisa
- ⚠️ Si múltiples items coinciden, se elige el más reciente (`ORDER BY created_at DESC`)

**Preguntas para confirmar**:
1. ¿El color está siempre codificado en el SKU como sufijo (ej: `RC3153-GR`)?
2. ¿Hay alguna tabla de mapeo SKU → color?
3. ¿Deberíamos usar `metadata` JSONB en `CatalogItems`?
4. ¿Hay un campo `hardware_color` en `CatalogItems` que no estoy viendo?

### 3. Block Condition (cassette/side_channel)
**Implementación**: Lee `block_condition` JSONB desde `BOMComponents` y verifica:
- Si `block_condition->>'cassette' = true` → requiere que `QuoteLine.cassette = true`
- Si `block_condition->>'side_channel' = true` → requiere que `QuoteLine.side_channel = true`

**Confirmar**:
- ✅ `QuoteLines` tiene campos `cassette` y `side_channel` (confirmado en migración 346)
- ✅ `block_condition` es JSONB en `BOMComponents` (confirmado en migración 132)
- ❓ ¿Hay otros campos en `block_condition` que deban verificarse?

### 4. Cálculo de Qty
**Implementado**:
- `fixed`: `qty = qty_value` (o `qty_per_unit` si `qty_value` es NULL)
- `per_width`: `qty = width_m * qty_value`
- `per_area`: `qty = width_m * height_m * qty_value`

**Confirmar**:
- ✅ `QuoteLines` tiene `width_m` y `height_m` (confirmado en migraciones)
- ❓ ¿Los valores están en metros? (asumido `m`, no `mm`)
- ❓ ¿Hay casos donde `width_m` o `height_m` sean NULL y debamos usar valores por defecto?

### 5. Redondeo de Qty
**Implementación**:
- Si UOM es `'pcs'`, `'ea'`, `'piece'`, `'pieces'` → `CEIL(qty)`
- Otros UOMs → `ROUND(qty, 3)` (3 decimales)

**Confirmar**: ¿Esta lógica de redondeo es correcta?

## 📋 Campo Exacto para Auto-Select

### Confirmado:
- ✅ Campo: `auto_select` (boolean) en `BOMComponents`
- ✅ Si `auto_select = true` O `component_item_id IS NULL` → componente es auto-select
- ✅ Campos relacionados: `sku_resolution_rule`, `hardware_color`, `block_condition`, `qty_type`, `qty_value`

### En el UI (TypeScript):
- Campo: `selection_mode` (`'fixed'` | `'auto_select'`)
- Al guardar: `auto_select = (selection_mode === 'auto_select')`
- `component_item_id` es NULL cuando `selection_mode === 'auto_select'`

## 🔍 Próximos Pasos (Pendientes)

### 1. Verificar Hardware Color Mapping
**Acción**: Ejecutar este query para ver cómo están codificados los colores en los SKUs reales:
```sql
SELECT 
    ci.sku,
    ci.item_name,
    ic.category_code,
    -- Ver si hay patrones comunes en SKU para colores
    CASE 
        WHEN ci.sku LIKE '%-W%' OR ci.sku LIKE '%WHITE%' OR ci.sku LIKE '%WHT%' THEN 'white'
        WHEN ci.sku LIKE '%-BLK%' OR ci.sku LIKE '%BLACK%' OR ci.sku LIKE '%BLK%' THEN 'black'
        WHEN ci.sku LIKE '%-GR%' OR ci.sku LIKE '%GREY%' OR ci.sku LIKE '%GRAY%' THEN 'grey'
        WHEN ci.sku LIKE '%-SV%' OR ci.sku LIKE '%SILVER%' THEN 'silver'
        WHEN ci.sku LIKE '%-BZ%' OR ci.sku LIKE '%BRONZE%' THEN 'bronze'
        ELSE 'unknown'
    END as inferred_color
FROM "CatalogItems" ci
INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
WHERE ci.deleted = false
AND ic.category_code IN ('bracket', 'cassette', 'side_channel', 'bottom_channel', 'accessory')
ORDER BY ci.sku
LIMIT 100;
```

### 2. Mejorar Resolución de SKU
**Opciones**:
1. Agregar campo `hardware_color` a `CatalogItems` (migración futura)
2. Usar tabla de mapeo `HardwareColorMapping` (si existe)
3. Mejorar lógica de matching basada en metadata JSONB
4. Usar tabla `BomRoleSkuMapping` si existe (similar a `generate_configured_bom_for_quote_line`)

### 3. Testing
**Pasos**:
1. Crear un BOMTemplate con componentes auto-select
2. Crear un QuoteLine que use ese template
3. Crear ManufacturingOrder
4. Ejecutar `generate_bom_for_manufacturing_order()`
5. Verificar que los BomInstanceLines se crearon correctamente

## 🐛 Errores Potenciales

### 1. Resolución de SKU falla
**Síntoma**: `RAISE EXCEPTION` en `resolve_auto_select_sku`
**Causas posibles**:
- No hay CatalogItems que coincidan con category_code + hardware_color
- El hardware_color no se mapea correctamente desde SKU
- La organización no tiene items en esa categoría

**Solución**: Verificar que existen CatalogItems con los SKUs esperados

### 2. Block condition no funciona
**Síntoma**: Componentes se incluyen cuando no deberían (o viceversa)
**Causas posibles**:
- `QuoteLine.cassette` o `side_channel` no están seteados correctamente
- `block_condition` JSONB tiene formato incorrecto

**Solución**: Verificar formato de `block_condition` y valores en `QuoteLines`

### 3. Qty calculation incorrecta
**Síntoma**: Cantidades muy grandes o muy pequeñas
**Causas posibles**:
- `width_m` o `height_m` están en unidades incorrectas (mm vs m)
- `qty_value` tiene valor incorrecto

**Solución**: Verificar unidades en `QuoteLines`

## 📝 Notas de Implementación

### Orden de Procesamiento
1. Primero se procesan `QuoteLineComponents` (fixed)
2. Luego se procesan `BOMComponents` con auto-select
3. Esto asegura que si hay conflicto, los fixed tienen prioridad

### Idempotencia
- La función verifica si `BomInstanceLine` ya existe antes de crear
- Usa `part_role` como key para evitar duplicados
- Si ya existe un line para un role, se omite

### Logging
- Usa `RAISE NOTICE` para debug
- Mensajes incluyen contexto suficiente para troubleshooting
- Errores críticos usan `RAISE EXCEPTION` (fail hard)

