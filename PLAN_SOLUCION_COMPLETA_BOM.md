# 🔧 Plan de Solución Completa: BOM Solo Telas + UOM + Accessories

## 🔍 Problemas Identificados

1. **Solo aparecen telas** → No se generaron otros componentes del BOM
2. **UOM de telas es "ea"** → Debería ser "m2" o "m"
3. **No aparecen accessories** → El trigger solo copia `source='configured_component'`, no copia `source='accessory'`

## 📊 Flujo del Sistema

```
Quote (approved)
  ↓
Trigger: on_quote_approved_create_operational_docs()
  ↓
1. Crea SaleOrder y SaleOrderLines
2. Crea BomInstances
3. Copia QuoteLineComponents (source='configured_component') → BomInstanceLines
   ❌ NO copia accessories (source='accessory')
```

## 🎯 Plan de Acción Completo

### Paso 1: Diagnosticar Estado Actual

Ejecuta `DIAGNOSTICO_COMPLETO_BOM.sql` con `SO-000007`:
- Step 1: QuoteLineComponents generados
- Step 2: BomInstanceLines (Manufacturing Order)
- Step 3: Configuración del QuoteLine
- Step 4: BOMTemplate components
- Step 5: Resumen de conteos

### Paso 2: Corregir UOM y Regenerar BOM

Ejecuta `FIX_BOM_COMPLETO.sql` con `SO-000007`:
- Corrige UOM de telas en QuoteLineComponents
- Elimina componentes configurados antiguos
- Regenera BOM completo llamando `generate_configured_bom_for_quote_line`
- Corrige UOM nuevamente en componentes recién generados
- Muestra verificación final

### Paso 3: Copiar Accessories a BomInstanceLines

Ejecuta `FIX_BOM_INCLUDE_ACCESSORIES.sql` con `SO-000007`:
- Copia manualmente los accessories de QuoteLineComponents a BomInstanceLines
- Esto corrige el problema de que el trigger no copia accessories

### Paso 4: Verificar Resultado Final

Ejecuta `DIAGNOSTICO_COMPLETO_BOM.sql` nuevamente:
- Step 1 debería mostrar múltiples componentes (fabric, drive, tube, bracket, etc.) + accessories
- Step 2 debería mostrar todos los componentes en BomInstanceLines
- UOM de telas debería ser "m2" o "m"

## 📋 Checklist Final

- [ ] Ejecutar DIAGNOSTICO_COMPLETO_BOM.sql (diagnóstico inicial)
- [ ] Ejecutar FIX_BOM_COMPLETO.sql (corrige UOM y regenera BOM)
- [ ] Ejecutar FIX_BOM_INCLUDE_ACCESSORIES.sql (copia accessories)
- [ ] Verificar con DIAGNOSTICO_COMPLETO_BOM.sql (resultado final)
- [ ] Verificar en UI que Manufacturing Order muestra todos los componentes

## 🎯 Resultado Esperado

Después de completar estos pasos:
- ✅ QuoteLineComponents tiene múltiples component_role (fabric, drive, tube, bracket, etc.) + accessories
- ✅ BomInstanceLines tiene múltiples category_code + accessories
- ✅ UOM de telas es "m2" o "m" (no "ea")
- ✅ Manufacturing Order muestra todos los componentes necesarios + accessories

## 🔧 Scripts Disponibles

1. **DIAGNOSTICO_COMPLETO_BOM.sql** - Diagnóstico completo
2. **FIX_BOM_COMPLETO.sql** - Corrige UOM y regenera BOM
3. **FIX_BOM_INCLUDE_ACCESSORIES.sql** - Copia accessories a BomInstanceLines

## ⚠️ Nota Importante

El trigger `on_quote_approved_create_operational_docs()` solo copia componentes con `source='configured_component'`. Los accessories con `source='accessory'` necesitan copiarse manualmente usando `FIX_BOM_INCLUDE_ACCESSORIES.sql`.








