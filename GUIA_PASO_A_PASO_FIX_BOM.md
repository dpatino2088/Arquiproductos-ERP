# Guía Paso a Paso: Corregir QuoteLineComponents Faltantes

## 📋 Resumen del Problema
- Los `QuoteLines` no tienen `product_type_id`
- Sin `product_type_id`, no se pueden generar `QuoteLineComponents`
- Sin `QuoteLineComponents`, no se crean `BomInstanceLines`
- Sin `BomInstanceLines`, el Manufacturing Order muestra 0 materiales

## 🔧 Solución: Ejecutar Script `FIX_MISSING_PRODUCT_TYPE_AND_GENERATE_BOM.sql`

### **PASO 1: Ejecutar el Script Completo**

1. Abre Supabase SQL Editor
2. Abre el archivo `FIX_MISSING_PRODUCT_TYPE_AND_GENERATE_BOM.sql`
3. **Ejecuta TODO el script de una vez** (Ctrl/Cmd + Enter o botón "Run")

### **PASO 2: Revisar los Resultados**

El script tiene 6 partes. Después de ejecutarlo, verás múltiples resultados. Aquí te explico qué buscar en cada uno:

---

## 📊 **RESULTADO 1: PASO 1 - Diagnosticar QuoteLines sin product_type_id**

**Qué buscar:**
- Una tabla con columnas: `quote_line_id`, `catalog_item_id`, `product_type_id`, `item_name`, `sku`, `suggested_product_type_id`, `suggested_product_type_name`

**Qué significa:**
- Si `suggested_product_type_id` tiene un valor → ✅ Podemos usar ese valor
- Si `suggested_product_type_id` es NULL → ❌ No hay relación en `CatalogItemProductTypes`

**Ejemplo de resultado esperado:**
```
quote_line_id | catalog_item_id | product_type_id | suggested_product_type_id | suggested_product_type_name
--------------|-----------------|-----------------|---------------------------|---------------------------
abc-123       | xyz-789        | NULL            | def-456                   | Roller Shade
```

---

## 📊 **RESULTADO 2: PASO 2 - Actualizar QuoteLines**

**Qué buscar:**
- **NO verás una tabla**, sino **mensajes en la consola/logs**
- Busca en la pestaña "Logs" o en los mensajes NOTICE del script

**Qué significa:**
- Mensajes como: `✅ Updated QuoteLine abc-123 with product_type_id def-456`
- `✅ Updated 2 QuoteLines with product_type_id`

**Si no ves estos mensajes:**
- Ve a la pestaña "Logs" en Supabase
- O ejecuta solo el bloque DO $$ del PASO 2

---

## 📊 **RESULTADO 3: PASO 3 - Verificar BOMTemplates**

**Qué buscar:**
- Una tabla con columnas: `quote_line_id`, `product_type_id`, `product_type_name`, `bom_template_id`, `bom_template_name`, `active`, `deleted`, `bom_components_count`

**Qué significa:**
- Si `bom_template_id` tiene un valor → ✅ Existe BOMTemplate
- Si `bom_components_count` > 0 → ✅ Tiene componentes
- Si `bom_template_id` es NULL → ❌ No hay BOMTemplate para ese product_type_id

**Ejemplo de resultado esperado:**
```
quote_line_id | product_type_name | bom_template_id | bom_template_name | active | bom_components_count
--------------|-------------------|-----------------|------------------|--------|----------------------
abc-123       | Roller Shade      | tpl-001         | Default BOM      | true   | 15
```

---

## 📊 **RESULTADO 4: PASO 4 - Generar QuoteLineComponents**

**Qué buscar:**
- **NO verás una tabla**, sino **mensajes en la consola/logs**
- Busca en la pestaña "Logs" o en los mensajes NOTICE/WARNING del script

**Qué significa:**
- `✅ Generated BOM for QuoteLine abc-123: 15 components` → ✅ Éxito
- `⚠️ No BOMTemplate found for QuoteLine...` → ❌ Falta BOMTemplate
- `❌ Error generating BOM for QuoteLine...` → ❌ Error en la función

**Si no ves estos mensajes:**
- Ve a la pestaña "Logs" en Supabase
- O ejecuta solo el bloque DO $$ del PASO 4

---

## 📊 **RESULTADO 5: PASO 5 - Verificar QuoteLineComponents Creados**

**Qué buscar:**
- Una tabla con columnas: `quote_line_id`, `qlc_id`, `source`, `component_role`, `catalog_item_id`, `qty`, `uom`, `sku`, `item_name`

**Qué significa:**
- Si hay filas con `source = 'configured_component'` → ✅ Se crearon correctamente
- Si la tabla está vacía → ❌ No se crearon

**Ejemplo de resultado esperado:**
```
quote_line_id | qlc_id | source                | component_role | qty  | uom | sku
--------------|--------|-----------------------|----------------|------|-----|-----
abc-123       | qlc-1  | configured_component  | fabric         | 2.5  | mts | FAB-001
abc-123       | qlc-2  | configured_component  | tube           | 2.0  | mts | RTU-42
```

---

## 📊 **RESULTADO 6: PASO 6 - Resumen Final**

**Qué buscar:**
- Una tabla con una fila: `RESUMEN FINAL`
- Columnas: `total_quote_lines`, `quote_lines_with_product_type`, `configured_components_created`

**Qué significa:**
- `quote_lines_with_product_type` = 2 → ✅ Los QuoteLines tienen product_type_id
- `configured_components_created` > 0 → ✅ Se crearon QuoteLineComponents
- `configured_components_created` = 0 → ❌ Aún no se crearon (ver PASO 4)

---

## 🚨 **Cómo Ver los Mensajes NOTICE/WARNING**

Si no ves los mensajes del PASO 2 y PASO 4:

1. **Opción 1: Ver Logs en Supabase**
   - Ve a la pestaña "Logs" en el panel izquierdo de Supabase
   - Busca mensajes que empiecen con `🔧`, `✅`, `⚠️`, `❌`

2. **Opción 2: Ejecutar Pasos Individualmente**
   - Copia solo el bloque `DO $$ ... END $$;` del PASO 2
   - Ejecútalo por separado
   - Luego ejecuta el bloque del PASO 4 por separado

3. **Opción 3: Usar RAISE NOTICE en una Query**
   - Los mensajes aparecen en la consola del navegador (F12 → Console)
   - O en la pestaña "Logs" de Supabase

---

## ✅ **Checklist de Verificación**

Después de ejecutar el script, verifica:

- [ ] PASO 1: ¿Hay `suggested_product_type_id`?
- [ ] PASO 2: ¿Se actualizaron los QuoteLines? (ver logs)
- [ ] PASO 3: ¿Existen BOMTemplates? ¿Tienen componentes?
- [ ] PASO 4: ¿Se generaron QuoteLineComponents? (ver logs)
- [ ] PASO 5: ¿Hay filas en la tabla de QuoteLineComponents?
- [ ] PASO 6: ¿`configured_components_created` > 0?

---

## 🔍 **Si Algo Falla**

### **Problema: No hay `suggested_product_type_id` en PASO 1**
**Solución:** Necesitamos crear la relación `CatalogItemProductTypes` manualmente

### **Problema: No hay BOMTemplate en PASO 3**
**Solución:** Necesitamos crear un BOMTemplate para ese `product_type_id`

### **Problema: BOMTemplate no tiene componentes en PASO 3**
**Solución:** Necesitamos agregar BOMComponents al BOMTemplate

### **Problema: Error en PASO 4 al generar BOM**
**Solución:** Revisar el mensaje de error específico y corregir

---

## 📝 **Próximos Pasos**

1. Ejecuta el script completo
2. Comparte los resultados de TODOS los pasos (especialmente PASO 3 y los mensajes del PASO 4)
3. Con esa información, prepararé la solución específica para tu caso








