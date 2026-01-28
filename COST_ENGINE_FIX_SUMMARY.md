# 🔧 RESUMEN: Corrección de CostEngine

**Fecha:** 2026-01-25  
**Problema:** Columnas vacías en ImportTax/Shipping y MSRP sale_out calculado incorrectamente

---

## ✅ ARCHIVOS CREADOS

### 1. **Script de Diagnóstico**
- `database/migrations/20260125_diagnose_cost_engine.sql`
- Verifica:
  - CostSettings por organización
  - ImportTaxRules activas
  - CategoryMargins configurados
  - Valores en CatalogItemsMSRP
  - Ejemplo de cálculo para un item

### 2. **Migración de Corrección**
- `database/migrations/20260125_fix_msrp_compute_for_item.sql`
- Corrige:
  - Fórmula de `msrp_sale_out` (ahora calcula desde `v_total` en lugar de `v_sale_in`)
  - Mejora comentarios y documentación
  - Mantiene lógica de import_tax y shipping (ya estaba correcta)

### 3. **Script de Recalculación**
- `database/migrations/20260125_recalculate_all_msrp_after_fix.sql`
- Recalcula MSRP para todos los items después de corregir la función

---

## 🔴 PROBLEMA PRINCIPAL: Fórmula de msrp_sale_out

### Fórmula ORIGINAL (Incorrecta):
```sql
v_sale_in := v_total / (1 - v_sale_in_pct);        -- Ej: 100 / 0.65 = 153.85
v_sale_out := v_sale_in / (1 - v_sale_out_pct);    -- Ej: 153.85 / 0.35 = 439.29 ❌
```

**Problema:** Aplica el margen `sale_out` sobre `sale_in`, dando valores excesivamente altos.

### Fórmula CORREGIDA:
```sql
v_sale_in := v_total / (1 - v_sale_in_pct);        -- Ej: 100 / 0.65 = 153.85
v_sale_out := v_total / (1 - v_sale_out_pct);       -- Ej: 100 / 0.35 = 285.71 ✅
```

**Corrección:** Ambos márgenes se calculan desde el costo total, no uno desde el otro.

---

## ⚠️ PROBLEMA SECUNDARIO: Import Tax y Shipping en 0

### Causa:
- `CostSettings` puede no existir para la organización
- `shipping_pct` y `global_import_tax_pct` pueden ser 0
- `ImportTaxRules` puede no tener reglas activas

### Solución:
1. **Verificar CostSettings:**
   ```sql
   SELECT * FROM public."CostSettings" WHERE organization_id = 'tu-org-id';
   ```
   - Si no existe, crear registro con valores apropiados
   - Si existe pero tiene valores 0, actualizar con valores correctos

2. **Verificar ImportTaxRules:**
   ```sql
   SELECT * FROM public."ImportTaxRules" 
   WHERE organization_id = 'tu-org-id' 
     AND COALESCE(is_active, true) = true;
   ```
   - Si no hay reglas, se usará `global_import_tax_pct` de CostSettings
   - Si `global_import_tax_pct = 0`, entonces `import_tax_cost = 0` (esto es correcto si no hay import tax)

3. **La función ya maneja NULL correctamente:**
   - Si CostSettings no existe, usa valores por defecto (0 para tax/shipping)
   - Esto es correcto, pero puede ser el problema si se esperan valores > 0

---

## 📋 PASOS PARA CORREGIR

### Paso 1: Ejecutar Diagnóstico
```sql
-- Ejecutar: 20260125_diagnose_cost_engine.sql
-- Esto mostrará:
-- - Qué organizaciones no tienen CostSettings
-- - Cuántos items tienen valores en 0
-- - Ejemplo de cálculo para verificar la fórmula
```

### Paso 2: Verificar/Configurar CostSettings
```sql
-- Para cada organización, verificar/crear CostSettings:
INSERT INTO public."CostSettings" (
  organization_id,
  shipping_pct,
  global_import_tax_pct,
  default_msrp_pct_sale_out,
  minimum_margin_pct
) VALUES (
  'tu-org-id',
  0.15,  -- 15% shipping
  0.10,  -- 10% import tax (ajustar según necesidad)
  0.65,  -- 65% margen sale out
  0.35   -- 35% margen mínimo
) ON CONFLICT (organization_id) DO UPDATE SET
  shipping_pct = EXCLUDED.shipping_pct,
  global_import_tax_pct = EXCLUDED.global_import_tax_pct,
  default_msrp_pct_sale_out = EXCLUDED.default_msrp_pct_sale_out,
  minimum_margin_pct = EXCLUDED.minimum_margin_pct;
```

### Paso 3: Corregir Función
```sql
-- Ejecutar: 20260125_fix_msrp_compute_for_item.sql
-- Esto corrige la fórmula de msrp_sale_out
```

### Paso 4: Recalcular Todos los Items
```sql
-- Ejecutar: 20260125_recalculate_all_msrp_after_fix.sql
-- Esto recalcula MSRP para todos los items con la fórmula corregida
```

---

## 🎯 RESULTADO ESPERADO

Después de aplicar las correcciones:

1. **Import Tax y Shipping:**
   - Si CostSettings tiene valores > 0, los costos se calcularán correctamente
   - Si CostSettings tiene valores 0, los costos serán 0 (esto es correcto si no hay import tax/shipping)

2. **MSRP Sale Out:**
   - Se calculará correctamente desde el costo total
   - Valores serán más razonables (menores que con la fórmula incorrecta)
   - Ejemplo: costo=100, sale_out_pct=65% → sale_out = 285.71 (en lugar de 439.29)

---

## ⚠️ NOTA SOBRE LABOR

**Labor NO se calcula en `msrp_compute_for_item`** porque:
- Labor es un porcentaje que se aplica **después** del cálculo base de MSRP
- Labor se aplica en el contexto de ConfiguredProducts o QuoteLines
- Esto es correcto según el modelo de negocio

Si necesitas incluir labor en el cálculo base de MSRP, sería necesario modificar la función, pero esto cambiaría el modelo de negocio actual.

---

## 📝 VERIFICACIÓN POST-CORRECCIÓN

```sql
-- Verificar que los valores se calcularon correctamente
SELECT 
  ci.sku,
  ci.cost_exw,
  cim.import_tax_cost,
  cim.shipping_cost,
  cim.total_cost,
  cim.msrp_sale_in,
  cim.msrp_sale_out,
  -- Verificar fórmula: msrp_sale_out debería ser aproximadamente total_cost / (1 - 0.65)
  (cim.total_cost / 0.35) AS expected_sale_out,
  ABS(cim.msrp_sale_out - (cim.total_cost / 0.35)) AS difference
FROM public."CatalogItems" ci
JOIN public."CatalogItemsMSRP" cim ON cim.catalog_item_id = ci.id
WHERE ci.cost_exw > 0
  AND ci.deleted = false
LIMIT 10;
```

---

**Estado:** ✅ Migraciones creadas. ⚠️ Pendiente ejecutar en orden: Diagnóstico → Verificar CostSettings → Corregir Función → Recalcular Items
