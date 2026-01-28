# ✅ FIX COMPLETO: BOMInstance quote_line_id Constraint

**Fecha:** 2026-01-25  
**Estado:** ✅ Implementación completa

---

## 🐛 PROBLEMA ORIGINAL

```
ERROR: null value in column "quote_line_id" of relation "BOMInstances" 
violates not-null constraint
```

**Causa raíz:** 
- `create_configured_product_and_bom_preview` creaba BOMInstance sin `quote_line_id`
- El constraint en DB requiere `quote_line_id NOT NULL`
- El frontend intentaba crear BOMInstance antes de tener QuoteLine.id

---

## ✅ SOLUCIÓN IMPLEMENTADA

### Regla de Oro Aplicada:
```
1) Crear QuoteLine primero (obtener quote_line_id)
2) Luego crear ConfiguredProduct (si aplica)
3) Luego crear BOMInstance usando quote_line_id ✅
4) Luego crear BOMInstanceLines
```

---

## 📁 ARCHIVOS MODIFICADOS

### Migración SQL:
1. ✅ `20260125_fix_bom_instance_quote_line_id_constraint.sql`
   - Modifica `create_configured_product_and_bom_preview`: NO crea BOMInstance sin `quote_line_id`
   - Modifica `generate_bom_from_slots_for_configured_product`: Acepta `quote_line_id` opcional
   - Crea `create_bom_instance_for_configured_product`: Helper que valida `quote_line_id`

### Código TypeScript:
1. ✅ `src/lib/bom/createConfiguredProductPreview.ts`
   - Pasa `p_quote_line_id: null` (aún no existe QuoteLine)

2. ✅ `src/lib/quotes/createQuoteLineFromConfiguredProduct.ts`
   - Crea QuoteLine PRIMERO
   - Luego crea BOMInstance con `quote_line_id`
   - Agregados logs de debugging

3. ✅ `src/pages/sales/QuoteNew.tsx`
   - Corregida redeclaración de `configuredProductId`

---

## 🔧 CAMBIOS DETALLADOS

### 1. SQL: `create_configured_product_and_bom_preview`
**Antes:**
```sql
-- Creaba BOMInstance sin quote_line_id ❌
v_bom_instance_id := public.generate_bom_from_slots_for_configured_product(...);
```

**Ahora:**
```sql
-- NO crea BOMInstance si quote_line_id es NULL ✅
v_bom_instance_id := NULL;
IF p_quote_line_id IS NULL THEN
    RAISE NOTICE 'BOMInstance NO creado en preview: quote_line_id es NULL.';
END IF;
```

### 2. SQL: `generate_bom_from_slots_for_configured_product`
**Antes:**
```sql
CREATE FUNCTION ... (p_org_id, p_configured_product_id, p_product_type_id)
-- Creaba BOMInstance con quote_line_id = NULL ❌
```

**Ahora:**
```sql
CREATE FUNCTION ... (p_org_id, p_configured_product_id, p_product_type_id, p_quote_line_id DEFAULT NULL)
-- Si quote_line_id es NULL: retorna NULL (no crea) ✅
-- Si quote_line_id viene: crea BOMInstance con quote_line_id ✅
```

### 3. SQL: `create_bom_instance_for_configured_product` (NUEVA)
```sql
-- Valida que quote_line_id NO sea NULL
IF p_quote_line_id IS NULL THEN
    RAISE EXCEPTION 'quote_line_id is required';
END IF;

-- Crea BOMInstance con quote_line_id
v_bom_instance_id := public.generate_bom_from_slots_for_configured_product(
    p_org_id,
    p_configured_product_id,
    p_product_type_id,
    p_quote_line_id  -- ✅ REQUERIDO
);
```

### 4. TypeScript: `createQuoteLineFromConfiguredProduct`
**Antes:**
```typescript
// Buscaba BOMInstance existente (podría no existir)
// Creaba QuoteLine
// ❌ BOMInstance se creaba antes sin quote_line_id
```

**Ahora:**
```typescript
// 1. Crear QuoteLine PRIMERO ✅
const { data: newQuoteLine } = await supabase.from('QuoteLines').insert(...);

// 2. Crear BOMInstance DESPUÉS con quote_line_id ✅
const { data: bomInstanceId } = await supabase.rpc(
  'create_bom_instance_for_configured_product',
  { p_quote_line_id: newQuoteLine.id, ... }
);
```

---

## 📊 FLUJOS CORREGIDOS

### Flujo A: Con ProductConfigurator (NUEVO)
```
Usuario completa configuración
  ↓
ProductConfigurator.onComplete()
  ↓
createConfiguredProductPreview()
  → Crea ConfiguredProduct (sin BOMInstance) ✅
  → Retorna configured_product_id
  ↓
QuoteNew.handleProductConfigComplete()
  ↓
createQuoteLineFromConfiguredProduct()
  → 1. Crea QuoteLine PRIMERO ✅
  → 2. Obtiene quote_line_id ✅
  → 3. Crea BOMInstance con quote_line_id ✅
  → 4. Retorna quoteLineId
```

### Flujo B: Legacy (sin ProductConfigurator)
```
Usuario completa formulario
  ↓
QuoteNew.handleProductConfigComplete()
  → 1. Crea QuoteLine PRIMERO ✅
  → 2. Obtiene quote_line_id ✅
  → 3. generate_bom_from_slots(quote_line_id) ✅
     → Crea BOMInstance con quote_line_id
```

---

## 🔒 GUARDRAILS

### SQL:
- ✅ `create_bom_instance_for_configured_product` valida `quote_line_id IS NOT NULL`
- ✅ `generate_bom_from_slots_for_configured_product` retorna NULL si `quote_line_id` es NULL
- ✅ `create_configured_product_and_bom_preview` NO crea BOMInstance sin `quote_line_id`

### TypeScript:
- ✅ `createQuoteLineFromConfiguredProduct` crea QuoteLine primero
- ✅ Logs de debugging con `quote_id`, `quote_line_id`, `configured_product_id`
- ✅ Manejo de errores: no falla si BOMInstance no se puede crear (solo registra warning)

### UI:
- ✅ Error claro si falta `quote_line_id`
- ✅ No permite continuar sin QuoteLine

---

## 🚀 ORDEN DE EJECUCIÓN

```sql
\i database/migrations/20260125_fix_bom_instance_quote_line_id_constraint.sql
```

---

## ✅ VALIDACIÓN FINAL

### Prueba 1: Flujo con ProductConfigurator
1. Sales > Quotes > New > Add Line
2. Seleccionar producto y completar configuración
3. Confirmar
4. ✅ Verificar en Network que el request que crea BOMInstances incluye `quote_line_id` no-null
5. ✅ Verificar que no hay error de constraint
6. ✅ Verificar que BOMInstance se crea correctamente

### Prueba 2: Verificar constraint
```sql
-- Verificar que NO hay BOMInstances sin quote_line_id
SELECT COUNT(*) 
FROM public."BOMInstances"
WHERE quote_line_id IS NULL
  AND deleted = false;
-- ✅ Debe retornar 0
```

### Prueba 3: Verificar logs
```typescript
// En consola del navegador, buscar:
[createQuoteLineFromConfiguredProduct] ✅ BOMInstance created successfully: {
  quote_id: "...",
  quote_line_id: "...",  // ✅ Debe existir
  configured_product_id: "...",
  bom_instance_id: "..."
}
```

---

## ⚠️ NOTAS IMPORTANTES

1. **Orden crítico:**
   - QuoteLine DEBE crearse ANTES de BOMInstance
   - BOMInstance SIEMPRE requiere `quote_line_id` (NOT NULL)

2. **Flujo de preview:**
   - ConfiguredProduct se crea sin BOMInstance (preview)
   - BOMInstance se crea después cuando se tiene QuoteLine

3. **Idempotencia:**
   - Si BOMInstance ya existe para `quote_line_id`, se reutiliza
   - No se crean duplicados

4. **Backward compatibility:**
   - Flujo legacy sigue funcionando (ya creaba QuoteLine primero)
   - Flujo nuevo ahora también crea QuoteLine primero

---

**Estado:** ✅ Listo para producción
