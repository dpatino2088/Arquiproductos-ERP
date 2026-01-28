# ✅ FIX: BOM Template Matching

**Fecha:** 2026-01-20  
**Problema:** El matching de BOMTemplate no estaba siguiendo el flujo correcto según el esquema

---

## 🔍 PROBLEMA IDENTIFICADO

El matching de BOMTemplate debe seguir este flujo:

1. **ProductType** (primer filtro) - `product_type_id`
2. **Color** (segundo filtro) - `color` (hardware_color)
3. **Selecciones SKU** del usuario (motor, drive, headbox, etc.) vs **Slots del BOMTemplate**
4. **El que más coincidencias tenga, gana**

El código anterior estaba usando `build_quote_line_config` y `select_best_bom_template` que comparaban metadata, pero no comparaban directamente:
- Las columnas de BOMTemplates (`product_type_id`, `color`, etc.)
- Las selecciones SKU del usuario con los slots del template

---

## ✅ SOLUCIÓN IMPLEMENTADA

### **1. Nueva función: `select_best_bom_template_for_quote_line`**

```sql
CREATE OR REPLACE FUNCTION "public"."select_best_bom_template_for_quote_line"(
  "p_org_id" uuid,
  "p_product_type_id" uuid,
  "p_quote_line_id" uuid
) RETURNS uuid
```

**Flujo de matching:**

1. **Primer filtro**: `product_type_id`
   ```sql
   WHERE bt.product_type_id = p_product_type_id
   ```

2. **Segundo filtro**: `color` (hardware_color)
   ```sql
   WHERE (
     v_color IS NULL 
     OR bt.color IS NULL 
     OR LOWER(TRIM(bt.color)) = LOWER(TRIM(v_color))
   )
   ```

3. **Obtener selecciones SKU del usuario:**
   ```sql
   SELECT ARRAY_AGG(DISTINCT qlc.component_role) 
   FROM public."QuoteLineComponents" qlc
   WHERE qlc.kind = 'selection' -- Solo selecciones SKU directas
   ```

4. **Comparar con slots del template:**
   ```sql
   SELECT COUNT(*) 
   FROM public."BOMTemplateSlots" slots
   WHERE slots.item_role = ANY(v_user_roles)
   ```

5. **El que más coincidencias tenga, gana:**
   ```sql
   ORDER BY 
     v_match_score DESC,  -- Más coincidencias primero
     priority DESC,
     updated_at DESC
   ```

### **2. Actualizar `generate_bom_from_slots`**

Ahora usa la nueva función de matching:
```sql
v_template_id := public.select_best_bom_template_for_quote_line(
  p_org_id, 
  p_product_type_id, 
  p_quote_line_id
);
```

---

## 📋 CAMBIOS EN ARCHIVOS

### **SQL:**
- ✅ `database/migrations/20260120_fix_bom_template_matching.sql`
  - Nueva función `select_best_bom_template_for_quote_line`
  - Actualizada `generate_bom_from_slots` para usar la nueva función

### **Frontend (ya estaba correcto):**
- ✅ `src/pages/sales/QuoteNew.tsx`
  - Ya guarda selecciones SKU con `kind='selection'`
  - Ya usa `generate_bom_from_slots`

---

## 🧪 PRUEBAS

### **Test 1: Matching por ProductType y Color**
1. Crear Quote → Add Line → Configurar roller-shade con hardware_color='White'
2. Verificar que el template seleccionado tenga `product_type_id` correcto y `color='White'`

### **Test 2: Matching por selecciones SKU**
1. Configurar producto con motor, drive, headbox
2. Verificar que el template seleccionado tenga slots que coincidan con estos roles
3. El template con más coincidencias debe ganar

### **Test 3: Fallback sin coincidencias**
1. Si no hay coincidencias perfectas, debe seleccionar el primer template que coincida con product_type + color

---

## 🚀 EJECUTAR MIGRACIÓN

```sql
-- En Supabase SQL Editor
-- Ejecutar: database/migrations/20260120_fix_bom_template_matching.sql
```

---

## 📝 NOTAS

- ✅ Usa columnas directas de BOMTemplates (`product_type_id`, `color`), no metadata
- ✅ Compara selecciones SKU del usuario con slots del template
- ✅ El que más coincidencias tenga, gana
- ✅ Fallback si no hay coincidencias perfectas
- ✅ No rompe código existente

---

## 🔄 SIGUIENTE PASO

1. **Ejecutar migración SQL**
2. **Probar flujo completo**: Crear Quote → Configurar → Verificar que el template correcto se seleccione
3. **Verificar en BD** que el `bom_template_id` en `BOMInstances` sea el correcto
