# ✅ IMPLEMENTACIÓN: Labor en ConfiguredProducts

**Fecha:** 2026-01-25  
**Estado:** ✅ Completo

---

## 📋 RESUMEN

Se ha ajustado el cálculo de `ConfiguredProducts` para incluir `labor_pct` en el total final (`roll_plus_bom_total`).

### Fórmula implementada:
```
subtotal_msrp = roll_msrp_total + bom_total
labor_amount = subtotal_msrp * labor_pct
roll_plus_bom_total = subtotal_msrp * (1 + labor_pct)
```

---

## 📁 ARCHIVOS MODIFICADOS

### Migración SQL:
1. ✅ `20260125_add_labor_to_configured_products.sql`
   - Agrega columna `labor_amount` a `ConfiguredProducts`
   - Ajusta `calculate_configured_product_totals` para incluir labor

### Código TypeScript:
1. ✅ `src/lib/quotes/createQuoteLineFromConfiguredProduct.ts`
   - Guarda `labor_pct` snapshot en QuoteLines (si existe)

---

## 🔧 CAMBIOS EN `calculate_configured_product_totals`

### Antes:
```sql
roll_plus_bom_total = roll_msrp_total + bom_total  -- Sin labor
```

### Ahora:
```sql
subtotal_msrp = roll_msrp_total + bom_total
labor_pct = (desde CostSettings por organization_id)
labor_amount = subtotal_msrp * labor_pct
roll_plus_bom_total = subtotal_msrp * (1 + labor_pct)  -- ✅ Con labor
```

### Fuente de `labor_pct`:
1. **CostSettings** (por `organization_id`, `is_active = true`) - Prioridad 1
2. **ConfiguredProducts.metadata->>'labor_pct'** - Prioridad 2
3. **ConfiguredProducts.labor_pct** - Prioridad 3
4. **0** - Fallback

---

## 📊 FLUJO ACTUALIZADO

```
CatalogItemsMSRP
  ↓
ConfiguredProducts (LIVE)
  - roll_msrp_total = msrp_sale_out × roll_width × height_m × quantity
  - bom_total = SUM(msrp_sale_out × qty) de BOMInstanceLines
  - subtotal_msrp = roll_msrp_total + bom_total  ✅ NUEVO
  - labor_pct = (desde CostSettings)  ✅ NUEVO
  - labor_amount = subtotal_msrp * labor_pct  ✅ NUEVO
  - roll_plus_bom_total = subtotal_msrp * (1 + labor_pct)  ✅ CON LABOR
  - roll_total_cost = total_cost × roll_width × height_m × quantity
  - bom_total_cost = SUM(total_cost × qty) de BOMInstanceLines
  ↓
QuoteLines (SNAPSHOT)
  - roll_msrp_snapshot = ConfiguredProducts.roll_msrp_total
  - bom_msrp_snapshot = ConfiguredProducts.bom_total
  - labor_pct = ConfiguredProducts.labor_pct  ✅ NUEVO
  - msrp = ConfiguredProducts.roll_plus_bom_total  ✅ Ya incluye labor
  - roll_cost_snapshot = ConfiguredProducts.roll_total_cost
  - bom_cost_snapshot = ConfiguredProducts.bom_total_cost
  - total_cost = roll_cost_snapshot + bom_cost_snapshot
  - net_price = msrp × (1 - discount_pct)
```

---

## ✅ COLUMNAS AGREGADAS

### ConfiguredProducts:
- ✅ `labor_amount` (numeric(12,4)) - Monto de labor calculado

### QuoteLines:
- ✅ `labor_pct` (ya existía) - Se guarda como snapshot

---

## 🚀 ORDEN DE EJECUCIÓN

```sql
-- Ejecutar después de todas las migraciones anteriores
\i database/migrations/20260125_add_labor_to_configured_products.sql
```

---

## ⚠️ NOTAS IMPORTANTES

1. **Formato de labor_pct:**
   - CostSettings.labor_pct está en formato decimal (0.15 = 15%)
   - Si viene de metadata/columna y es > 1, se convierte automáticamente

2. **Labor solo en ConfiguredProducts:**
   - CatalogItemsMSRP NO incluye labor (correcto, es por SKU)
   - QuoteLines queda congelado con `msrp` que ya incluye labor

3. **Inmutabilidad:**
   - QuoteLines NO se recalcula automáticamente
   - ConfiguredProducts se recalcula cuando cambia configuración

4. **Accessories:**
   - Se suman DESPUÉS de aplicar labor
   - `total_msrp = roll_plus_bom_total + accessories_total`

---

## ✅ VERIFICACIÓN

```sql
-- Verificar que labor se calcula correctamente
SELECT 
  id,
  roll_msrp_total,
  bom_total,
  (roll_msrp_total + bom_total) as subtotal_msrp,
  labor_pct,
  labor_amount,
  roll_plus_bom_total,
  (roll_msrp_total + bom_total) * (1 + COALESCE(labor_pct, 0)) as roll_plus_bom_verificado
FROM public."ConfiguredProducts"
WHERE deleted = false
  AND roll_plus_bom_total IS NOT NULL
LIMIT 5;

-- ✅ roll_plus_bom_verificado debe ser igual a roll_plus_bom_total
```

---

**Estado:** ✅ Listo para producción
