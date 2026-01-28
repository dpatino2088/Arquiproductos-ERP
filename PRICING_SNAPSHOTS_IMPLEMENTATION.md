# 📋 IMPLEMENTACIÓN: Sistema de Snapshots para QuoteLines

**Fecha:** 2026-01-25  
**Objetivo:** Implementar snapshots completos (desglose) al crear QuoteLine desde ConfiguredProduct

---

## ✅ COMPLETADO

### 1. **Migración SQL**
- ✅ `database/migrations/20260125_add_quote_lines_snapshot_columns.sql`
- ✅ Agrega columnas: `roll_cost_snapshot`, `bom_cost_snapshot`, `roll_msrp_snapshot`, `bom_msrp_snapshot`

### 2. **Servicio Principal**
- ✅ `src/lib/quotes/createQuoteLineFromConfiguredProduct.ts`
- ✅ Función: `createQuoteLineFromConfiguredProduct()`
- ✅ Flujo:
  1. Valida IDs
  2. Recalcula ConfiguredProducts (server-side)
  3. Lee ConfiguredProducts recalculado
  4. Calcula costos (roll_cost, bom_cost)
  5. Inserta QuoteLines con snapshots
  6. Opcional: actualiza ConfiguredProducts.quote_line_id

### 3. **Hooks Actualizados**
- ✅ `src/hooks/useQuotes.ts` - Corregido para usar snapshots de QuoteLines en lugar de ConfiguredProducts

---

## ⚠️ PENDIENTE

### 1. **Extender calculate_configured_product_totals (Opcional)**
La función SQL `calculate_configured_product_totals` actualmente solo calcula MSRP:
- `roll_msrp_total` ✅
- `bom_total` (MSRP) ✅
- `roll_plus_bom_total` ✅

**No calcula costos:**
- `roll_cost_total` ❌
- `bom_cost_total` ❌

**Opciones:**
- **Opción A (Recomendada):** Extender la función SQL para calcular y persistir costos en ConfiguredProducts
- **Opción B (Actual):** Calcular costos en el servicio TypeScript (ya implementado)

**Estado actual:** El servicio TypeScript calcula costos directamente desde CatalogItems y BOMInstanceLines.

### 2. **Actualizar UI del Configurador**
- ⚠️ Mostrar valores desde ConfiguredProducts mientras el usuario edita
- ⚠️ Llamar `createQuoteLineFromConfiguredProduct` al hacer "Agregar a cotización"
- ⚠️ Mostrar desglose: Roll MSRP, BOM MSRP, MSRP total, Costos

### 3. **Actualizar UI de Cotización**
- ⚠️ Mostrar valores desde QuoteLines (snapshots) en la lista/detalle de cotizaciones
- ⚠️ Mostrar desglose: Roll MSRP Snapshot, BOM MSRP Snapshot, MSRP total, Costos

### 4. **Integrar en QuoteNew.tsx**
- ⚠️ Reemplazar lógica actual de creación de QuoteLines para usar `createQuoteLineFromConfiguredProduct`
- ⚠️ Asegurar que ConfiguredProduct se recalcule antes de crear QuoteLine

---

## 📝 CONTRATO DE SNAPSHOT

### Reglas Fundamentales

1. **QuoteLines es SNAPSHOT:**
   - ❌ NO debe cambiar cuando cambie CatalogItems o CatalogItemsMSRP
   - ✅ Solo se recalcula con acción explícita "Reprice" o creando nuevo QuoteLine
   - ✅ Valores congelados al momento de crear

2. **ConfiguredProducts es VIVO:**
   - ✅ Se recalcula en cada cambio del configurador
   - ✅ Muestra valores actuales basados en CatalogItemsMSRP vigente

3. **UI:**
   - **Configurador:** Muestra `ConfiguredProducts.roll_msrp_total`, `bom_total`, `roll_plus_bom_total`
   - **Cotización:** Muestra `QuoteLines.roll_msrp_snapshot`, `bom_msrp_snapshot`, `msrp`, `total_cost`, `net_price`

---

## 🔍 VERIFICACIÓN

### Casos de Prueba

1. **Crear QuoteLine desde ConfiguredProduct:**
   - ✅ Snapshots llenos y consistentes
   - ✅ `msrp = roll_msrp_snapshot + bom_msrp_snapshot`
   - ✅ `total_cost = roll_cost_snapshot + bom_cost_snapshot`

2. **Cambiar CatalogItems.cost_exw:**
   - ✅ Recalcular CatalogItemsMSRP
   - ✅ QuoteLine existente NO cambia
   - ✅ ConfiguredProduct SÍ refleja cambios

3. **Crear nueva QuoteLine:**
   - ✅ Refleja cambios en CatalogItemsMSRP
   - ✅ Snapshots capturan valores actuales

---

## 📚 ARCHIVOS MODIFICADOS

### Nuevos
1. `database/migrations/20260125_add_quote_lines_snapshot_columns.sql`
2. `src/lib/quotes/createQuoteLineFromConfiguredProduct.ts`

### Actualizados
1. `src/hooks/useQuotes.ts` - Usa snapshots de QuoteLines

---

## 🎯 PRÓXIMOS PASOS

1. **Ejecutar migración SQL** en base de datos
2. **Integrar servicio en QuoteNew.tsx** para reemplazar lógica actual
3. **Actualizar UI del configurador** para mostrar ConfiguredProducts
4. **Actualizar UI de cotización** para mostrar snapshots de QuoteLines
5. **Probar flujo completo** end-to-end

---

**Estado:** ✅ Servicio y migración creados. ⚠️ Pendiente integración en UI.
