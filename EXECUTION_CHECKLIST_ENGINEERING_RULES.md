# ✅ Engineering Rules Implementation - Execution Checklist

## 📋 Status Check

Verifica que cada paso esté completo antes de continuar:

### ✅ Paso 1: Inspección de Schema
- [ ] Ejecutado: `INSPECT_SCHEMA_FOR_ENGINEERING_RULES.sql`
- [ ] Revisados los resultados para entender la estructura actual

### ✅ Paso 2: Crear/Corregir EngineeringRules Table
- [ ] Ejecutado: `FIX_ENGINEERING_RULES_NULLABLE_COLUMNS.sql` (si había error)
- [ ] O ejecutado: `CREATE_ENGINEERING_RULES_TABLE.sql` (si la tabla no existía)
- [ ] Verificado: Columnas agregadas correctamente
- [ ] Si había filas existentes: Actualizadas con valores válidos
- [ ] Si la tabla estaba vacía: Columnas seteadas a NOT NULL

### ⏭️ Paso 3: Crear Función de Ajustes (SIGUIENTE)
- [ ] **EJECUTAR AHORA:** `CREATE_RESOLVE_DIMENSIONAL_ADJUSTMENTS_FUNCTION.sql`
- [ ] Verificar: Función creada sin errores

### ⏭️ Paso 4: Integrar en Generación de BOM
- [ ] Ejecutar: `INTEGRATE_ENGINEERING_RULES_INTO_BOM.sql`
- [ ] Verificar: Función `generate_bom_for_manufacturing_order` actualizada
- [ ] Verificar: Columnas `cut_length_mm`, `cut_width_mm`, `cut_height_mm`, `calc_notes` agregadas a `BomInstanceLines`

### ✅ Paso 5: Frontend (Ya actualizado)
- [x] `SummaryTab.tsx` actualizado con mejor manejo de errores
- [x] Label "Material Review" para status DRAFT
- [x] Loading states mejorados

## 🚀 Próximo Paso

**Ejecuta ahora:**
```sql
-- CREATE_RESOLVE_DIMENSIONAL_ADJUSTMENTS_FUNCTION.sql
```

Esta función es necesaria antes de ejecutar `INTEGRATE_ENGINEERING_RULES_INTO_BOM.sql` porque la función de generación de BOM la llama.

## 🧪 Verificación Rápida

Después de ejecutar cada script, verifica:

```sql
-- Verificar función existe
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'resolve_dimensional_adjustments';

-- Verificar columnas en BomInstanceLines
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'BomInstanceLines'
AND column_name IN ('cut_length_mm', 'cut_width_mm', 'cut_height_mm', 'calc_notes')
ORDER BY column_name;
```

## 📝 Notas

- Si `EngineeringRules` está vacía, los ajustes simplemente no se aplicarán (comportamiento normal)
- La función de generación de BOM seguirá funcionando sin reglas de ingeniería
- Las reglas se aplican solo cuando existen y coinciden con el product_type_id y target_role






