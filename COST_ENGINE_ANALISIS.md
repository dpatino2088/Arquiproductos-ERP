# 🔍 ANÁLISIS: Problemas en CostEngine

**Fecha:** 2026-01-25  
**Problema:** Columnas vacías en ImportTax, Shipping y MSRP sale_out calculado incorrectamente

---

## 🔴 PROBLEMAS IDENTIFICADOS

### 1. **Import Tax y Shipping en 0**

**Causa:**
- La función `msrp_compute_for_item` lee `shipping_pct` y `global_import_tax_pct` desde `CostSettings`
- Si `CostSettings` no existe para la organización, o si los valores son 0, los costos serán 0
- Si `ImportTaxRules` no tiene reglas activas, se usa `global_import_tax_pct` que puede ser 0

**Solución:**
- Verificar que `CostSettings` tenga valores configurados para cada organización
- Verificar que `ImportTaxRules` tenga reglas activas si se requiere import tax por categoría
- La función ya maneja NULL correctamente, pero los valores pueden ser 0 si no están configurados

### 2. **Fórmula de msrp_sale_out Incorrecta**

**Fórmula ACTUAL (posiblemente incorrecta):**
```sql
v_sale_in := v_total / (1 - v_sale_in_pct);  -- v_sale_in_pct = 0.35
v_sale_out := v_sale_in / (1 - v_sale_out_pct);  -- v_sale_out_pct = 0.65
```

**Ejemplo con v_total = 100:**
- `v_sale_in = 100 / (1 - 0.35) = 100 / 0.65 = 153.85`
- `v_sale_out = 153.85 / (1 - 0.65) = 153.85 / 0.35 = 439.29`

**Problema:** Esta fórmula aplica el margen `sale_out` sobre `sale_in`, no sobre el costo total.

**Fórmula CORREGIDA (si sale_out es margen sobre costo total):**
```sql
v_sale_in := v_total / (1 - v_sale_in_pct);
v_sale_out := v_total / (1 - v_sale_out_pct);  -- ✅ CORRECCIÓN
```

**Ejemplo con v_total = 100:**
- `v_sale_in = 100 / (1 - 0.35) = 100 / 0.65 = 153.85`
- `v_sale_out = 100 / (1 - 0.65) = 100 / 0.35 = 285.71`

**Diferencia:** La fórmula corregida da un valor menor (285.71 vs 439.29), lo cual tiene más sentido si ambos son márgenes sobre el costo total.

---

## 📊 INTERPRETACIÓN DE MÁRGENES

### Opción A: Márgenes sobre Costo Total (RECOMENDADA)
- `msrp_pct_sale_in = 0.35` → Margen del 35% sobre costo total
- `msrp_pct_sale_out = 0.65` → Margen del 65% sobre costo total
- **Fórmula:** `precio = costo_total / (1 - margen_pct)`

### Opción B: Markup sobre Sale-In (ACTUAL)
- `msrp_pct_sale_in = 0.35` → Margen del 35% sobre costo total
- `msrp_pct_sale_out = 0.65` → Markup del 65% sobre sale_in
- **Fórmula:** `sale_out = sale_in / (1 - markup_pct)`

**Recomendación:** Usar Opción A (márgenes sobre costo total) porque:
1. Es más intuitivo
2. Permite configurar márgenes independientes por categoría
3. Evita que sale_out sea excesivamente alto

---

## 🔧 CORRECCIONES NECESARIAS

### 1. Verificar CostSettings
```sql
-- Verificar que todas las organizaciones tengan CostSettings
SELECT o.id, o.name, cs.shipping_pct, cs.global_import_tax_pct
FROM public."Organizations" o
LEFT JOIN public."CostSettings" cs ON cs.organization_id = o.id
WHERE cs.id IS NULL;
```

### 2. Corregir Fórmula de msrp_sale_out
```sql
-- Cambiar de:
v_sale_out := v_sale_in / (1 - v_sale_out_pct);

-- A:
v_sale_out := v_total / (1 - v_sale_out_pct);
```

### 3. Recalcular Todos los Items
```sql
-- Después de corregir la función, recalcular todos los items
SELECT msrp_compute_for_item(id) 
FROM public."CatalogItems" 
WHERE cost_exw > 0 
  AND organization_id IS NOT NULL;
```

---

## ⚠️ NOTA IMPORTANTE

**Labor:** No se calcula en `msrp_compute_for_item` porque:
- Labor es un porcentaje que se aplica **después** de calcular el MSRP base
- Labor se aplica en el contexto de ConfiguredProducts o QuoteLines, no en el cálculo base de MSRP por SKU
- Esto es correcto según el modelo de negocio

---

## 📝 PRÓXIMOS PASOS

1. ✅ Ejecutar script de diagnóstico: `20260125_diagnose_cost_engine.sql`
2. ✅ Verificar CostSettings por organización
3. ✅ Corregir función: `20260125_fix_msrp_compute_for_item.sql`
4. ⚠️ Recalcular todos los items después de corregir la función
