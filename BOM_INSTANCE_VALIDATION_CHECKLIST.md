# ✅ Checklist de Validación: BOMInstance quote_line_id Fix

**Fecha:** 2026-01-25  
**Estado:** ✅ Migración ejecutada

---

## 🔍 VALIDACIÓN POST-MIGRACIÓN

### 1. Verificar que no hay BOMInstances huérfanos sin quote_line_id

```sql
-- ✅ Debe retornar 0
SELECT COUNT(*) 
FROM public."BOMInstances"
WHERE quote_line_id IS NULL
  AND deleted = false;
```

**Resultado esperado:** `0`

---

### 2. Verificar que las funciones SQL están correctas

```sql
-- Verificar firma de create_configured_product_and_bom_preview
SELECT 
    p.proname AS function_name,
    pg_get_function_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname = 'create_configured_product_and_bom_preview';
```

**Resultado esperado:** Debe tener 5 parámetros (incluyendo `p_quote_line_id`)

```sql
-- Verificar firma de generate_bom_from_slots_for_configured_product
SELECT 
    p.proname AS function_name,
    pg_get_function_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname = 'generate_bom_from_slots_for_configured_product';
```

**Resultado esperado:** Debe tener 4 parámetros (incluyendo `p_quote_line_id`)

```sql
-- Verificar que create_bom_instance_for_configured_product existe
SELECT 
    p.proname AS function_name,
    pg_get_function_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname = 'create_bom_instance_for_configured_product';
```

**Resultado esperado:** Debe existir con 4 parámetros

---

## 🧪 PRUEBAS EN UI

### Prueba 1: Flujo con ProductConfigurator (NUEVO)

**Pasos:**
1. Ir a: `Sales > Quotes > New`
2. Crear nueva Quote (si no existe)
3. Click en "Add Line"
4. Seleccionar producto (ej: Roller Shade)
5. Completar configuración:
   - Seleccionar medidas (width, height)
   - Seleccionar drive type (Manual/Motor)
   - Seleccionar fabric/variant
   - Seleccionar hardware color
6. Click en "Confirm" o "Save"

**Validaciones:**
- ✅ NO debe aparecer error: `null value in column "quote_line_id"`
- ✅ En Network tab (DevTools):
  - Request a `create_configured_product_and_bom_preview` debe tener `p_quote_line_id: null`
  - Request a `create_bom_instance_for_configured_product` debe tener `p_quote_line_id: <uuid>` (no-null)
- ✅ En consola del navegador:
  ```
  [createQuoteLineFromConfiguredProduct] ✅ BOMInstance created successfully: {
    quote_line_id: "...",  // ✅ Debe existir
    bom_instance_id: "..."
  }
  ```
- ✅ QuoteLine se crea correctamente
- ✅ BOMInstance se crea correctamente
- ✅ BOMInstanceLines se crean correctamente

---

### Prueba 2: Flujo Legacy (sin ProductConfigurator)

**Pasos:**
1. Ir a: `Sales > Quotes > New`
2. Crear nueva Quote (si no existe)
3. Click en "Add Line"
4. Completar formulario manualmente (sin configurador)
5. Guardar

**Validaciones:**
- ✅ QuoteLine se crea primero
- ✅ `generate_bom_from_slots` se llama con `quote_line_id` (no-null)
- ✅ BOMInstance se crea correctamente
- ✅ NO debe aparecer error de constraint

---

### Prueba 3: Verificar datos en DB

**Después de crear una QuoteLine con ProductConfigurator:**

```sql
-- Obtener el último QuoteLine creado
SELECT 
    ql.id AS quote_line_id,
    ql.quote_id,
    ql.configured_product_id,
    cp.id AS configured_product_exists,
    bi.id AS bom_instance_id,
    bi.quote_line_id AS bom_instance_quote_line_id,
    bi.configured_product_id AS bom_instance_configured_product_id,
    COUNT(bil.id) AS bom_instance_lines_count
FROM public."QuoteLines" ql
LEFT JOIN public."ConfiguredProducts" cp ON cp.id = ql.configured_product_id
LEFT JOIN public."BOMInstances" bi ON bi.quote_line_id = ql.id AND bi.deleted = false
LEFT JOIN public."BOMInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE ql.deleted = false
ORDER BY ql.created_at DESC
LIMIT 1;
```

**Validaciones:**
- ✅ `quote_line_id` debe existir
- ✅ `bom_instance_id` debe existir
- ✅ `bom_instance_quote_line_id` debe ser igual a `quote_line_id` (no NULL)
- ✅ `bom_instance_lines_count` debe ser > 0
- ✅ `configured_product_exists` debe existir si se usó ProductConfigurator

---

## 🐛 DEBUGGING

### Si aparece el error de constraint:

1. **Verificar logs en consola:**
   ```typescript
   // Buscar en consola del navegador:
   [createQuoteLineFromConfiguredProduct] Error creating BOMInstance
   ```

2. **Verificar que QuoteLine se creó:**
   ```sql
   SELECT id, quote_id, configured_product_id, created_at
   FROM public."QuoteLines"
   WHERE deleted = false
   ORDER BY created_at DESC
   LIMIT 5;
   ```

3. **Verificar que no hay BOMInstances sin quote_line_id:**
   ```sql
   SELECT id, quote_line_id, configured_product_id, created_at
   FROM public."BOMInstances"
   WHERE quote_line_id IS NULL
     AND deleted = false;
   ```

4. **Verificar llamadas a RPC:**
   - En Network tab, buscar requests a:
     - `create_configured_product_and_bom_preview`
     - `create_bom_instance_for_configured_product`
   - Verificar que los parámetros son correctos

---

## ✅ CHECKLIST FINAL

- [ ] Migración SQL ejecutada sin errores
- [ ] No hay BOMInstances sin `quote_line_id` (query 1)
- [ ] Funciones SQL tienen las firmas correctas (queries 2-4)
- [ ] Prueba 1 (ProductConfigurator) pasa todas las validaciones
- [ ] Prueba 2 (Legacy) pasa todas las validaciones
- [ ] Prueba 3 (DB) muestra datos correctos
- [ ] No hay errores en consola del navegador
- [ ] No hay errores en Network tab
- [ ] QuoteLines se crean correctamente
- [ ] BOMInstances se crean correctamente
- [ ] BOMInstanceLines se crean correctamente

---

## 📝 NOTAS

- **Orden crítico:** QuoteLine → BOMInstance (nunca al revés)
- **Preview:** ConfiguredProduct se crea sin BOMInstance (correcto)
- **Producción:** BOMInstance se crea después con `quote_line_id` (correcto)

---

**Estado:** ✅ Listo para validación
