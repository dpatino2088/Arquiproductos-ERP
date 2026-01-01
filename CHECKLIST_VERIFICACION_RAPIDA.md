# ✅ Checklist de Verificación Rápida

## Estado Actual: Migraciones Aplicadas ✅

- [x] Migración 212: Fix Quote Approved Trigger
- [x] Migración 213: Deshabilitar Auto-delete
- [x] Migración 214: Fix SalesOrders Default
- [x] Migración 215: Fix Engineering Rules Function
- [x] Migración 216: Reaplicar Rules a BOMs Existentes
- [x] Migración 218: Fix Missing bom_template_id
- [x] Migración 219: Reaplicar Rules Después de Template Fix

## ⚠️ Problema Pendiente: cut_length_mm = NULL

### Verificación Inmediata

1. **Ejecutar diagnóstico:**
   ```sql
   -- En Supabase SQL Editor
   -- Archivo: TEST_SINGLE_BOM_INSTANCE.sql
   ```

2. **Revisar resultados:**
   - ¿El BomInstance tiene `bom_template_id`?
   - ¿El template tiene engineering rules?
   - ¿Hay dimensiones (`width_m`, `height_m`)?
   - ¿La función se ejecuta sin errores?

3. **Si todo está bien pero no calcula:**
   - Verificar logs de PostgreSQL
   - Revisar función `normalize_component_role`
   - Verificar que `BOMComponents` tienen `affects_role` y `cut_axis` configurados

## 📊 Métricas Actuales

- **SalesOrders con template:** 45/57 (79%)
- **SalesOrders sin template:** 12/57 (21%)
- **cut_length_mm calculados:** 0/88 (0%) ❌

## 🎯 Próximo Paso

**EJECUTAR:** `TEST_SINGLE_BOM_INSTANCE.sql` y compartir los logs completos.




