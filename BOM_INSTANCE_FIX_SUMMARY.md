# ✅ FIX: BOMInstance quote_line_id Constraint

**Fecha:** 2026-01-25  
**Estado:** ✅ Completo

---

## 🐛 PROBLEMA

Error en UI:
```
Failed to create BOMInstance ... null value in column quote_line_id 
of relation BOMInstances violates not-null constraint
```

**Causa:** El frontend intentaba crear BOMInstance antes de tener QuoteLine.id (quote_line_id).

---

## ✅ SOLUCIÓN IMPLEMENTADA

### Cambios en SQL:

1. **`create_configured_product_and_bom_preview`** (RPC)
   - ✅ Agregado parámetro `p_quote_line_id` opcional
   - ✅ NO crea BOMInstance si `quote_line_id` es NULL
   - ✅ Solo crea ConfiguredProduct en el preview

2. **`generate_bom_from_slots_for_configured_product`** (función SQL)
   - ✅ Agregado parámetro `p_quote_line_id` opcional
   - ✅ Si `quote_line_id` es NULL: retorna NULL (no crea BOMInstance)
   - ✅ Si `quote_line_id` viene: crea BOMInstance con `quote_line_id` (requerido)

3. **`create_bom_instance_for_configured_product`** (nueva función RPC)
   - ✅ Valida que `quote_line_id` NO sea NULL
   - ✅ Crea BOMInstance con `quote_line_id` después de tener QuoteLine
   - ✅ Reutiliza `generate_bom_from_slots_for_configured_product` con `quote_line_id`

### Cambios en TypeScript:

1. **`createConfiguredProductPreview`**
   - ✅ Pasa `p_quote_line_id: null` (aún no existe QuoteLine)
   - ✅ BOMInstance NO se crea en el preview

2. **`createQuoteLineFromConfiguredProduct`**
   - ✅ Crea QuoteLine PRIMERO (obtiene `quote_line_id`)
   - ✅ Luego llama a `create_bom_instance_for_configured_product` con `quote_line_id`
   - ✅ Agregados logs de debugging

3. **`QuoteNew.tsx`**
   - ✅ Corregida redeclaración de `configuredProductId`
   - ✅ Flujo nuevo usa `createQuoteLineFromConfiguredProduct` (ya corregido)
   - ✅ Flujo legacy usa `generate_bom_from_slots` (ya tiene `quote_line_id`)

---

## 📊 FLUJO CORREGIDO

### Flujo con ProductConfigurator (NUEVO):
```
1. Usuario completa configuración en ProductConfigurator
2. createConfiguredProductPreview()
   → Crea ConfiguredProduct (sin BOMInstance)
   → Retorna configured_product_id
3. Usuario confirma → QuoteNew.handleProductConfigComplete()
4. createQuoteLineFromConfiguredProduct()
   → Crea QuoteLine PRIMERO (obtiene quote_line_id) ✅
   → Luego crea BOMInstance con quote_line_id ✅
   → Retorna quoteLineId
```

### Flujo Legacy (sin ProductConfigurator):
```
1. Usuario completa formulario en QuoteNew
2. Crea QuoteLine PRIMERO (obtiene quote_line_id) ✅
3. generate_bom_from_slots(quote_line_id) ✅
   → Crea BOMInstance con quote_line_id
```

---

## 🔒 GUARDRAILS IMPLEMENTADOS

1. **En SQL:**
   - ✅ `create_bom_instance_for_configured_product` valida `quote_line_id IS NOT NULL`
   - ✅ `generate_bom_from_slots_for_configured_product` retorna NULL si `quote_line_id` es NULL

2. **En TypeScript:**
   - ✅ `createQuoteLineFromConfiguredProduct` crea QuoteLine primero
   - ✅ Logs de debugging con `quote_id`, `quote_line_id`, `configured_product_id`

3. **En UI:**
   - ✅ Error claro si falta `quote_line_id`
   - ✅ No permite continuar sin QuoteLine

---

## 📁 ARCHIVOS MODIFICADOS

### Migraciones SQL:
1. ✅ `20260125_fix_bom_instance_quote_line_id_constraint.sql`
   - Modifica `create_configured_product_and_bom_preview`
   - Modifica `generate_bom_from_slots_for_configured_product`
   - Crea `create_bom_instance_for_configured_product`

### Código TypeScript:
1. ✅ `src/lib/bom/createConfiguredProductPreview.ts`
   - Pasa `p_quote_line_id: null` a la RPC

2. ✅ `src/lib/quotes/createQuoteLineFromConfiguredProduct.ts`
   - Crea QuoteLine primero
   - Luego crea BOMInstance con `quote_line_id`
   - Agregados logs de debugging

3. ✅ `src/pages/sales/QuoteNew.tsx`
   - Corregida redeclaración de `configuredProductId`

---

## 🚀 ORDEN DE EJECUCIÓN

```sql
\i database/migrations/20260125_fix_bom_instance_quote_line_id_constraint.sql
```

---

## ✅ VALIDACIÓN

### Prueba 1: Flujo con ProductConfigurator
1. Sales > Quotes > New > Add Line
2. Seleccionar producto y completar configuración
3. Confirmar
4. ✅ Verificar en Network que el request que crea BOMInstances incluye `quote_line_id` no-null
5. ✅ Verificar que no hay error de constraint

### Prueba 2: Flujo Legacy
1. Sales > Quotes > New > Add Line (sin configurador)
2. Completar formulario manualmente
3. Guardar
4. ✅ Verificar que BOMInstance se crea con `quote_line_id`

### Prueba 3: Verificar constraint
```sql
-- Verificar que NO hay BOMInstances sin quote_line_id
SELECT COUNT(*) 
FROM public."BOMInstances"
WHERE quote_line_id IS NULL
  AND deleted = false;
-- ✅ Debe retornar 0
```

---

## ⚠️ NOTAS IMPORTANTES

1. **Orden crítico:**
   - QuoteLine DEBE crearse ANTES de BOMInstance
   - BOMInstance SIEMPRE requiere `quote_line_id` (NOT NULL)

2. **Flujo de preview:**
   - ConfiguredProduct se crea sin BOMInstance
   - BOMInstance se crea después cuando se tiene QuoteLine

3. **Idempotencia:**
   - Si BOMInstance ya existe para `quote_line_id`, se reutiliza
   - No se crean duplicados

---

**Estado:** ✅ Listo para producción
