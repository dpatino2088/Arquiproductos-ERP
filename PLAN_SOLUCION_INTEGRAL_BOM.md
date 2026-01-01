# Plan de Solución Integral: BOM con Solo Telas

## 🎯 Objetivo
Resolver completamente el problema de que el BOM solo muestra telas, asegurando que todos los componentes necesarios (motor, tube, brackets, bottom_bar, cassette, side_channel) aparezcan correctamente.

## 📊 Flujo del Sistema

```
Quote (configurado)
  ↓
handleProductConfigComplete (QuoteNew.tsx)
  ↓
generate_configured_bom_for_quote_line (función SQL)
  ↓
QuoteLineComponents (source='configured_component')
  ↓
Quote (approved)
  ↓
Trigger: on_quote_approved_create_operational_docs()
  ↓
BomInstanceLines (copiado de QuoteLineComponents)
```

**El problema está en la generación**: Si `QuoteLineComponents` solo tiene telas, `BomInstanceLines` solo tendrá telas.

## 🔍 Diagnóstico Completo

### Paso 1: Ejecutar Diagnóstico Completo

Ejecuta `DIAGNOSE_BOM_COMPLETE.sql` con tu Sale Order number. Este script verifica 6 puntos críticos:

1. **STEP 1**: Configuración de QuoteLine (drive_type, cassette, hardware_color, etc.)
2. **STEP 2**: BOMTemplate y sus componentes
3. **STEP 3**: BOMComponents y su capacidad de resolución (component_item_id, auto_select)
4. **STEP 4**: QuoteLineComponents generados
5. **STEP 5**: BomInstanceLines finales
6. **STEP 6**: Simulación de block condition matching

## 🔧 Soluciones por Escenario

### Escenario A: BOMTemplate Incompleto (STEP 2 solo muestra 'fabric')

**Síntoma**: El BOMTemplate solo tiene componentes de tipo 'fabric'.

**Solución**: Ejecutar `FIX_BOM_TEMPLATE_COMPONENTS.sql` (se creará)

### Escenario B: Configuración Incompleta (STEP 1 muestra NULLs)

**Síntoma**: `drive_type`, `cassette`, `hardware_color` son NULL.

**Solución**: Ya corregido en `QuoteNew.tsx` (bottom_rail_type tiene default). Ejecutar `FIX_MISSING_BOTTOM_RAIL_TYPE.sql` para datos existentes.

### Escenario C: BOMComponents Sin Resolución (STEP 3 muestra 'MISSING')

**Síntoma**: BOMComponents no tienen `component_item_id` y no pueden auto-seleccionar.

**Solución**: Ejecutar `FIX_BOM_COMPONENTS_RESOLUTION.sql` (se creará)

### Escenario D: Block Condition Mismatch (STEP 6 muestra 'BLOCKED')

**Síntoma**: Las condiciones de bloque están bloqueando componentes.

**Solución**: Ejecutar `FIX_BLOCK_CONDITIONS.sql` (se creará)

### Escenario E: Función No Genera Componentes (STEP 4 solo muestra 'fabric')

**Síntoma**: La función se ejecuta pero solo genera telas.

**Solución**: Revisar logs y ejecutar `TEST_GENERATE_BOM_MANUAL.sql` (se creará)

## 🚀 Plan de Ejecución

1. **Diagnóstico**: Ejecutar `DIAGNOSE_BOM_COMPLETE.sql`
2. **Identificar Escenario**: Basado en los resultados
3. **Aplicar Corrección**: Ejecutar el script correspondiente
4. **Verificación**: Re-generar BOM y verificar que aparecen todos los componentes

## 📝 Notas Importantes

- La función `generate_configured_bom_for_quote_line` se llama correctamente desde `QuoteNew.tsx` línea 557
- Todos los parámetros se están pasando correctamente
- El problema está en la lógica de la función o en los datos (BOMTemplate, BOMComponents)








