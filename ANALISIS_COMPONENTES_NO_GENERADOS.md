# 📊 Análisis: Componentes NO Generados

## 🔍 Problemas Identificados

### 1. **Block Conditions que NO coinciden con la configuración**

El QuoteLine tiene:
- `drive_type: "motor"`
- `bottom_rail_type: "standard"`
- `cassette: false`
- `side_channel: false`

Pero muchos componentes tienen `block_condition` que no coinciden:

#### ❌ Componentes bloqueados por drive_type incorrecto:
- `operating_system_drive` con `drive_type: "manual"` (línea 2) → Debería ser `"motor"`
- `tube` con `drive_type: "manual"` (línea 6) → Debería ser `"motor"` o NULL
- `clutch_adapter`, `end_plug`, `clutch` con `drive_type: "manual"` → Deberían ser `"motor"` o NULL

#### ✅ Componentes que SÍ deberían generarse:
- `operating_system_drive` con `drive_type: "motor"` (línea 3) → ✅ Coincide
- `tube` con `drive_type: "motor"` (línea 5) → ✅ Coincide
- `bracket` con `cassette: false` (líneas 7, 9) → ✅ Coincide
- `bottom_rail_end_cap` y `bottom_rail_profile` con `bottom_rail_type: "standard"` (líneas 22, 25) → ✅ Coinciden

### 2. **Componentes que NO pueden resolverse**

Componentes con `auto_select: true` pero `sku_resolution_rule: null`:

- `tube` (línea 4) → ❌ No puede auto-seleccionar
- `bracket` con `cassette: true` (línea 10) → ❌ No puede auto-seleccionar
- `bottom_bar` (líneas 11-12) → ❌ No puede auto-seleccionar
- `side_channel_profile` (líneas 19-20) → ❌ No puede auto-seleccionar
- `cassette` (línea 28) → ❌ No puede auto-seleccionar

### 3. **Componentes que deberían funcionar pero no se generaron**

Componentes con `auto_select: true` y `sku_resolution_rule: "direct"` o con `component_item_id`:

- `bracket` con `auto_select: true, sku_resolution_rule: "direct"` (línea 8) → ✅ Debería funcionar
- `screw_end_cap` con `auto_select: true, sku_resolution_rule: "direct"` (línea 18) → ✅ Debería funcionar
- `bracket_end_cap` con `auto_select: true, sku_resolution_rule: "direct"` (línea 27) → ✅ Debería funcionar
- `bottom_rail_end_cap` con `component_item_id` (líneas 23-24) → ✅ Debería funcionar

## 🎯 Soluciones Necesarias

### Solución 1: Corregir sku_resolution_rule para componentes con auto_select

Los componentes con `auto_select: true` pero `sku_resolution_rule: null` necesitan una regla:

```sql
-- Ejemplo: Agregar sku_resolution_rule a tube
UPDATE "BOMComponents"
SET sku_resolution_rule = 'width_rule_42_65_80'
WHERE component_role = 'tube'
  AND auto_select = true
  AND sku_resolution_rule IS NULL;
```

### Solución 2: Verificar por qué componentes con "direct" no se generan

Los componentes con `auto_select: true` y `sku_resolution_rule: "direct"` deberían funcionar. Necesitamos verificar:
- Si la función `generate_configured_bom_for_quote_line` maneja correctamente `sku_resolution_rule: "direct"`
- Si hay algún problema con la lógica de auto-select

### Solución 3: Verificar block_conditions

Aunque algunos componentes tienen block_conditions que coinciden, no se están generando. Necesitamos verificar:
- Si la función está evaluando correctamente las block_conditions
- Si hay algún problema con la lógica de matching

## 📋 Próximos Pasos

1. **Re-configurar QuoteLine en la UI** para regenerar el BOM
2. **Verificar si se generan los componentes que deberían** (los que tienen block_conditions que coinciden)
3. **Corregir sku_resolution_rule** para componentes que no pueden resolverse
4. **Investigar por qué componentes con "direct" no se generan**








