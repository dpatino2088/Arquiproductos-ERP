# ✅ CORRECCIÓN COMPLETA DEL COSTENGINE

**Fecha:** 2026-01-25  
**Estado:** ✅ Migración completa creada

---

## 📋 RESUMEN DE CORRECCIONES

### 1. ✅ Fórmula de Import Tax Corregida
**Antes (Incorrecta):**
```sql
import_tax_cost = cost_exw * import_tax_pct
```

**Ahora (Correcta):**
```sql
import_tax_cost = (cost_exw + shipping_cost) * import_tax_pct
```

**Razón:** El import tax se aplica sobre el costo total (incluyendo shipping), no solo sobre el costo base.

### 2. ✅ Fórmula de MSRP Sale-Out Corregida
**Antes (Incorrecta):**
```sql
msrp_sale_out = msrp_sale_in / (1 - msrp_pct_sale_out)
```

**Ahora (Correcta):**
```sql
msrp_sale_out = total_cost / (1 - msrp_pct_sale_out)
```

**Razón:** Ambos márgenes (sale_in y sale_out) deben calcularse desde el costo total, no uno desde el otro.

### 3. ✅ Soporte para Jerarquía de Categorías
- Busca reglas de import tax y márgenes subiendo por la jerarquía (`parent_id` en `CatalogCategories`)
- Si no encuentra regla en la categoría actual, busca en la categoría padre
- Continúa hasta encontrar una regla o llegar a la raíz

### 4. ✅ Triggers Automáticos
- **CatalogItems**: Recalcula cuando cambia `cost_exw` o `category_id`
- **ImportTaxRules**: Recalcula todos los items de la categoría afectada
- **CategoryMargins**: Recalcula todos los items de la categoría afectada
- **CostSettings**: Recalcula todos los items de la organización cuando cambia `shipping_pct` o `global_import_tax_pct`

### 5. ✅ Función para Recompute Masivo
- `msrp_recompute_for_category(p_category_id, p_organization_id)`: Recalcula todos los items de una categoría
- Útil para cambios masivos o correcciones

---

## 📁 ARCHIVOS CREADOS

### 1. `database/migrations/20260125_fix_cost_engine_complete.sql`
**Contenido:**
- Función `get_import_tax_pct_for_category`: Busca import tax con jerarquía
- Función `get_category_margins_for_category`: Busca márgenes con jerarquía
- Función `msrp_compute_for_item`: Función principal corregida
- Función `msrp_recompute_for_category`: Recompute masivo por categoría
- Triggers para recalcular automáticamente

### 2. `database/migrations/20260125_diagnose_cost_engine.sql`
- Script de diagnóstico para verificar el estado actual

### 3. `database/migrations/20260125_recalculate_all_msrp_after_fix.sql`
- Script para recalcular todos los items después de aplicar la corrección

---

## 🔧 FÓRMULAS FINALES

### Cálculo de Costos:
```sql
shipping_cost = cost_exw * shipping_pct
import_tax_cost = (cost_exw + shipping_cost) * import_tax_pct  ✅ CORREGIDO
total_cost = cost_exw + shipping_cost + import_tax_cost
```

### Cálculo de MSRP:
```sql
msrp_sale_in = total_cost / (1 - msrp_pct_sale_in)
msrp_sale_out = total_cost / (1 - msrp_pct_sale_out)  ✅ CORREGIDO
```

---

## 📊 FLUJO COMPLETO

```
CatalogItems
  ↓ (trigger: cost_exw o category_id cambia)
msrp_compute_for_item()
  ↓
  - Lee CostSettings (shipping_pct, global_import_tax_pct)
  - Busca ImportTaxRules por categoría (con jerarquía)
  - Busca CategoryMargins por categoría (con jerarquía)
  - Calcula: shipping_cost, import_tax_cost, total_cost
  - Calcula: msrp_sale_in, msrp_sale_out
  ↓
CatalogItemsMSRP (actualizado)
  ↓
ConfiguredProducts (suma roll_msrp_total + bom_total)
  ↓
QuoteLines (snapshot congelado)
```

---

## ✅ VERIFICACIÓN DE REFERENCIAS A TABLAS OLD

**Resultado:** ✅ Todas las referencias usan las tablas correctas:
- `BOMInstances` (mayúsculas) ✅
- `BOMInstanceLines` (mayúsculas) ✅
- No hay referencias a `BomInstances` o `BomInstanceLines` (camelCase) ✅

---

## 🚀 PASOS PARA APLICAR

### Paso 1: Ejecutar Diagnóstico (Opcional)
```sql
-- Ver estado actual
\i database/migrations/20260125_diagnose_cost_engine.sql
```

### Paso 2: Aplicar Corrección Completa
```sql
-- Aplicar todas las correcciones y triggers
\i database/migrations/20260125_fix_cost_engine_complete.sql
```

### Paso 3: Recalcular Todos los Items
```sql
-- Recalcular todos los items con las fórmulas corregidas
\i database/migrations/20260125_recalculate_all_msrp_after_fix.sql
```

---

## 🎯 CRITERIOS DE ACEPTACIÓN

✅ **Cambiar ImportTaxRules de una categoría** → Actualiza `import_tax_cost` y `total_cost` de todos los SKUs en esa categoría  
✅ **Cambiar cost_exw o category_id en CatalogItems** → Recalcula ese SKU en CatalogItemsMSRP  
✅ **Cambiar CategoryMargins** → Recalcula todos los SKUs de esa categoría  
✅ **Cambiar CostSettings.shipping_pct** → Recalcula todos los SKUs de la organización  
✅ **ConfiguredProducts** → Siempre refleja `roll_msrp_total + bom_total = roll_plus_bom_total`  
✅ **No existen referencias a tablas OLD BOM** → Todo usa `BOMInstances` / `BOMInstanceLines`  
✅ **Multi-tenant por organization_id** → Todo es RLS-friendly  

---

## ⚠️ NOTAS IMPORTANTES

1. **Jerarquía de Categorías:**
   - La tabla es `CatalogCategories` (no `Categories`)
   - La columna es `parent_id` (no `parent_category_id`)
   - Si no hay regla en la categoría actual, busca en `parent_id` recursivamente

2. **Performance:**
   - Los triggers recalculan automáticamente, pero pueden ser lentos con muchos items
   - Para cambios masivos, considerar ejecutar `msrp_recompute_for_category` en background

3. **Labor:**
   - Labor NO se calcula en `msrp_compute_for_item` (correcto según modelo de negocio)
   - Labor se aplica después en ConfiguredProducts o QuoteLines

---

**Estado:** ✅ Listo para ejecutar
