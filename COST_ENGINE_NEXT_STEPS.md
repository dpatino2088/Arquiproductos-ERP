# 🚀 PRÓXIMOS PASOS: CostEngine Fix

**Fecha:** 2026-01-25  
**Estado:** ✅ Fix aplicado

---

## ✅ PASO 1: Verificar que el fix se aplicó correctamente

Ejecuta el script de verificación:

```sql
\i database/migrations/20260125_verify_cost_engine_fix.sql
```

**Qué verifica:**
- ✅ Que todas las funciones existen
- ✅ Que todos los triggers existen
- ✅ Que la fórmula de `import_tax_cost` es correcta
- ✅ Que la fórmula de `msrp_sale_out` es correcta
- ✅ Estadísticas generales

---

## ✅ PASO 2: Recalcular todos los items

**IMPORTANTE:** Después de aplicar el fix, necesitas recalcular todos los items con las fórmulas corregidas.

Ejecuta:

```sql
\i database/migrations/20260125_recalculate_all_msrp_after_fix.sql
```

**Qué hace:**
- Recalcula MSRP para todos los `CatalogItems` con `cost_exw > 0`
- Usa las fórmulas corregidas:
  - `import_tax_cost = (cost_exw + shipping_cost) * import_tax_pct`
  - `msrp_sale_out = total_cost / (1 - msrp_pct_sale_out)`
- Muestra progreso cada 100 items

**Tiempo estimado:** Depende de la cantidad de items (puede tomar varios minutos)

---

## ✅ PASO 3: Corregir función calculate_configured_product_totals

**IMPORTANTE:** La función `calculate_configured_product_totals` está usando las tablas antiguas `BomInstances` y `BomInstanceLines`. Necesitas corregirla.

Ejecuta:

```sql
\i database/migrations/20260125_fix_configured_products_bom_tables.sql
```

**Qué corrige:**
- ✅ Cambia `BomInstances` → `BOMInstances` (mayúsculas)
- ✅ Cambia `BomInstanceLines` → `BOMInstanceLines` (mayúsculas)
- ✅ Ya usa `msrp_sale_out` correctamente (no necesita cambio)

**Verificar después:**
- Debe usar `msrp_sale_out` de `CatalogItemsMSRP` para calcular `roll_msrp_total`
- Debe sumar `roll_msrp_total + bom_total = roll_plus_bom_total`

---

## ✅ PASO 4: Probar el flujo completo

### Test 1: Cambiar ImportTaxRule
```sql
-- 1. Crear/actualizar ImportTaxRule para una categoría
INSERT INTO public."ImportTaxRules" (organization_id, category_id, import_tax_pct, is_active)
VALUES ('tu-org-id', 'tu-category-id', 0.15, true)
ON CONFLICT (organization_id, category_id) 
DO UPDATE SET import_tax_pct = 0.15, is_active = true;

-- 2. Verificar que se recalculó automáticamente
SELECT ci.sku, cim.import_tax_cost, cim.total_cost
FROM public."CatalogItems" ci
JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id
WHERE ci.category_id = 'tu-category-id'
LIMIT 5;
```

### Test 2: Cambiar CategoryMargin
```sql
-- 1. Crear/actualizar CategoryMargin
INSERT INTO public."CategoryMargins" (organization_id, category_id, msrp_pct_sale_out, is_active)
VALUES ('tu-org-id', 'tu-category-id', 0.70, true)
ON CONFLICT (organization_id, category_id)
DO UPDATE SET msrp_pct_sale_out = 0.70, is_active = true;

-- 2. Verificar que se recalculó automáticamente
SELECT ci.sku, cim.msrp_sale_out
FROM public."CatalogItems" ci
JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id
WHERE ci.category_id = 'tu-category-id'
LIMIT 5;
```

### Test 3: Cambiar cost_exw en CatalogItem
```sql
-- 1. Actualizar cost_exw
UPDATE public."CatalogItems"
SET cost_exw = 10.50
WHERE id = 'tu-item-id';

-- 2. Verificar que se recalculó automáticamente
SELECT cim.cost_exw, cim.shipping_cost, cim.import_tax_cost, cim.total_cost, cim.msrp_sale_out
FROM public."CatalogItemsMSRP" cim
WHERE cim.catalog_item_id = 'tu-item-id';
```

---

## 📋 CHECKLIST FINAL

- [ ] ✅ Fix aplicado (`20260125_fix_cost_engine_complete.sql`)
- [ ] ✅ Verificación ejecutada (`20260125_verify_cost_engine_fix.sql`)
- [ ] ✅ Todos los items recalculados (`20260125_recalculate_all_msrp_after_fix.sql`)
- [ ] ✅ Test 1: Cambiar ImportTaxRule → Se recalcula automáticamente
- [ ] ✅ Test 2: Cambiar CategoryMargin → Se recalcula automáticamente
- [ ] ✅ Test 3: Cambiar cost_exw → Se recalcula automáticamente
- [ ] ✅ ConfiguredProducts usa `msrp_sale_out` correctamente
- [ ] ✅ QuoteLines guarda snapshots correctamente

---

## 🔍 VERIFICACIÓN MANUAL

### Verificar un item específico:

```sql
-- Ver detalles de un item
SELECT 
  ci.sku,
  ci.cost_exw,
  cs.shipping_pct,
  COALESCE(itr.import_tax_pct, cs.global_import_tax_pct, 0) as import_tax_pct,
  cim.shipping_cost,
  cim.import_tax_cost,
  cim.total_cost,
  cim.msrp_sale_in,
  cim.msrp_sale_out,
  -- Verificar fórmulas
  (ci.cost_exw * cs.shipping_pct) as shipping_cost_expected,
  ((ci.cost_exw + (ci.cost_exw * cs.shipping_pct)) * COALESCE(itr.import_tax_pct, cs.global_import_tax_pct, 0)) as import_tax_cost_expected,
  (cim.total_cost / (1 - COALESCE(cm.msrp_pct_sale_out, cs.default_msrp_pct_sale_out, 0.65))) as msrp_sale_out_expected
FROM public."CatalogItems" ci
JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id
LEFT JOIN public."CostSettings" cs ON cs.organization_id = ci.organization_id
LEFT JOIN public."ImportTaxRules" itr ON itr.organization_id = ci.organization_id 
  AND itr.category_id = ci.category_id 
  AND COALESCE(itr.is_active, true) = true
LEFT JOIN public."CategoryMargins" cm ON cm.organization_id = ci.organization_id 
  AND cm.category_id = ci.category_id
  AND COALESCE(cm.is_active, true) = true
WHERE ci.id = 'tu-item-id';
```

---

## ⚠️ NOTAS IMPORTANTES

1. **Performance:** Los triggers recalculan automáticamente, pero pueden ser lentos con muchos items. Si es necesario, puedes deshabilitar temporalmente los triggers para cambios masivos.

2. **Jerarquía de Categorías:** Si una categoría no tiene regla, busca en `parent_id` recursivamente. Esto puede afectar el performance si hay muchas categorías anidadas.

3. **ConfiguredProducts:** Asegúrate de que `calculate_configured_product_totals` use `msrp_sale_out` (no `msrp_sale_in`) para calcular `roll_msrp_total`.

4. **QuoteLines:** Los snapshots deben estar congelados. No deben cambiar aunque cambien los costos base.

---

**Siguiente paso:** Ejecutar `20260125_recalculate_all_msrp_after_fix.sql` para recalcular todos los items con las fórmulas corregidas.
