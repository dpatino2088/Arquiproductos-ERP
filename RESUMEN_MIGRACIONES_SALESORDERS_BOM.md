# Resumen: Fixes de SalesOrders y Cálculo de BOM

**Fecha:** Diciembre 2024  
**Estado:** En progreso - Migraciones aplicadas, pendiente verificación completa

---

## 📋 Problema Inicial

1. **SalesOrders no aparecían en la UI** - Aunque existían en la base de datos
2. **BOMs no calculaban cut dimensions** - Los campos `cut_length_mm`, `cut_width_mm`, `cut_height_mm` estaban NULL
3. **Inconsistencias en nombres de tablas** - Uso de `SaleOrders` vs `SalesOrders` (pluralización)

---

## ✅ Migraciones Aplicadas

### **Migración 212: Fix Quote Approved Trigger**
**Archivo:** `database/migrations/212_fix_quote_approved_trigger_sale_order_creation.sql`

**Cambios:**
- Corregidos todos los nombres de tablas de `SaleOrders`/`SaleOrderLines` a `SalesOrders`/`SalesOrderLines`
- Mejorado el trigger que crea SalesOrders cuando un Quote se aprueba
- Agregado manejo de errores y fallback para generación de números

**Estado:** ✅ Aplicada

---

### **Migración 213: Deshabilitar Auto-delete de SalesOrders**
**Archivo:** `database/migrations/213_disable_salesorder_autodelete.sql`

**Cambios:**
- Eliminados triggers que hacían soft-delete automático de SalesOrders
- Agregado comentario a la tabla enfatizando que SalesOrders son documentos inmutables

**Estado:** ✅ Aplicada

---

### **Migración 214: Fix SalesOrders Default y Verificación BOM**
**Archivo:** `database/migrations/214_fix_salesorders_and_bom_compute.sql`

**Cambios:**
- Establecido `deleted = false` como default en `SalesOrders.deleted`
- Verificación de existencia de función `apply_engineering_rules_to_bom_instance`

**Estado:** ✅ Aplicada

---

### **Migración 215: Fix Engineering Rules Function**
**Archivo:** `database/migrations/215_fix_engineering_rules_function.sql`

**Cambios:**
- **CRÍTICO:** Corregida la función `apply_engineering_rules_to_bom_instance`
- Ahora obtiene engineering rules directamente de `BOMComponents` basado en `bom_template_id`
- Calcula correctamente dimensiones base para `tube` y `bottom_rail_profile` desde `width_m` de QuoteLines
- Maneja casos donde `bom_template_id` es NULL buscando template por `product_type_id`
- Mejora en el UPDATE para establecer valores correctamente

**Estado:** ✅ Aplicada

---

### **Migración 216: Reaplicar Engineering Rules a BOMs Existentes**
**Archivo:** `database/migrations/216_reapply_engineering_rules_existing_boms.sql`

**Cambios:**
- Reaplica engineering rules a todos los BomInstances existentes que tienen `cut_length_mm` NULL
- Procesa en lotes para evitar timeouts

**Estado:** ✅ Aplicada (pero resultados muestran 0% calculado - ver sección de problemas)

---

### **Migración 218: Fix Missing bom_template_id**
**Archivo:** `database/migrations/218_fix_missing_bom_template_ids.sql`

**Cambios:**
- Pobla `bom_template_id` en BomInstances que lo tienen NULL
- Busca template usando `product_type_id` desde `SalesOrderLines`
- Prioriza templates de la misma organización

**Estado:** ✅ Aplicada (12 BomInstances aún sin template - posiblemente sin product_type_id)

---

### **Migración 219: Reaplicar Rules Después de Fix Template**
**Archivo:** `database/migrations/219_reapply_engineering_rules_after_template_fix.sql`

**Cambios:**
- Reaplica engineering rules después de que los templates fueron asignados
- Muestra resumen con porcentaje de líneas calculadas

**Estado:** ✅ Aplicada (pero resultados muestran 0% calculado - ver sección de problemas)

---

## 🔍 Problemas Identificados

### **Problema Principal: cut_length_mm sigue siendo NULL**

**Diagnóstico:**
- Todos los BomInstances tienen `bom_template_id = NULL` inicialmente
- Migración 218 corrigió algunos (45 con template, 12 sin)
- Migración 219 ejecutó la función pero resultados muestran 0% calculado

**Posibles causas:**
1. La función `apply_engineering_rules_to_bom_instance` no se está ejecutando correctamente
2. Faltan dimensiones (`width_m`, `height_m`) en QuoteLines/SalesOrderLines
3. Los BOMTemplates no tienen engineering rules configuradas
4. Hay un error silencioso en la función que no se está reportando

---

## 🛠️ Scripts de Diagnóstico Creados

### **DIAGNOSE_WHY_NO_CUTS.sql**
Script completo para diagnosticar por qué `cut_length_mm` es NULL. Verifica:
- Existencia de función
- BomInstances y sus datos
- Templates y engineering rules
- Dimensiones disponibles

### **TEST_SINGLE_BOM_INSTANCE.sql**
Script para probar la función en un solo BomInstance con logging detallado:
- Muestra estado antes y después
- Ejecuta la función manualmente
- Reporta errores si los hay

### **QUICK_VERIFY_ALL_MIGRATIONS.sql**
Verificación rápida de las migraciones 214, 215, 216:
- Default de `SalesOrders.deleted`
- Existencia de función
- Conteo de `cut_length_mm` calculados vs NULL

---

## 📊 Estado Actual de la Base de Datos

### **SalesOrders:**
- ✅ Default `deleted = false` establecido
- ✅ Triggers de auto-delete deshabilitados
- ✅ SalesOrders aparecen en la UI (después de fix en frontend)

### **BomInstances:**
- ⚠️ 45 tienen `bom_template_id` asignado
- ⚠️ 12 aún sin `bom_template_id` (posiblemente sin `product_type_id`)
- ❌ 0% de `cut_length_mm` calculados (88 líneas con NULL: 44 tube + 44 bottom_rail_profile)

---

## 🔧 Cambios en Frontend

### **OrganizationContext.tsx**
- Mejorado logging de errores para diagnóstico
- Detección específica de errores de red/fetch

### **SaleOrders.tsx**
- Agregados guards para prevenir queries antes de que organization esté cargada
- Debug logging agregado

---

## 📝 Próximos Pasos Recomendados

### **1. Diagnóstico Inmediato (URGENTE)**
Ejecutar `TEST_SINGLE_BOM_INSTANCE.sql` en Supabase para identificar exactamente por qué la función no calcula:

```sql
-- Ejecutar en Supabase SQL Editor
-- Este script mostrará logs detallados de qué está fallando
```

**Qué buscar en los logs:**
- ¿El BomInstance tiene `bom_template_id`?
- ¿El template tiene engineering rules?
- ¿Hay dimensiones (`width_m`, `height_m`) disponibles?
- ¿La función se ejecuta sin errores?
- ¿Los valores se actualizan después de ejecutar?

### **2. Verificar Engineering Rules en Templates**
```sql
-- Verificar que los BOMTemplates tienen engineering rules
SELECT 
    bt.name,
    bt.id,
    COUNT(bc.id) as rules_count
FROM "BOMTemplates" bt
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
    AND bc.deleted = false
    AND bc.affects_role IS NOT NULL
    AND bc.cut_axis IS NOT NULL
    AND bc.cut_axis != 'none'
WHERE bt.deleted = false
GROUP BY bt.id, bt.name
ORDER BY bt.name;
```

### **3. Verificar Dimensiones en QuoteLines**
```sql
-- Verificar que las dimensiones están disponibles
SELECT 
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE width_m IS NULL OR width_m = 0) as missing_width,
    COUNT(*) FILTER (WHERE height_m IS NULL OR height_m = 0) as missing_height
FROM "QuoteLines"
WHERE deleted = false;
```

### **4. Si la Función Tiene Errores**
- Revisar logs de PostgreSQL (si están habilitados)
- Ejecutar la función manualmente con `RAISE NOTICE` adicionales
- Verificar que `normalize_component_role` existe y funciona correctamente

### **5. Si Faltan Templates**
Para los 12 BomInstances sin `bom_template_id`:
- Verificar si tienen `product_type_id` en SalesOrderLines
- Crear templates si no existen
- O asignar templates manualmente

---

## 🎯 Objetivos Finales

1. ✅ **SalesOrders aparecen en UI** - COMPLETADO
2. ❌ **BOMs calculan cut_length_mm correctamente** - PENDIENTE
3. ✅ **Nombres de tablas consistentes** - COMPLETADO
4. ✅ **SalesOrders no se auto-eliminan** - COMPLETADO

---

## 📁 Archivos Importantes

### **Migraciones:**
- `212_fix_quote_approved_trigger_sale_order_creation.sql`
- `213_disable_salesorder_autodelete.sql`
- `214_fix_salesorders_and_bom_compute.sql`
- `215_fix_engineering_rules_function.sql` ⚠️ **CRÍTICO**
- `216_reapply_engineering_rules_existing_boms.sql`
- `218_fix_missing_bom_template_ids.sql`
- `219_reapply_engineering_rules_after_template_fix.sql`

### **Scripts de Diagnóstico:**
- `DIAGNOSE_WHY_NO_CUTS.sql`
- `TEST_SINGLE_BOM_INSTANCE.sql` ⚠️ **USAR ESTE PRIMERO**
- `QUICK_VERIFY_ALL_MIGRATIONS.sql`

### **Frontend:**
- `src/context/OrganizationContext.tsx`
- `src/pages/sales/SaleOrders.tsx`

---

## ⚠️ Notas Importantes

1. **NO modificar triggers** a menos que sea absolutamente necesario
2. **Todas las migraciones SQL deben estar en archivos nuevos** (no modificar existentes)
3. **Los logs deben ser dev-friendly** - usar `RAISE NOTICE` y `RAISE WARNING`
4. **Preferir patches mínimos** - no reescribir funciones completas si no es necesario

---

## 🚀 Cómo Continuar

1. **Ejecutar diagnóstico:** `TEST_SINGLE_BOM_INSTANCE.sql`
2. **Revisar logs** para identificar el problema exacto
3. **Aplicar fix** basado en los resultados del diagnóstico
4. **Verificar** con `QUICK_VERIFY_ALL_MIGRATIONS.sql`
5. **Probar en UI** que los cut_length_mm aparecen correctamente

---

## 📞 Contacto

Si hay dudas sobre alguna migración o script, revisar los comentarios dentro de cada archivo SQL para más detalles.




