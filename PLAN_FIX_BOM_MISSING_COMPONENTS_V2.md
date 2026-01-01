# Plan de Acción: Resolver BOM con Solo Telas (Versión 2)

## 🔍 Problema Confirmado
Los resultados del diagnóstico muestran que **solo aparecen telas (fabric) en el BOM** del Manufacturing Order. Esto indica que el problema está en la generación de `QuoteLineComponents` cuando se llama a `generate_configured_bom_for_quote_line`.

## 📊 Flujo del Sistema

```
Quote (approved)
  ↓
Trigger: on_quote_approved_create_operational_docs()
  ↓
1. Crea SaleOrder y SaleOrderLines
2. Crea BomInstances
3. Copia QuoteLineComponents (source='configured_component') → BomInstanceLines
```

**El problema está en el paso 3**: Solo hay componentes de tipo 'fabric' en `QuoteLineComponents`, por lo que solo se copian telas.

## 🎯 Diagnóstico Paso a Paso

### Ejecuta el script `DIAGNOSE_BOM_ROOT_CAUSE.sql` completo

Este script verifica 5 puntos críticos:

1. **STEP 1: QuoteLineComponents Generated**
   - Muestra qué componentes fueron generados por `generate_configured_bom_for_quote_line`
   - **Si solo aparece 'fabric'**: El problema está en la función de generación

2. **STEP 2: BOMTemplate Components**
   - Muestra qué componentes están configurados en el BOMTemplate
   - **Si solo aparece 'fabric'**: El BOMTemplate está incompleto

3. **STEP 3: QuoteLine Configuration**
   - Muestra la configuración que se pasó a `generate_configured_bom_for_quote_line`
   - **Si drive_type, cassette, hardware_color son NULL**: La configuración no se guardó correctamente

4. **STEP 4: Block Condition Matching**
   - Simula la lógica de matching de `block_condition`
   - **Si la mayoría muestra '❌ BLOCKED'**: Las condiciones de bloque son demasiado restrictivas

5. **STEP 5: QuoteLineComponents vs BomInstanceLines**
   - Compara lo que se generó vs lo que se copió
   - **Si QuoteLineComponents tiene más filas**: El proceso de copia falló

## 🔧 Soluciones por Escenario

### Escenario 1: BOMTemplate Incompleto (STEP 2 solo muestra 'fabric')

**Síntoma**: El BOMTemplate solo tiene componentes de tipo 'fabric'.

**Solución**:
1. Verificar que existe un BOMTemplate activo para el ProductType:
   ```sql
   SELECT bt.id, bt.name, pt.code, pt.name
   FROM "BOMTemplates" bt
   INNER JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
   WHERE bt.product_type_id = '<product_type_id>'
     AND bt.active = true
     AND bt.deleted = false;
   ```

2. Verificar que el BOMTemplate tiene componentes para todos los tipos:
   ```sql
   SELECT bc.component_role, COUNT(*) as count
   FROM "BOMComponents" bc
   WHERE bc.bom_template_id = '<bom_template_id>'
     AND bc.deleted = false
   GROUP BY bc.component_role;
   ```

3. Si faltan componentes, ejecutar la migración de seed o crear manualmente:
   - `database/migrations/182_seed_bom_templates_shades.sql` (si existe)
   - O crear BOMComponents manualmente para: drive, tube, bracket, bottom_bar, cassette, side_channel

### Escenario 2: Configuración No Guardada (STEP 3 muestra NULLs)

**Síntoma**: `drive_type`, `cassette`, `hardware_color` son NULL en QuoteLines.

**Solución**:
1. Verificar que `handleProductConfigComplete` en `QuoteNew.tsx` guarda todos los campos:
   - `drive_type`
   - `cassette`
   - `cassette_type`
   - `side_channel`
   - `side_channel_type`
   - `hardware_color`
   - `bottom_rail_type`

2. Verificar que la conversión de QuoteLines → SaleOrderLines preserva todos los campos (ya está en el trigger, línea 726-778 de `177_complete_operational_flow_quote_to_bom.sql`)

### Escenario 3: Block Condition Mismatch (STEP 4 muestra '❌ BLOCKED')

**Síntoma**: La mayoría de componentes están bloqueados por condiciones.

**Solución**:
1. Verificar que los valores en `QuoteLines` coinciden con los valores en `BOMComponents.block_condition`:
   ```sql
   -- Ver valores en QuoteLines
   SELECT drive_type, cassette, hardware_color, side_channel
   FROM "QuoteLines"
   WHERE id = '<quote_line_id>';
   
   -- Ver valores esperados en BOMComponents
   SELECT component_role, block_condition
   FROM "BOMComponents"
   WHERE bom_template_id = '<bom_template_id>';
   ```

2. Ajustar `block_condition` en BOMComponents para que coincidan con los valores reales, o ajustar los valores en QuoteLines.

3. Verificar que `generate_configured_bom_for_quote_line` recibe los parámetros correctos:
   - Revisar cómo se llama la función desde el frontend o backend
   - Asegurar que todos los parámetros se pasan correctamente

### Escenario 4: Component Item ID Missing (STEP 2 muestra '❌ MISSING')

**Síntoma**: BOMComponents no tienen `component_item_id` y no pueden auto-seleccionar.

**Solución**:
1. Verificar que cada BOMComponent tiene:
   - `component_item_id` (directo), O
   - `auto_select = true` + `sku_resolution_rule` (auto-selección)

2. Si falta `component_item_id`, mapear a CatalogItems:
   ```sql
   -- Ejemplo: Mapear tube por width rule
   UPDATE "BOMComponents"
   SET component_item_id = (
     SELECT id FROM "CatalogItems"
     WHERE sku ILIKE '%TUBE%42%'
       AND organization_id = '<org_id>'
       AND deleted = false
     LIMIT 1
   )
   WHERE id = '<bom_component_id>';
   ```

### Escenario 5: Función No Llamada (STEP 1 está vacío)

**Síntoma**: No hay QuoteLineComponents con `source='configured_component'`.

**Solución**:
1. Verificar que `generate_configured_bom_for_quote_line` se llama cuando se completa la configuración del producto
2. Verificar que la función se ejecuta sin errores (revisar logs de Supabase)
3. Llamar manualmente la función para probar:
   ```sql
   SELECT generate_configured_bom_for_quote_line(
     p_quote_line_id := '<quote_line_id>',
     p_product_type_id := '<product_type_id>',
     p_organization_id := '<organization_id>',
     p_drive_type := 'motor', -- o 'manual'
     p_bottom_rail_type := 'standard', -- o 'wrapped'
     p_cassette := true,
     p_cassette_type := 'standard',
     p_side_channel := true,
     p_side_channel_type := 'side_and_bottom',
     p_hardware_color := 'white',
     p_width_m := 2.0,
     p_height_m := 1.5,
     p_qty := 1
   );
   ```

## 🚀 Acción Inmediata

1. **Ejecuta `DIAGNOSE_BOM_ROOT_CAUSE.sql`** con tu Sale Order number
2. **Comparte los resultados** de los 5 steps
3. **Basado en los resultados**, aplicamos la solución correspondiente

## 📝 Notas Importantes

- El flujo es: `QuoteLineComponents` (generado por `generate_configured_bom_for_quote_line`) → `BomInstanceLines` (copiado por el trigger)
- Si `QuoteLineComponents` solo tiene telas, `BomInstanceLines` solo tendrá telas
- El problema está en la generación, no en la copia
- La función `generate_configured_bom_for_quote_line` filtra componentes por:
  - `block_condition` (drive_type, cassette, side_channel, etc.)
  - `hardware_color` (si `applies_color = true`)
  - `component_item_id` o `auto_select` con `sku_resolution_rule`

## 🔍 Verificación Final

Después de aplicar la solución, verifica:

```sql
-- Debe mostrar múltiples category_code, no solo 'fabric'
SELECT category_code, COUNT(*) as count
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "SaleOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000003'
  AND bil.deleted = false
GROUP BY category_code
ORDER BY category_code;
```

**Esperado**: Múltiples filas con `category_code` = 'fabric', 'motor', 'tube', 'bracket', 'bottom_rail', 'cassette', 'side_channel', etc.








