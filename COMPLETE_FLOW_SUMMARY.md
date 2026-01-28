# ✅ FLUJO COMPLETO: CatalogItemsMSRP → ConfiguredProducts → QuoteLines

**Fecha:** 2026-01-25  
**Estado:** ✅ Implementación completa

---

## 📊 FLUJO DE DATOS

```
CatalogItems
  ↓ (trigger: cost_exw o category_id cambia)
msrp_compute_for_item()
  ↓
CatalogItemsMSRP
  - cost_exw
  - shipping_cost = cost_exw * shipping_pct
  - import_tax_cost = (cost_exw + shipping_cost) * import_tax_pct ✅ CORREGIDO
  - total_cost = cost_exw + shipping_cost + import_tax_cost
  - msrp_sale_in = total_cost / (1 - msrp_pct_sale_in)
  - msrp_sale_out = total_cost / (1 - msrp_pct_sale_out) ✅ CORREGIDO
  ↓
ConfiguredProducts (vivo, se recalcula)
  - roll_msrp_total = msrp_sale_out × roll_width × height_m × quantity
  - bom_total = SUM(msrp_sale_out × qty) de cada BOMInstanceLine
  - roll_plus_bom_total = roll_msrp_total + bom_total
  - roll_total_cost = total_cost × roll_width × height_m × quantity ✅ NUEVO
  - bom_total_cost = SUM(total_cost × qty) de cada BOMInstanceLine ✅ NUEVO
  ↓
QuoteLines (snapshot congelado)
  - roll_msrp_snapshot = ConfiguredProducts.roll_msrp_total
  - bom_msrp_snapshot = ConfiguredProducts.bom_total
  - msrp = ConfiguredProducts.roll_plus_bom_total
  - roll_cost_snapshot = ConfiguredProducts.roll_total_cost ✅ NUEVO
  - bom_cost_snapshot = ConfiguredProducts.bom_total_cost ✅ NUEVO
  - total_cost = roll_cost_snapshot + bom_cost_snapshot
  - net_price = msrp × (1 - discount_pct)
```

---

## ✅ IMPLEMENTACIÓN

### 1. CatalogItemsMSRP ✅
- **Función:** `msrp_compute_for_item(item_id)`
- **Triggers:** Recalcula automáticamente cuando cambian:
  - `CatalogItems.cost_exw` o `category_id`
  - `ImportTaxRules`
  - `CategoryMargins`
  - `CostSettings.shipping_pct` o `global_import_tax_pct`
- **Fórmulas:**
  - `shipping_cost = cost_exw * shipping_pct`
  - `import_tax_cost = (cost_exw + shipping_cost) * import_tax_pct` ✅ CORREGIDO
  - `total_cost = cost_exw + shipping_cost + import_tax_cost`
  - `msrp_sale_out = total_cost / (1 - msrp_pct_sale_out)` ✅ CORREGIDO

### 2. ConfiguredProducts ✅
- **Función:** `calculate_configured_product_totals(configured_product_id)`
- **Columnas agregadas:**
  - `roll_total_cost` ✅ NUEVO
  - `bom_total_cost` ✅ NUEVO
- **Cálculos:**
  - `roll_msrp_total = msrp_sale_out × roll_width × height_m × quantity`
  - `bom_total = SUM(msrp_sale_out × qty)` de cada BOMInstanceLine
  - `roll_plus_bom_total = roll_msrp_total + bom_total`
  - `roll_total_cost = total_cost × roll_width × height_m × quantity` ✅ NUEVO
  - `bom_total_cost = SUM(total_cost × qty)` de cada BOMInstanceLine ✅ NUEVO
- **Tablas usadas:** `BOMInstances`, `BOMInstanceLines` (mayúsculas) ✅ CORREGIDO

### 3. QuoteLines ✅
- **Servicio:** `createQuoteLineFromConfiguredProduct()`
- **Snapshots guardados:**
  - `roll_msrp_snapshot = ConfiguredProducts.roll_msrp_total`
  - `bom_msrp_snapshot = ConfiguredProducts.bom_total`
  - `roll_cost_snapshot = ConfiguredProducts.roll_total_cost` ✅ NUEVO
  - `bom_cost_snapshot = ConfiguredProducts.bom_total_cost` ✅ NUEVO
  - `msrp = ConfiguredProducts.roll_plus_bom_total`
  - `total_cost = roll_cost_snapshot + bom_cost_snapshot`
  - `net_price = msrp × (1 - discount_pct)`
- **Inmutabilidad:** QuoteLines NO se recalcula automáticamente cuando cambian CatalogItemsMSRP ✅

---

## 📁 ARCHIVOS CREADOS/MODIFICADOS

### Migraciones SQL:
1. ✅ `20260125_fix_cost_engine_complete.sql` - Corrección completa del CostEngine
2. ✅ `20260125_fix_configured_products_bom_tables.sql` - Corrige referencias a tablas BOM
3. ✅ `20260125_complete_configured_products_quote_lines_flow.sql` - Completa el flujo con costos reales

### Código TypeScript:
1. ✅ `src/lib/quotes/createQuoteLineFromConfiguredProduct.ts` - Actualizado para usar costos desde ConfiguredProducts

---

## 🎯 CRITERIOS DE ACEPTACIÓN

✅ **Cambiar CatalogItemsMSRP** → NO cambia QuoteLines existentes (snapshot congelado)  
✅ **ConfiguredProducts** → Siempre consistente: `roll_plus_bom_total = roll_msrp_total + bom_total`  
✅ **BOMInstances/BOMInstanceLines** → Se usan (no tablas OLD)  
✅ **Costos reales** → Se calculan y guardan en ConfiguredProducts y QuoteLines  
✅ **Multi-tenant** → Todo por `organization_id` (RLS-friendly)  

---

## 🚀 PASOS PARA APLICAR

### Paso 1: Aplicar migraciones (en orden)
```sql
-- 1. Fix CostEngine (si no se aplicó antes)
\i database/migrations/20260125_fix_cost_engine_complete.sql

-- 2. Corregir ConfiguredProducts (tablas BOM)
\i database/migrations/20260125_fix_configured_products_bom_tables.sql

-- 3. Completar flujo con costos reales
\i database/migrations/20260125_complete_configured_products_quote_lines_flow.sql
```

### Paso 2: Recalcular ConfiguredProducts existentes
```sql
-- Recalcular todos los ConfiguredProducts para que tengan roll_total_cost y bom_total_cost
DO $$
DECLARE
  v_cp RECORD;
  v_count integer := 0;
BEGIN
  FOR v_cp IN
    SELECT id
    FROM public."ConfiguredProducts"
    WHERE deleted = false
  LOOP
    BEGIN
      PERFORM public.calculate_configured_product_totals(v_cp.id);
      v_count := v_count + 1;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE WARNING 'Error recalculando ConfiguredProduct %: %', v_cp.id, SQLERRM;
    END;
  END LOOP;
  
  RAISE NOTICE 'Recalculados % ConfiguredProducts', v_count;
END $$;
```

### Paso 3: Verificar
```sql
-- Verificar que ConfiguredProducts tiene costos
SELECT 
  id,
  roll_msrp_total,
  bom_total,
  roll_plus_bom_total,
  roll_total_cost,
  bom_total_cost,
  (roll_msrp_total + bom_total) as roll_plus_bom_verificado
FROM public."ConfiguredProducts"
WHERE deleted = false
LIMIT 10;
```

---

## ⚠️ NOTAS IMPORTANTES

1. **QuoteLines es inmutable:** Una vez creado, NO cambia aunque cambien CatalogItemsMSRP
2. **ConfiguredProducts es vivo:** Se recalcula cada vez que cambia la configuración
3. **Costos reales:** Ahora se calculan y guardan para poder calcular márgenes correctamente
4. **BOMInstances:** Siempre usar tablas con mayúsculas (`BOMInstances`, `BOMInstanceLines`)

---

**Estado:** ✅ Listo para usar
