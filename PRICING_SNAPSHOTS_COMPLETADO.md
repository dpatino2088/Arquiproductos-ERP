# ✅ IMPLEMENTACIÓN COMPLETADA: Sistema de Snapshots para QuoteLines

**Fecha:** 2026-01-25  
**Estado:** ✅ COMPLETADO

---

## ✅ COMPLETADO

### 1. **Migración SQL**
- ✅ `database/migrations/20260125_add_quote_lines_snapshot_columns.sql`
- ✅ Columnas agregadas: `roll_cost_snapshot`, `bom_cost_snapshot`, `roll_msrp_snapshot`, `bom_msrp_snapshot`
- ✅ **Ejecutado en base de datos** ✅

### 2. **Servicio Principal**
- ✅ `src/lib/quotes/createQuoteLineFromConfiguredProduct.ts`
- ✅ Función: `createQuoteLineFromConfiguredProduct()`
- ✅ Flujo completo:
  1. Recalcula ConfiguredProducts (server-side)
  2. Calcula costos desde CatalogItems y BOMInstanceLines
  3. Captura snapshots de MSRP desde ConfiguredProducts
  4. Inserta QuoteLine con todos los snapshots
  5. Opcional: actualiza `ConfiguredProducts.quote_line_id`

### 3. **Integración en QuoteNew.tsx**
- ✅ Importado servicio `createQuoteLineFromConfiguredProduct`
- ✅ Modificada función `handleProductConfigComplete`:
  - Detecta si hay `configured_product_id`
  - Si hay ConfiguredProduct y NO está editando → usa servicio de snapshots
  - Si está editando o no hay ConfiguredProduct → usa flujo legacy
- ✅ Return temprano después de usar servicio de snapshots (no ejecuta BOM manual)
- ✅ Guard rail: no ejecuta generación de BOM manual si se usó servicio de snapshots

### 4. **Hooks Actualizados**
- ✅ `src/hooks/useQuotes.ts`:
  - Corregido para usar snapshots de QuoteLines
  - NO recalcula desde ConfiguredProducts (snapshot congelado)
  - Usa `roll_msrp_snapshot + bom_msrp_snapshot` si están disponibles

### 5. **UI Actualizada**
- ✅ `src/pages/sales/QuoteNew.tsx`:
  - Tooltips con desglose de snapshots en columnas de precio
  - Muestra Roll MSRP, BOM MSRP, Total MSRP al hacer hover
  - Usa snapshots cuando están disponibles, fallback a `msrp` total

---

## 📋 CONTRATO DE SNAPSHOT IMPLEMENTADO

### ✅ Reglas Fundamentales

1. **QuoteLines es SNAPSHOT:**
   - ✅ NO cambia cuando cambia CatalogItems o CatalogItemsMSRP
   - ✅ Solo se recalcula con acción explícita "Reprice" o creando nuevo QuoteLine
   - ✅ Valores congelados al momento de crear

2. **ConfiguredProducts es VIVO:**
   - ✅ Se recalcula en cada cambio del configurador
   - ✅ Muestra valores actuales basados en CatalogItemsMSRP vigente

3. **UI:**
   - ✅ **Configurador:** Muestra `ConfiguredProducts.roll_msrp_total`, `bom_total`, `roll_plus_bom_total` (vivo)
   - ✅ **Cotización:** Muestra `QuoteLines.roll_msrp_snapshot`, `bom_msrp_snapshot`, `msrp`, `total_cost`, `net_price` (snapshot)

---

## 🔍 FLUJO IMPLEMENTADO

### Cuando el usuario hace "Agregar a cotización":

1. ✅ **Validación:** Verifica que hay `configured_product_id`
2. ✅ **Recalcular:** Llama `calculate_configured_product_totals(configured_product_id)` (server-side)
3. ✅ **Leer ConfiguredProducts:** Obtiene valores recalculados
4. ✅ **Calcular Costos:**
   - `roll_cost_snapshot` = desde CatalogItems.cost_exw × medidas
   - `bom_cost_snapshot` = suma de BOMInstanceLines.total_cost_exw
5. ✅ **Capturar Snapshots:**
   - `roll_msrp_snapshot` = ConfiguredProducts.roll_msrp_total
   - `bom_msrp_snapshot` = ConfiguredProducts.bom_total
   - `msrp` = roll_msrp_snapshot + bom_msrp_snapshot
   - `total_cost` = roll_cost_snapshot + bom_cost_snapshot
6. ✅ **Insertar QuoteLine:** Con todos los snapshots y `pricing_locked = true`
7. ✅ **Opcional:** Actualizar `ConfiguredProducts.quote_line_id`

---

## 📊 COLUMNAS SNAPSHOT EN QuoteLines

```sql
roll_cost_snapshot    numeric(12,4)  -- Costo del roll al momento de crear
bom_cost_snapshot     numeric(12,4)  -- Costo del BOM al momento de crear
roll_msrp_snapshot    numeric(12,4)  -- MSRP del roll al momento de crear
bom_msrp_snapshot     numeric(12,4)  -- MSRP del BOM al momento de crear
```

**Relaciones:**
- `msrp = roll_msrp_snapshot + bom_msrp_snapshot`
- `total_cost = roll_cost_snapshot + bom_cost_snapshot`
- `net_price = msrp × (1 - discount_pct)`

---

## 🎯 CASOS DE USO VERIFICADOS

### ✅ Caso 1: Crear QuoteLine desde ConfiguredProduct
- Snapshots llenos y consistentes
- `msrp = roll_msrp_snapshot + bom_msrp_snapshot`
- `total_cost = roll_cost_snapshot + bom_cost_snapshot`

### ✅ Caso 2: Cambiar CatalogItems.cost_exw
- Recalcular CatalogItemsMSRP
- QuoteLine existente NO cambia (snapshot congelado)
- ConfiguredProduct SÍ refleja cambios (vivo)

### ✅ Caso 3: Crear nueva QuoteLine
- Refleja cambios en CatalogItemsMSRP
- Snapshots capturan valores actuales

---

## 📝 ARCHIVOS MODIFICADOS

### Nuevos
1. `database/migrations/20260125_add_quote_lines_snapshot_columns.sql`
2. `src/lib/quotes/createQuoteLineFromConfiguredProduct.ts`

### Actualizados
1. `src/hooks/useQuotes.ts` - Usa snapshots de QuoteLines
2. `src/pages/sales/QuoteNew.tsx` - Integra servicio de snapshots y muestra desglose en UI

---

## 🚀 PRÓXIMOS PASOS (Opcional)

1. **Extender calculate_configured_product_totals (Opcional):**
   - Agregar cálculo de `roll_cost_total` y `bom_cost_total` en la función SQL
   - Esto permitiría usar valores directamente desde ConfiguredProducts en lugar de calcular en TypeScript

2. **UI Mejoras (Opcional):**
   - Agregar columna expandible para mostrar desglose completo
   - Agregar indicador visual de "snapshot locked" vs "live pricing"
   - Mostrar fecha de snapshot (`last_priced_at`)

3. **Funcionalidad "Reprice" (Futuro):**
   - Botón para recalcular QuoteLine existente
   - Crear nuevo QuoteLine con valores actualizados
   - Mantener historial de cambios

---

## ✅ VALIDACIÓN

### Checklist de Verificación

- [x] Migración SQL ejecutada
- [x] Servicio creado y funcionando
- [x] Integrado en QuoteNew.tsx
- [x] Hooks actualizados para usar snapshots
- [x] UI muestra snapshots con tooltips
- [x] Flujo completo probado: ConfiguredProduct → QuoteLine con snapshots

---

**Estado:** ✅ **IMPLEMENTACIÓN COMPLETA Y FUNCIONAL**

El sistema de snapshots está completamente implementado y listo para usar. Los QuoteLines ahora capturan snapshots completos (desglose de roll y BOM) al momento de crear, y estos valores NO cambian aunque cambien los precios en CatalogItems o CatalogItemsMSRP.
