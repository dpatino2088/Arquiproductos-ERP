# Implementación Completa: Sistema de Precios

## 📋 Reglas Oficiales del Sistema

### 1. CatalogItems.msrp
- **Significado**: MSRP END USER (precio lista público)
- **No hay campo separado**: No existe `msrp_end_user` - `msrp` ES el precio lista público
- **Uso**: Precio que paga el consumidor final (end user)

### 2. QuoteLines.list_unit_price_snapshot
- **Origen**: Copia de `CatalogItems.msrp` al crear la línea
- **Significado**: Precio lista público (END USER) en el momento de crear la cotización
- **Snapshot**: No cambia aunque el MSRP del item cambie después

### 3. QuoteLines.unit_price_snapshot
- **Cálculo**: Precio neto final después de aplicar:
  - Descuento por tier del cliente (`discount_pct_used`)
  - Margin floor (guardrail de margen mínimo)
- **Significado**: Precio que paga el distribuidor/cliente (después de descuentos)
- **Fórmula**: Resultado de `calculateQuoteLinePrice()`

### 4. QuoteLines.discount_pct_used
- **Origen**: Descuento según `DirectoryCustomers.customer_type`
- **Fuente**: `CostSettings` (discount_distributor_pct, discount_partner_pct, etc.)
- **Aplicado a**: `list_unit_price_snapshot` (MSRP)

### 5. QuoteLines.line_total
- **Cálculo**: `unit_price_snapshot * computed_qty`
- **Significado**: Total neto que paga el distribuidor

### 6. QuoteLines.price_basis
- **Valores**: `'MSRP_TIER'` o `'MARGIN_FLOOR'`
- **Significado**: Indica si el precio final viene del tier discount o del margin floor

---

## 🔧 Implementación

### Paso 1: Backfill Temporal de MSRP

**Script**: `BACKFILL_MSRP_TEMPORAL.sql`

Este script permite validar el flujo mientras defines los MSRPs reales:

```sql
-- Usa margen fijo del 35% (margin-on-sale)
UPDATE "CatalogItems"
SET msrp = ROUND(cost_exw / (1 - 0.35), 2)
WHERE deleted = false
  AND (msrp IS NULL OR msrp = 0)
  AND cost_exw > 0;
```

**⚠️ IMPORTANTE**: Este es un backfill temporal. Debes definir los MSRPs reales después.

---

### Paso 2: Validación de Seguridad

**Ubicación**: `src/pages/sales/QuoteNew.tsx` - `handleProductConfigComplete`

**Bloqueo implementado**:
- Si `catalogItem.msrp` es NULL o 0 → Error y bloqueo
- Mensaje: "Catalog item [SKU] does not have MSRP (list price). Please define MSRP before adding to quote."
- Impide crear QuoteLines con items sin MSRP

---

### Paso 3: Guardado en QuoteLines

**Campos guardados**:

```typescript
{
  // PRICING SNAPSHOTS
  list_unit_price_snapshot: listPrice,        // CatalogItems.msrp (END USER)
  unit_price_snapshot: netUnitPrice,          // Precio neto (distribuidor)
  line_total: lineTotal,                      // unit_price_snapshot * computedQty
  
  // METADATA
  discount_pct_used: pricingResult.discountPct,
  customer_type_snapshot: customerType,
  price_basis: pricingResult.priceBasis,
  margin_pct_used: calculatedMargin,
  
  // NO SE GUARDAN LEGACY FIELDS:
  // - final_unit_price
  // - discount_percentage
  // - discount_amount
  // - discount_source
  // - margin_percentage
  // - margin_source
}
```

---

### Paso 4: UI - Tabla de QuoteLines

**Columnas mostradas**:

1. **List Price (MSRP)**: `list_unit_price_snapshot`
   - Precio lista público (END USER)

2. **Discount**: `discount_pct_used %`
   - Porcentaje de descuento aplicado según tier

3. **Net Price**: `unit_price_snapshot`
   - Precio neto unitario (distribuidor)

4. **Net Total**: `line_total`
   - Total neto (distribuidor paga esto)

**✅ Sin recálculos en UI**: Todos los valores vienen de snapshots guardados.

---

## 📊 Flujo de Datos

```
1. CatalogItem tiene:
   - msrp = $100 (END USER precio lista)
   - cost_exw = $50

2. Cliente es "Distributor" con 35% discount

3. Se crea QuoteLine:
   - list_unit_price_snapshot = $100 (copia de msrp)
   - discount_pct_used = 35%
   - unit_price_snapshot = $65 (después de 35% descuento)
   - line_total = $65 * qty

4. UI muestra:
   - List Price: $100
   - Discount: 35%
   - Net Price: $65
   - Net Total: $65 * qty
```

---

## ✅ Checklist de Implementación

- [x] Script de backfill temporal de MSRP creado
- [x] Validación de seguridad en QuoteNew.tsx (bloquea items sin MSRP)
- [x] Guardado correcto de `list_unit_price_snapshot` y `unit_price_snapshot`
- [x] UI actualizada con 4 columnas de precios
- [x] Eliminados campos legacy del guardado
- [x] Sin recálculos en UI (todo desde snapshots)
- [x] Totals calculados desde `line_total`

---

## 🚀 Próximos Pasos

1. **Ejecutar backfill temporal**:
   ```sql
   -- Ejecutar: BACKFILL_MSRP_TEMPORAL.sql
   ```

2. **Ejecutar migración de columna** (si no existe):
   ```sql
   -- Ejecutar: ADD_LIST_UNIT_PRICE_SNAPSHOT.sql
   ```

3. **Backfill de QuoteLines existentes** (opcional):
   ```sql
   -- Ejecutar: BACKFILL_LIST_UNIT_PRICE_SNAPSHOT.sql
   ```

4. **Definir MSRPs reales**:
   - Reemplazar los valores temporales con MSRPs reales
   - O implementar reglas de negocio para calcularlos automáticamente

---

## 📝 Notas Importantes

- **MSRP = END USER price**: No existe campo separado, `msrp` ES el precio lista público
- **Distribuidor paga menos**: `unit_price_snapshot` es el precio neto después de descuentos
- **Snapshots no cambian**: Una vez guardado, no se recalcula aunque cambien los precios del item
- **Legacy fields deprecated**: Ya no se usan, pero se mantienen en BD para compatibilidad





