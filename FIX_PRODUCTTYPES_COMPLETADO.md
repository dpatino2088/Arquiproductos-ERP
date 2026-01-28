# ✅ FIX: ProductTypes - Soporte para Registros Globales

**Fecha:** 2026-01-20  
**Problema:** "Product Type Not Found" porque ProductTypes son globales (organization_id NULL)

---

## 🔍 PROBLEMA IDENTIFICADO

- **Toast:** "Product Type Not Found: No ProductType match for 'roller-shade'"
- **Console:** `[useBOMTemplates] Error fetching ProductTypes "[circular]"`
- **Console:** "Error getting user profile undefined"

**Causa raíz:** ProductTypes son un catálogo global (organization_id NULL), pero el frontend estaba filtrando solo por `.eq('organization_id', organizationId)`, retornando 0 resultados.

---

## ✅ SOLUCIÓN IMPLEMENTADA

### **1. Guardrails para organizationId**

**En `QuoteNew.tsx`:**
```typescript
if (!activeOrganizationId) {
  console.error("❌ Missing organizationId; cannot resolve ProductTypes.");
  useUIStore.getState().addNotification({
    type: "error",
    title: "Org not loaded",
    message: "No organizationId in session/profile. Fix auth profile.",
  });
  return;
}
```

**En `useBOMTemplates.ts`:**
```typescript
if (!activeOrganizationId) {
  console.error('[useBOMTemplates] ❌ Missing activeOrganizationId; cannot fetch templates');
  setLoading(false);
  setTemplates([]);
  setError('No organizationId in session/profile. Fix auth profile.');
  return;
}
```

### **2. Soporte para registros globales (organization_id NULL)**

**Cambiado TODAS las queries a ProductTypes para usar:**
```typescript
.or(`organization_id.eq.${organizationId},organization_id.is.null`)
```

**Archivos modificados:**
- ✅ `src/pages/sales/QuoteNew.tsx` - `resolveProductTypeId()` (3 queries)
- ✅ `src/pages/sales/QuoteNew.tsx` - Editar quote line (2 queries)
- ✅ `src/hooks/useBOMTemplates.ts` - Fetch ProductTypes (1 query)
- ✅ `src/hooks/useProductTypes.ts` - Fetch ProductTypes (1 query)
- ✅ `src/pages/catalog/BOMTemplates.tsx` - Fetch ProductTypes (1 query)

### **3. Logs DEBUG**

**En `resolveProductTypeId()`:**
```typescript
if (import.meta.env.DEV) {
  console.log("🔍 resolveProductTypeId DEBUG:", { organizationId, productTypeRaw });
  console.log("✅ resolveProductTypeId: Found by exact code", { code, id: data[0].id });
  console.warn("⚠️ resolveProductTypeId: No match found", { productTypeRaw, candidates });
}
```

**En `useBOMTemplates.ts`:**
```typescript
if (import.meta.env.DEV) {
  console.log('[useBOMTemplates] DEBUG:', { 
    activeOrganizationId, 
    productTypeId,
    timestamp: new Date().toISOString()
  });
}
```

### **4. Eliminar "[circular]" en logs**

**En `useBOMTemplates.ts`:**
- ✅ Ya implementado `safeErr()` función
- ✅ Usado en catch de ProductTypes fetch

**En `src/lib/supabase/client.ts`:**
- ✅ Fix para "Error getting user profile undefined" usando safeErr

---

## 📋 ARCHIVOS MODIFICADOS

1. ✅ `src/pages/sales/QuoteNew.tsx`
   - Guardrail para organizationId
   - `resolveProductTypeId()` soporta registros globales
   - Logs DEBUG agregados
   - Queries de edición soportan registros globales

2. ✅ `src/hooks/useBOMTemplates.ts`
   - Guardrail para organizationId
   - Logs DEBUG agregados
   - Query a ProductTypes soporta registros globales

3. ✅ `src/hooks/useProductTypes.ts`
   - Query a ProductTypes soporta registros globales

4. ✅ `src/pages/catalog/BOMTemplates.tsx`
   - Query a ProductTypes soporta registros globales

5. ✅ `src/lib/supabase/client.ts`
   - Fix para "Error getting user profile undefined"

6. ✅ `backups/DIAGNOSTIC_PRODUCTTYPES.sql`
   - SQL de diagnóstico y fixes

---

## 🧪 VALIDACIÓN

### **Test 1: Verificar que organizationId existe**
1. Abrir consola en `/sales/quotes/new`
2. Verificar que aparece log: `🔍 resolveProductTypeId DEBUG: { organizationId: "...", productTypeRaw: "roller-shade" }`
3. Si NO aparece organizationId → Error: "Org not loaded"

### **Test 2: Verificar que ProductType se resuelve**
1. Configurar producto "roller-shade"
2. Verificar que aparece log: `✅ resolveProductTypeId: Found by exact code { code: "roller", id: "..." }`
3. NO debe aparecer toast "Product Type Not Found"

### **Test 3: Verificar que no hay "[circular]"**
1. Abrir consola
2. NO debe aparecer `[circular]` en ningún error
3. Errores deben mostrarse correctamente con `safeErr()`

---

## 🚀 PRÓXIMOS PASOS

### **1. Ejecutar SQL de diagnóstico:**
```sql
-- En Supabase SQL Editor
-- Ejecutar: backups/DIAGNOSTIC_PRODUCTTYPES.sql
```

### **2. Verificar qué ProductTypes existen:**
- Si `organization_id` es NULL → ProductTypes son globales (OK, ya está arreglado)
- Si NO existe "roller" → Ejecutar SQL #3 para crearlo
- Si existe pero con code diferente → El frontend ya maneja aliases (OK)

### **3. Reiniciar dev server:**
```bash
# Para asegurar que los cambios de hook/log sí cargaron
# Ctrl+C y luego npm run dev
```

### **4. Probar flujo completo:**
1. Abrir `/sales/quotes/new`
2. Click "Add Line"
3. Configurar producto "roller-shade"
4. Verificar en consola:
   - ✅ `organizationId` correcto
   - ✅ `resolveProductTypeId` encuentra el ProductType
   - ✅ NO aparece "Product Type Not Found"
   - ✅ NO aparece "[circular]"

---

## 📝 NOTAS FINALES

- ✅ Todas las queries a ProductTypes ahora soportan registros globales
- ✅ Guardrails implementados para organizationId
- ✅ Logs DEBUG para troubleshooting
- ✅ Errores "[circular]" eliminados
- ✅ Error "Error getting user profile undefined" arreglado

**Si aún aparece "Product Type Not Found":**
1. Ejecutar SQL #1 para ver qué ProductTypes existen
2. Si NO existe "roller", ejecutar SQL #3
3. Verificar que organizationId esté correcto en consola
