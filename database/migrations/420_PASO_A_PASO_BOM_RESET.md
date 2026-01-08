# 🚀 Guía Paso a Paso: BOM Reset y SO-Driven BOM

## 📋 Resumen
Esta guía te llevará paso a paso para implementar el sistema de BOM reset y BOM driven por Sales Order.

---

## ✅ PASO 1: Ejecutar Migración 419 (Funciones Helper)

**Archivo:** `database/migrations/419_bom_reset_and_helpers.sql`

**Qué hace:**
- Crea función `resolve_bom_template_id_for_sale_order_line()` - Resuelve el BOM template correcto
- Crea función `resolve_selected_fabric_catalog_item_id()` - Resuelve el fabric seleccionado
- Crea función `reset_and_generate_bom_for_manufacturing_order()` - Resetea y regenera BOM

**Cómo ejecutar:**
1. Abre Supabase SQL Editor
2. Copia TODO el contenido de `419_bom_reset_and_helpers.sql`
3. Pega en el editor
4. Haz clic en "Run" o presiona `Ctrl+Enter`
5. Verifica que no haya errores (debería mostrar "Success")

**Verificación:**
```sql
-- Verificar que las funciones existen
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN (
    'resolve_bom_template_id_for_sale_order_line',
    'resolve_selected_fabric_catalog_item_id',
    'reset_and_generate_bom_for_manufacturing_order'
);
-- Debería devolver 3 filas
```

---

## ✅ PASO 2: Actualizar generate_bom_for_manufacturing_order

**Archivo:** `database/migrations/405_fix_bom_instances_rls_and_return_counts.sql`

**Qué hace:**
- Actualiza la función principal para usar los helpers
- Implementa resolución de template usando helper
- Implementa resolución de fabric usando helper (SO-driven)

**Cómo ejecutar:**
1. Abre Supabase SQL Editor
2. Busca la función `generate_bom_for_manufacturing_order` en el archivo
3. Copia TODO el `CREATE OR REPLACE FUNCTION generate_bom_for_manufacturing_order(...)` completo
4. Pega en el editor
5. Haz clic en "Run"
6. Verifica que no haya errores

**⚠️ IMPORTANTE:** 
- Asegúrate de copiar la función COMPLETA (desde `CREATE OR REPLACE FUNCTION` hasta el `$$;` final)
- El archivo tiene ~1553 líneas, la función es grande

**Verificación:**
```sql
-- Verificar que la función fue actualizada
SELECT routine_name, routine_definition 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'generate_bom_for_manufacturing_order';
-- Debería mostrar la función actualizada
```

---

## ✅ PASO 3: Probar las Funciones Helper

**Archivo:** `database/migrations/QUERY_VERIFY_BOM_RESET_AND_SO_DRIVEN.sql`

**Qué hace:**
- Prueba que las funciones helper funcionan correctamente
- Muestra resultados de resolución de template y fabric

**Cómo ejecutar:**
1. Abre Supabase SQL Editor
2. Copia el **Query 0** del archivo (líneas 11-35 aproximadamente)
3. Pega en el editor
4. Haz clic en "Run"
5. Verifica que devuelva resultados (no errores)

**Query a ejecutar:**
```sql
-- Test resolve_bom_template_id_for_sale_order_line
SELECT 
    sol.id AS sale_order_line_id,
    sol.line_number,
    sol.quote_line_id,
    public.resolve_bom_template_id_for_sale_order_line(sol.id) AS resolved_bom_template_id,
    bt.name AS resolved_template_name
FROM "SalesOrderLines" sol
LEFT JOIN "BOMTemplates" bt ON bt.id = public.resolve_bom_template_id_for_sale_order_line(sol.id) AND bt.deleted = false
WHERE sol.deleted = false
LIMIT 5;

-- Test resolve_selected_fabric_catalog_item_id
SELECT 
    sol.id AS sale_order_line_id,
    sol.line_number,
    public.resolve_selected_fabric_catalog_item_id(sol.id) AS selected_fabric_catalog_item_id,
    ci.sku AS selected_fabric_sku,
    ci.item_name AS selected_fabric_name
FROM "SalesOrderLines" sol
LEFT JOIN "CatalogItems" ci ON ci.id = public.resolve_selected_fabric_catalog_item_id(sol.id) AND ci.deleted = false
WHERE sol.deleted = false
LIMIT 5;
```

**Resultado esperado:**
- Debería mostrar `sale_order_line_id`, `resolved_bom_template_id`, y `resolved_template_name` (puede ser NULL si no hay template)
- Debería mostrar `selected_fabric_catalog_item_id` y `selected_fabric_sku` (puede ser NULL si no hay fabric seleccionado)

---

## ✅ PASO 4: Probar reset_and_generate_bom_for_manufacturing_order

**Qué hace:**
- Prueba la función que resetea y regenera BOM

**Cómo ejecutar:**
1. Primero, obtén un `manufacturing_order_id` real:
```sql
-- Obtener un Manufacturing Order ID
SELECT id, manufacturing_order_no, sale_order_id, status
FROM "ManufacturingOrders"
WHERE deleted = false
LIMIT 5;
```

2. Usa uno de esos IDs para probar la función:
```sql
-- Reemplaza 'TU-MANUFACTURING-ORDER-ID-AQUI' con un ID real del paso anterior
SELECT public.reset_and_generate_bom_for_manufacturing_order('TU-MANUFACTURING-ORDER-ID-AQUI'::uuid);
```

**Resultado esperado:**
- Debería devolver un JSON con:
  - `ok: true`
  - `deleted_instances: <número>`
  - `deleted_lines: <número>`
  - `new_bom_instance_id: <uuid>`
  - `new_lines_count: <número>`

**⚠️ ADVERTENCIA:** Esta función BORRA (soft-delete) los BOMs existentes y crea nuevos. Úsala solo en testing o cuando quieras regenerar.

---

## ✅ PASO 5: Verificar BOM Template Resolution (Query 1)

**Archivo:** `database/migrations/QUERY_VERIFY_BOM_RESET_AND_SO_DRIVEN.sql`

**Qué hace:**
- Valida que el BOM template se resuelve correctamente para cada SalesOrderLine

**Cómo ejecutar:**
1. Abre Supabase SQL Editor
2. Copia el **Query 1** del archivo (líneas 37-50 aproximadamente)
3. Pega en el editor
4. Haz clic en "Run"

**Resultado esperado:**
- Debería mostrar para cada `sale_order_line_id`:
  - `quote_line_bom_template_id` (puede ser NULL)
  - `resolved_bom_template_id` (debería tener valor si hay template)
  - `resolved_template_name` (nombre del template)

---

## ✅ PASO 6: Verificar Fabric Selection (Query 2)

**Archivo:** `database/migrations/QUERY_VERIFY_BOM_RESET_AND_SO_DRIVEN.sql`

**Qué hace:**
- Compara el fabric seleccionado en SO/QuoteLine vs el fabric en el BOM generado

**Cómo ejecutar:**
1. Abre Supabase SQL Editor
2. Copia el **Query 2** del archivo (líneas 52-95 aproximadamente)
3. Pega en el editor
4. Haz clic en "Run"

**Resultado esperado:**
- Debería mostrar:
  - `quote_line_collection` y `quote_line_variant` (del QuoteLine)
  - `selected_fabric_sku` (del helper)
  - `bom_fabric_sku` (del BOM generado)
  - `match_status`: 
    - `✅ MATCH` si coinciden
    - `⚠️ NO BOM FABRIC` si no hay fabric en BOM
    - `⚠️ NO SELECTION` si no hay selección
    - `❌ MISMATCH` si no coinciden

---

## ✅ PASO 7: Verificar UOM Normalization (Query 3)

**Archivo:** `database/migrations/QUERY_VERIFY_BOM_RESET_AND_SO_DRIVEN.sql`

**Qué hace:**
- Verifica que todos los UOMs estén normalizados (m, m2, ea)

**Cómo ejecutar:**
1. Abre Supabase SQL Editor
2. Copia el **Query 3** del archivo (líneas 97-120 aproximadamente)
3. Pega en el editor
4. Haz clic en "Run"

**Resultado esperado:**
- Si hay UOMs no normalizados, los mostrará con:
  - `uom_raw`: el UOM original (ft, pcs, set, etc.)
  - `uom_canonical`: el UOM normalizado (m, m2, ea)
  - `uom_status`: `⚠️ NEEDS NORMALIZATION` o `❌ INVALID`

**Si hay UOMs no normalizados:**
- Ejecuta la migración 418: `418_normalize_existing_bom_uom.sql`

---

## ✅ PASO 8: Probar desde la UI

**Qué hace:**
- Probar el botón "Generate BOM" desde la interfaz

**Cómo ejecutar:**
1. Abre la aplicación en el navegador
2. Ve a **Manufacturing Orders**
3. Selecciona un Manufacturing Order
4. Ve a la pestaña **Materials**
5. Haz clic en el botón **"Generate BOM"**
6. Espera a que termine (puede tardar unos segundos)
7. Verifica que:
   - Aparece un mensaje de éxito
   - Se muestran los materiales en la tabla
   - El fabric coincide con el del Sales Order
   - Los UOMs están normalizados (m, m2, ea)

**Verificación en la base de datos:**
```sql
-- Verificar que se creó un nuevo BOM instance
SELECT 
    bi.id AS bom_instance_id,
    bi.sale_order_line_id,
    bi.bom_template_id,
    bi.created_at,
    bi.generated_at,
    COUNT(bil.id) AS line_count
FROM "BomInstances" bi
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE bi.deleted = false
ORDER BY COALESCE(bi.generated_at, bi.created_at) DESC
LIMIT 5;
```

---

## ✅ PASO 9: Verificar Monitor BOM (Query 4)

**Archivo:** `database/migrations/QUERY_VERIFY_BOM_RESET_AND_SO_DRIVEN.sql`

**Qué hace:**
- Lista los BOM instances por Sale Order Line ordenados por fecha (más reciente primero)

**Cómo ejecutar:**
1. Abre Supabase SQL Editor
2. Copia el **Query 4** del archivo (líneas 122-140 aproximadamente)
3. Pega en el editor
4. Haz clic en "Run"

**Resultado esperado:**
- Debería mostrar para cada `sale_order_line_id`:
  - `bom_instance_id`
  - `bom_date` (fecha de creación/generación)
  - `line_count` (número de líneas)
  - Ordenado por fecha DESC (más reciente primero)

**Verificación:**
- El monitor en la UI debería mostrar el BOM más reciente (el primero en la lista)

---

## ✅ PASO 10: Verificar Duplicados (Query 5)

**Archivo:** `database/migrations/QUERY_VERIFY_BOM_RESET_AND_SO_DRIVEN.sql`

**Qué hace:**
- Detecta si hay múltiples BOM instances activos para el mismo SaleOrderLine (no debería haber después del reset)

**Cómo ejecutar:**
1. Abre Supabase SQL Editor
2. Copia el **Query 5** del archivo (líneas 142-160 aproximadamente)
3. Pega en el editor
4. Haz clic en "Run"

**Resultado esperado:**
- **Idealmente:** 0 filas (no hay duplicados)
- Si hay filas: muestra `sale_order_line_id` con múltiples `bom_instance_ids`

**Si hay duplicados:**
- Significa que hay BOMs viejos que no fueron borrados
- Ejecuta `reset_and_generate_bom_for_manufacturing_order` de nuevo para limpiar

---

## ✅ PASO 11: Verificar BOM Template Components (Query 6)

**Archivo:** `database/migrations/QUERY_VERIFY_BOM_RESET_AND_SO_DRIVEN.sql`

**Qué hace:**
- Verifica que los componentes del BOM template tengan UOM canónicos

**Cómo ejecutar:**
1. Abre Supabase SQL Editor
2. Copia el **Query 6** del archivo (líneas 162-180 aproximadamente)
3. Pega en el editor
4. Haz clic en "Run"

**Resultado esperado:**
- **Idealmente:** 0 filas (todos los UOMs son canónicos)
- Si hay filas: muestra componentes con UOMs no canónicos (ft, pcs, set)

**Si hay UOMs no canónicos en templates:**
- Necesitas actualizar los `BOMComponents` para usar UOMs canónicos
- O ejecutar una migración de normalización

---

## 🎯 Checklist Final

- [ ] Paso 1: Migración 419 ejecutada sin errores
- [ ] Paso 2: Función `generate_bom_for_manufacturing_order` actualizada
- [ ] Paso 3: Funciones helper probadas y funcionando
- [ ] Paso 4: `reset_and_generate_bom_for_manufacturing_order` probada
- [ ] Paso 5: Query 1 muestra templates resueltos correctamente
- [ ] Paso 6: Query 2 muestra fabric matching (✅ MATCH)
- [ ] Paso 7: Query 3 muestra UOMs normalizados (0 filas o solo ✅ CANONICAL)
- [ ] Paso 8: Botón "Generate BOM" funciona desde UI
- [ ] Paso 9: Query 4 muestra BOMs ordenados por fecha DESC
- [ ] Paso 10: Query 5 muestra 0 duplicados
- [ ] Paso 11: Query 6 muestra 0 UOMs no canónicos en templates

---

## 🆘 Troubleshooting

### Error: "column sol.configured_product_id does not exist"
- **Solución:** Ya está corregido en la migración 419. Asegúrate de ejecutar la versión más reciente.

### Error: "function resolve_bom_template_id_for_sale_order_line does not exist"
- **Solución:** Ejecuta el Paso 1 de nuevo (Migración 419).

### Error: "BOM generated but 0 lines created"
- **Posibles causas:**
  - No hay BOM template asociado al producto
  - Los componentes del template no están configurados correctamente
  - Hay errores en la resolución de SKUs
- **Solución:** Revisa los logs en la consola del navegador o ejecuta los queries de verificación.

### El fabric no coincide entre SO y BOM
- **Solución:** Verifica el Query 2. Si muestra `❌ MISMATCH`, revisa:
  - Que `QuoteLineComponents` tenga un componente con `role='fabric'`
  - Que `QuoteLine.collection_name` o `variant_name` estén correctos

---

## 📝 Notas Finales

- El botón "Generate BOM" ahora hace **reset + regeneración** (no solo genera)
- El fabric viene del **SO/QuoteLine** (SO-driven), no del template
- Los UOMs se normalizan automáticamente (ft→m, pcs→ea, set→ea)
- El monitor siempre muestra el **BOM más reciente** (por `generated_at`)

---

**¿Necesitas ayuda con algún paso específico?** Ejecuta los pasos en orden y avísame si encuentras algún error.


