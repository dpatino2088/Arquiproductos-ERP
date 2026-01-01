# 🔧 Solución Completa: BOM Solo Telas y UOM Incorrecto

## 🔍 Problema Identificado

1. **Solo aparecen telas en Manufacturing Order** → No se generaron otros componentes del BOM
2. **UOM de telas es "ea"** → Debería ser "m2" o "m"

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

**El problema está en la generación**: Si `QuoteLineComponents` solo tiene telas, `BomInstanceLines` solo tendrá telas.

## 🎯 Plan de Acción Completo

### Paso 1: Verificar Estado Actual

Ejecuta `CHECK_BOM_COMPLETE_FLOW.sql` con `SO-000006`:
- Step 1: Sale Order y QuoteLine
- Step 2: QuoteLineComponents generados
- Step 3: BomInstances creados
- Step 4: BomInstanceLines (frozen materials)
- Step 5: Resumen de conteos

### Paso 2: Corregir UOM de Telas

Ejecuta `FIX_BOM_UOM_AND_REGENERATE.sql` con `SO-000006`:
- Corrige UOM en QuoteLineComponents
- Corrige UOM en BomInstanceLines
- Muestra QuoteLines que necesitan regeneración

### Paso 3: Regenerar BOM Completo

**Opción A: Re-configurar en UI (Recomendado)**
1. Ve a QuoteNew
2. Edita el QuoteLine
3. Re-configura el producto (pasa por todos los steps)
4. Guarda → Esto regenerará el BOM

**Opción B: Llamar función manualmente**
Usa los datos del Step 3 de `FIX_BOM_UOM_AND_REGENERATE.sql` y llama:
```sql
SELECT generate_configured_bom_for_quote_line(
  p_quote_line_id := 'QUOTE_LINE_ID',
  p_product_type_id := 'PRODUCT_TYPE_ID',
  p_organization_id := 'ORGANIZATION_ID',
  p_drive_type := 'motor',
  p_bottom_rail_type := 'standard',
  p_cassette := false,
  p_cassette_type := NULL,
  p_side_channel := false,
  p_side_channel_type := NULL,
  p_hardware_color := 'white',
  p_width_m := 2.0,
  p_height_m := 1.5,
  p_qty := 1
);
```

### Paso 4: Re-aprobar Quote (si es necesario)

Si el Quote ya está aprobado pero el BOM no se generó correctamente:
1. Cambia el status del Quote a 'draft'
2. Vuelve a aprobarlo → Esto ejecutará el trigger nuevamente

### Paso 5: Verificar Resultado Final

Ejecuta `CHECK_BOM_COMPLETE_FLOW.sql` nuevamente:
- Step 2 debería mostrar múltiples componentes
- Step 4 debería mostrar múltiples materiales frozen
- UOM de telas debería ser "m2" o "m"

## 🔧 Scripts Disponibles

1. **CHECK_BOM_COMPLETE_FLOW.sql** - Diagnóstico completo
2. **FIX_BOM_UOM_AND_REGENERATE.sql** - Corrige UOM y prepara regeneración
3. **FIX_BOM_COMPONENTS_AUTO_SELECT.sql** - Corrige sku_resolution_rule
4. **CHECK_BOM_GENERATED.sql** - Verifica qué se generó

## 📋 Checklist Final

- [ ] Ejecutar CHECK_BOM_COMPLETE_FLOW.sql
- [ ] Ejecutar FIX_BOM_UOM_AND_REGENERATE.sql
- [ ] Re-configurar QuoteLine en UI
- [ ] Verificar que se generaron múltiples componentes
- [ ] Verificar que UOM de telas es "m2" o "m"
- [ ] Re-aprobar Quote si es necesario
- [ ] Verificar BomInstanceLines tiene todos los componentes

## 🎯 Resultado Esperado

Después de completar estos pasos:
- ✅ QuoteLineComponents tiene múltiples component_role
- ✅ BomInstanceLines tiene múltiples category_code
- ✅ UOM de telas es "m2" o "m" (no "ea")
- ✅ Manufacturing Order muestra todos los componentes necesarios








