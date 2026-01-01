# Revisión: Cálculo y Presentación de Precios en QuoteNew

## 📋 Resumen Ejecutivo

Este documento describe cómo se calculan y presentan los precios en `QuoteNew.tsx`, desde `cost_exw` hasta la visualización final en la UI.

---

## 🔄 Flujo de Cálculo de Precios

### 1. Origen: CatalogItem (Items del Catálogo)

**Datos almacenados en `CatalogItems`:**
- `cost_exw`: Costo EXW base
- `msrp`: Precio de venta público (MSRP - Manufacturer's Suggested Retail Price)
- `default_margin_pct`: Margen por defecto del item (%)
- `msrp_manual`: Flag que indica si el MSRP fue editado manualmente

**Cálculo del MSRP (en CatalogItemNew.tsx):**
```
total_unit_cost = cost_exw + labor_cost + logistics_cost
msrp = total_unit_cost / (1 - margin_pct / 100)
```
*Nota: Este cálculo se hace cuando se crea/actualiza un CatalogItem, NO cuando se crea un QuoteLine.*

---

### 2. Creación de QuoteLine (handleProductConfigComplete)

**Ubicación:** `src/pages/sales/QuoteNew.tsx` (líneas 449-561)

#### Paso 1: Obtener datos del CatalogItem
```typescript
const { data: catalogItem } = await supabase
  .from('CatalogItems')
  .select('collection_name, variant_name, cost_exw, msrp, default_margin_pct, uom, item_category_id')
  .eq('id', catalogItemId)
  .maybeSingle();
```

#### Paso 2: Calcular precio unitario
```typescript
// ⚠️ IMPORTANTE: Se usa MSRP DIRECTAMENTE (sin descuentos de tier)
const msrp = catalogItem?.msrp || 0;
const unitPrice = msrp; // No se aplican descuentos aquí
const lineTotal = unitPrice * computedQty;
```

**Problema potencial identificado:**
- Si `catalogItem.msrp` es `NULL` o `0`, entonces `unitPrice = 0` y `lineTotal = 0`
- **No hay fallback para calcular MSRP desde `cost_exw` si el MSRP no existe**

#### Paso 3: Calcular información de descuentos (solo para snapshots)
```typescript
const pricingResult = calculateQuoteLinePrice(
  {
    msrp: catalogItem?.msrp || null,
    cost_exw: catalogItem?.cost_exw || null,
    // ⚠️ PROBLEMA: Los campos opcionales se envían como null
    labor_cost_per_unit: null,
    shipping_cost_per_unit: null,
    freight_cost: null,
    handling_cost: null,
    import_tax_pct: null,
    default_margin_pct: catalogItem?.default_margin_pct || null,
  },
  customerType,
  costSettings || null,
  categoryMargin
);
```

**⚠️ PROBLEMA CRÍTICO:**
- `calculateQuoteLinePrice` necesita calcular `total_unit_cost`, pero si solo se pasa `cost_exw` y los demás campos son `null`, entonces:
  ```
  total_unit_cost = cost_exw + 0 + 0 = cost_exw (sin labor ni logistics)
  ```
- Esto significa que el `total_unit_cost_snapshot` guardado será solo `cost_exw`, no el costo total real.

#### Paso 4: Guardar QuoteLine
```typescript
const quoteLineData: any = {
  // ... otros campos ...
  computed_qty: computedQty,
  unit_price_snapshot: msrp, // ⚠️ Puede ser 0 si msrp es NULL
  unit_cost_snapshot: catalogItem?.cost_exw || 0, // Legacy
  total_unit_cost_snapshot: pricingResult.totalUnitCost, // ⚠️ Solo cost_exw si otros campos son null
  discount_pct_used: pricingResult.discountPct,
  customer_type_snapshot: customerType,
  price_basis: 'MSRP_TIER', // Siempre MSRP_TIER cuando se guarda
  margin_pct_used: pricingResult.totalUnitCost > 0 && pricingResult.unitPrice > 0
    ? ((pricingResult.unitPrice - pricingResult.totalUnitCost) / pricingResult.unitPrice * 100)
    : null,
  line_total: lineTotal, // ⚠️ Puede ser 0 si msrp es NULL
  // ...
};
```

---

### 3. Visualización en UI (Tabla de QuoteLines)

**Ubicación:** `src/pages/sales/QuoteNew.tsx` (líneas 1533-1558)

#### Para Quotes NO aprobados (status !== 'approved'):
```typescript
// Muestra MSRP directo (sin descuentos)
formatCurrency(line.line_total || 0, watch('currency'))
```
- **Muestra:** `line.line_total` que es `msrp * computedQty`
- **Si `msrp` es NULL o 0 → muestra $0.00**

#### Para Quotes aprobados (status === 'approved'):
```typescript
// Muestra MSRP con descuento de tier aplicado
const msrp = line.unit_price_snapshot || 0;
const discountPct = line.discount_pct_used || 0;
const computedQty = line.computed_qty || line.qty || 1;
const unitPriceWithDiscount = msrp * (1 - discountPct / 100);
const lineTotalWithDiscount = unitPriceWithDiscount * computedQty;
```
- **Muestra:** Precio con descuento aplicado
- **Si `unit_price_snapshot` es 0 → muestra $0.00**

---

## 🔍 Problemas Identificados

### Problema 1: MSRP NULL o 0
**Síntoma:** Precios mostrados como $0.00 o $23.26 / $24.06 (parecen incorrectos)

**Causas posibles:**
1. CatalogItems no tienen `msrp` calculado
2. El script `UPDATE_MSRP_FOR_EXISTING_ITEMS.sql` no se ejecutó
3. Items nuevos no tienen `msrp` porque no se calcularon automáticamente

**Solución:**
- Verificar que todos los CatalogItems tengan `msrp` > 0
- Ejecutar el script de actualización si es necesario
- Agregar fallback para calcular MSRP desde `cost_exw` si `msrp` es NULL

### Problema 2: total_unit_cost_snapshot incorrecto
**Síntoma:** El snapshot de costo total no incluye labor ni logistics

**Causa:**
- En `handleProductConfigComplete`, los campos opcionales se envían como `null`:
  ```typescript
  labor_cost_per_unit: null,
  shipping_cost_per_unit: null,
  // etc.
  ```
- `computeTotalUnitCost` solo suma `cost_exw + 0 + 0 = cost_exw`

**Solución:**
- Obtener los campos reales de CatalogItems si existen
- O al menos documentar que `total_unit_cost_snapshot` solo incluye `cost_exw` por ahora

### Problema 3: No hay validación ni logs
**Síntoma:** Difícil debuggear por qué los precios están mal

**Causa:**
- No hay `console.log` para ver qué valores se están usando
- No hay validación que alerte si `msrp` es NULL o 0

**Solución:**
- Agregar logs de debugging
- Agregar validación y alertas si `msrp` es NULL o 0

---

## 📊 Datos Guardados en QuoteLines

| Campo | Valor Guardado | Fuente | Notas |
|-------|---------------|--------|-------|
| `unit_price_snapshot` | `msrp` del CatalogItem | `catalogItem?.msrp \|\| 0` | Precio público MSRP (sin descuentos) |
| `line_total` | `msrp * computedQty` | Calculado | Total de línea (sin descuentos) |
| `unit_cost_snapshot` | `cost_exw` del CatalogItem | `catalogItem?.cost_exw \|\| 0` | Legacy - solo cost_exw |
| `total_unit_cost_snapshot` | `computeTotalUnitCost(...)` | `pricingResult.totalUnitCost` | ⚠️ Actualmente solo cost_exw (otros campos son null) |
| `discount_pct_used` | Descuento del tier del cliente | `pricingResult.discountPct` | Se aplica cuando Quote está Approved |
| `customer_type_snapshot` | Tipo de cliente | `customerType` | Para referencia futura |
| `price_basis` | `'MSRP_TIER'` | Fijo | Siempre MSRP_TIER al guardar |
| `margin_pct_used` | Margen real después de descuento | Calculado | Solo si hay datos válidos |

---

## 🧪 Casos de Prueba

### Caso 1: CatalogItem con MSRP válido
```
Input:
  - catalogItem.msrp = 100.00
  - catalogItem.cost_exw = 50.00
  - computedQty = 1.2 m²
  - status = 'draft'

Expected:
  - unit_price_snapshot = 100.00
  - line_total = 120.00
  - UI muestra: $120.00

Actual: ✅ Debería funcionar correctamente
```

### Caso 2: CatalogItem con MSRP NULL o 0
```
Input:
  - catalogItem.msrp = NULL o 0
  - catalogItem.cost_exw = 50.00
  - computedQty = 1.2 m²
  - status = 'draft'

Expected:
  - ⚠️ unit_price_snapshot = 0
  - ⚠️ line_total = 0
  - UI muestra: $0.00

Actual: ❌ PROBLEMA - No hay fallback para calcular desde cost_exw
```

### Caso 3: Quote Approved con descuento
```
Input:
  - unit_price_snapshot = 100.00
  - discount_pct_used = 25%
  - computedQty = 1.2 m²
  - status = 'approved'

Expected:
  - UI muestra: $90.00 (100 * 0.75 * 1.2)
  - Muestra badge: "25.0% tier discount"

Actual: ✅ Debería funcionar correctamente
```

---

## 🔧 Recomendaciones

### 1. Agregar fallback para MSRP NULL
```typescript
// En handleProductConfigComplete, después de obtener catalogItem:
let msrp = catalogItem?.msrp || 0;

// Si msrp es 0 o NULL, calcular desde cost_exw
if (msrp === 0 || msrp === null) {
  const totalUnitCost = catalogItem?.cost_exw || 0;
  const marginPct = resolveMarginPct(
    catalogItem?.default_margin_pct,
    categoryMargin,
    35
  );
  msrp = computeMsrpFromMarginOnSale(totalUnitCost, marginPct);
  
  // Log para debugging
  console.warn(`⚠️ MSRP was NULL/0 for item ${catalogItemId}, calculated from cost_exw: ${msrp}`);
}
```

### 2. Obtener campos opcionales de CatalogItems
```typescript
// En el select de CatalogItems, agregar campos opcionales:
const { data: catalogItem } = await supabase
  .from('CatalogItems')
  .select(`
    collection_name, 
    variant_name, 
    cost_exw, 
    msrp, 
    default_margin_pct, 
    uom, 
    item_category_id,
    labor_cost_per_unit,
    shipping_cost_per_unit,
    freight_cost,
    handling_cost,
    import_tax_pct
  `)
  .eq('id', catalogItemId)
  .maybeSingle();

// Luego pasar estos valores a calculateQuoteLinePrice:
const pricingResult = calculateQuoteLinePrice(
  {
    msrp: catalogItem?.msrp || null,
    cost_exw: catalogItem?.cost_exw || null,
    labor_cost_per_unit: catalogItem?.labor_cost_per_unit || null,
    shipping_cost_per_unit: catalogItem?.shipping_cost_per_unit || null,
    freight_cost: catalogItem?.freight_cost || null,
    handling_cost: catalogItem?.handling_cost || null,
    import_tax_pct: catalogItem?.import_tax_pct || null,
    default_margin_pct: catalogItem?.default_margin_pct || null,
  },
  // ...
);
```

### 3. Agregar validación y logs
```typescript
// Después de obtener catalogItem:
if (!catalogItem) {
  console.error('❌ CatalogItem not found:', catalogItemId);
  // Mostrar error al usuario
  return;
}

if (!catalogItem.msrp || catalogItem.msrp === 0) {
  console.warn('⚠️ CatalogItem has no MSRP:', {
    id: catalogItemId,
    cost_exw: catalogItem.cost_exw,
    default_margin_pct: catalogItem.default_margin_pct,
  });
  // Opcionalmente: mostrar alerta al usuario
}
```

### 4. Verificar datos en base de datos
```sql
-- Verificar CatalogItems sin MSRP
SELECT 
  id, 
  sku, 
  collection_name, 
  variant_name, 
  cost_exw, 
  msrp, 
  default_margin_pct,
  msrp_manual
FROM "CatalogItems"
WHERE "deleted" = false
  AND ("msrp" IS NULL OR "msrp" = 0)
  AND "cost_exw" > 0
ORDER BY "updated_at" DESC
LIMIT 50;

-- Verificar QuoteLines con precios 0
SELECT 
  id,
  quote_id,
  unit_price_snapshot,
  line_total,
  total_unit_cost_snapshot,
  unit_cost_snapshot
FROM "QuoteLines"
WHERE "deleted" = false
  AND ("unit_price_snapshot" = 0 OR "line_total" = 0)
ORDER BY "created_at" DESC
LIMIT 50;
```

---

## 📝 Conclusión

**Problema principal identificado:**
- Si `CatalogItem.msrp` es NULL o 0, los QuoteLines se guardan con precio 0
- No hay fallback para calcular MSRP desde `cost_exw` cuando se crea un QuoteLine
- El `total_unit_cost_snapshot` solo incluye `cost_exw` porque los campos opcionales se envían como `null`

**Acción inmediata recomendada:**
1. Verificar en BD cuántos CatalogItems tienen MSRP NULL o 0
2. Ejecutar el script `UPDATE_MSRP_FOR_EXISTING_ITEMS.sql` si es necesario
3. Agregar el fallback sugerido en el código
4. Agregar validación y logs para debugging futuro

---

**Fecha de revisión:** 2024-12-24  
**Archivo revisado:** `src/pages/sales/QuoteNew.tsx` (líneas 430-561, 1533-1558)  
**Función de pricing:** `src/lib/pricing.ts`





