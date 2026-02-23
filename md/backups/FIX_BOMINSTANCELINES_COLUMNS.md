# ✅ FIX: Agregar organization_id y deleted a BOMInstanceLines

**Fecha:** 2026-01-20  
**Problema:** Error "column 'organization_id' of relation 'BOMInstanceLines' does not exist"

---

## 🔍 PROBLEMA IDENTIFICADO

La función `generate_bom_from_slots()` está intentando insertar `organization_id` y `deleted` en `BOMInstanceLines`, pero estas columnas no existen en el esquema actual.

---

## ✅ SOLUCIÓN IMPLEMENTADA

### **1. SQL para agregar columnas**

**Archivo:** `database/migrations/20260120_add_columns_to_bominstancelines.sql`

Este script:
1. ✅ Agrega `organization_id` (uuid, NOT NULL)
2. ✅ Pobla `organization_id` desde `BOMInstances`
3. ✅ Agrega FK constraint a `Organizations`
4. ✅ Agrega `deleted` (boolean, default false, NOT NULL)
5. ✅ Crea índice para performance
6. ✅ Verifica que las columnas se agregaron correctamente

### **2. Función corregida**

**Archivos actualizados:**
- ✅ `database/migrations/20260120_fix_bom_template_matching.sql`
  - Usa `unit_cost_exw` (no `unit_cost`)
  - Mantiene `organization_id` y `deleted` en INSERTs
- ✅ `backups/FIX_GENERATE_BOM_FROM_SLOTS_REMOVE_DELETED.sql`
  - Mismas correcciones

---

## 🚀 EJECUTAR SQL (EN ORDEN)

### **Paso 1: Agregar columnas a BOMInstanceLines**
```sql
-- Ejecutar: database/migrations/20260120_add_columns_to_bominstancelines.sql
```

### **Paso 2: Actualizar función (sin slots.deleted)**
```sql
-- Ejecutar: backups/FIX_GENERATE_BOM_FROM_SLOTS_REMOVE_DELETED.sql
```

### **Paso 3: Convertir a SECURITY DEFINER (si no lo es)**
```sql
-- Ejecutar: backups/FIX_GENERATE_BOM_FROM_SLOTS_SECURITY_DEFINER.sql
-- Paso 1: Verificar si ya es SECURITY DEFINER
-- Si is_security_definer = false, ejecutar pasos 2-4
```

---

## 🧪 PRUEBA

1. **Ejecutar SQLs en orden**
2. **Reiniciar dev server:**
   ```bash
   # Ctrl+C y luego npm run dev
   ```
3. **Hard refresh:** `Cmd+Shift+R`
4. **Probar crear Quote Line:**
   - Abrir `/sales/quotes/new`
   - Click "Add Line"
   - Configurar producto "roller-shade"
   - Click "Add to Quote"

5. **Verificar en consola:**
   - ✅ Debe aparecer: `🔧 RPC generate_bom_from_slots args: {...}`
   - ✅ Si funciona: `✅ RPC generate_bom_from_slots OK: <id>`
   - ✅ Si hay error: `❌ RPC generate_bom_from_slots failed:` con detalles completos

6. **Verificar en BD:**
   ```sql
   SELECT * FROM public."BOMInstanceLines" 
   WHERE bom_instance_id IN (
     SELECT id FROM public."BOMInstances" 
     ORDER BY created_at DESC LIMIT 1
   );
   ```
   - Debe tener `organization_id` y `deleted`

---

## 📋 VERIFICACIÓN

- ✅ SQL para agregar columnas creado
- ✅ Función actualizada para usar `unit_cost_exw`
- ✅ Función mantiene `organization_id` y `deleted` en INSERTs
- ✅ Removida referencia a `slots.deleted` (BOMTemplateSlots no tiene esa columna)

**Después de ejecutar los SQLs, el error "column 'organization_id' does not exist" debería desaparecer.**
