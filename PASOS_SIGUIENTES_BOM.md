# 🎯 Pasos Siguientes: Verificación y Pruebas del BOM

## ✅ Lo que ya está completado:

1. ✅ **BOM Templates reconstruidos** - 3 templates creados (BOTTOM_RAIL_ONLY, SIDE_CHANNEL_ONLY, SIDE_CHANNEL_WITH_BOTTOM_RAIL)
2. ✅ **Frontend actualizado** - MaterialsTab y BOMTemplates.tsx muestran las nuevas categorías
3. ✅ **Función de categorización actualizada** - `derive_category_code_from_role` mapea los nuevos roles
4. ✅ **Categorías regeneradas** - `REGENERATE_BOM_CATEGORIES.sql` ejecutado

---

## 📋 Pasos Siguientes (en orden):

### **Paso 1: Verificar Categorías** ⚠️ PRIORITARIO

**Ejecutar:** `VERIFY_BOM_CATEGORIES.sql` en Supabase SQL Editor

**Qué verifica:**
- Que todas las categorías se asignaron correctamente
- Que no hay categorías NULL o inesperadas
- Que los `part_role` se mapearon correctamente a `category_code`

**Resultado esperado:**
- Ver categorías: `fabric`, `tube`, `motor`, `bracket`, `cassette`, `side_channel`, `bottom_channel`, `accessory`
- Cada categoría debe tener líneas asociadas

---

### **Paso 2: Verificar Manufacturing Order BOM** ⚠️ PRIORITARIO

**Acción:** Ir a la aplicación y verificar el Manufacturing Order BOM tab

**Qué verificar:**
1. Abrir un Manufacturing Order existente
2. Ir al tab "Materials"
3. Verificar que se muestran **TODOS** los componentes, no solo fabrics:
   - ✅ Fabric (telas)
   - ✅ Tube (tubos)
   - ✅ Motor / Drive
   - ✅ Bracket
   - ✅ Cassette
   - ✅ Side Channel
   - ✅ Bottom Rail / Bottom Channel
   - ✅ Accessory

**Si solo aparecen fabrics:**
- Los BOMs no se generaron correctamente desde los QuoteLines
- Necesitas ejecutar `REGENERATE_BOM_FROM_QUOTES.sql`

---

### **Paso 3: Regenerar BOMs desde QuoteLines** (si es necesario)

**Ejecutar:** `REGENERATE_BOM_FROM_QUOTES.sql` en Supabase SQL Editor

**Cuándo ejecutar:**
- Si en el Paso 2 solo ves fabrics en el Manufacturing Order BOM
- Si los componentes no aparecen correctamente categorizados

**Qué hace:**
- Regenera `QuoteLineComponents` desde los QuoteLines aprobados
- Usa `generate_configured_bom_for_quote_line` para cada QuoteLine
- Actualiza las categorías en `BomInstanceLines`

**⚠️ Nota:** Este script puede tardar si hay muchos quotes aprobados.

---

### **Paso 4: Probar Flujo Completo** (Opcional pero recomendado)

**Flujo de prueba:**
1. Crear un nuevo Quote en la aplicación
2. Configurar un producto completo:
   - Seleccionar Product Type
   - Seleccionar Collection y Variant (fabric)
   - Seleccionar Operating System (motor/tube)
   - Seleccionar Hardware (brackets, cassette, side channel, bottom rail)
   - Agregar Accessories
3. Guardar el Quote
4. Aprobar el Quote (esto crea SaleOrder y BOM)
5. Verificar Manufacturing Order:
   - Ir a Manufacturing Orders
   - Abrir el Manufacturing Order creado
   - Verificar que el tab "Materials" muestra **TODOS** los componentes

**Resultado esperado:**
- Todos los componentes aparecen correctamente categorizados
- Las cantidades son correctas
- Los costos se calculan correctamente

---

### **Paso 5: Verificar BOM Templates en UI** (Opcional)

**Acción:** Ir a Catalog > BOM en la aplicación

**Qué verificar:**
1. Los BOM Templates se muestran correctamente
2. Los componentes están agrupados por `block_type`:
   - TUBO
   - DRIVE
   - BRACKET
   - CASSETTE
   - BOTTOM_RAIL
   - SIDE_CHANNEL
3. Se muestran los campos nuevos:
   - Role (component_role)
   - Condition (block_condition)
   - Color (applies_color)

---

## 🚨 Si algo no funciona:

### Problema: Solo aparecen fabrics en Manufacturing Order BOM

**Solución:**
1. Ejecutar `REGENERATE_BOM_FROM_QUOTES.sql`
2. Verificar que los QuoteLines tienen `product_type_id` correcto
3. Verificar que los QuoteLines tienen toda la configuración necesaria:
   - `drive_type`
   - `bottom_rail_type`
   - `cassette`
   - `side_channel`
   - `hardware_color`

### Problema: Categorías incorrectas o NULL

**Solución:**
1. Verificar que `derive_category_code_from_role` está actualizada
2. Ejecutar `REGENERATE_BOM_CATEGORIES.sql` nuevamente
3. Verificar que `part_role` en `BomInstanceLines` tiene valores correctos

### Problema: Componentes faltantes en BOM

**Solución:**
1. Verificar que el BOMTemplate tiene todos los componentes necesarios
2. Verificar que los `block_condition` coinciden con la configuración del QuoteLine
3. Verificar que los SKUs existen en `CatalogItems`
4. Ejecutar `VERIFY_BOM_COMPONENTS_CREATED.sql` para verificar los templates

---

## 📊 Scripts de Diagnóstico Disponibles:

1. **VERIFY_BOM_CATEGORIES.sql** - Verifica categorías en BomInstanceLines
2. **VERIFY_BOM_COMPONENTS_CREATED.sql** - Verifica componentes en BOMTemplates
3. **CHECK_BOM_COMPLETE_FLOW.sql** - Verifica el flujo completo Quote → BOM
4. **DIAGNOSTICO_COMPLETO_BOM.sql** - Diagnóstico completo del BOM

---

## ✅ Checklist Final:

- [ ] Ejecutar `VERIFY_BOM_CATEGORIES.sql` y verificar resultados
- [ ] Verificar Manufacturing Order BOM muestra todos los componentes
- [ ] Si faltan componentes, ejecutar `REGENERATE_BOM_FROM_QUOTES.sql`
- [ ] Probar flujo completo: crear quote → aprobar → verificar BOM
- [ ] Verificar BOM Templates en UI muestran block_type correctamente

---

## 🎯 Objetivo Final:

**Todos los componentes del BOM deben aparecer correctamente categorizados en el Manufacturing Order BOM tab, no solo las telas.**








