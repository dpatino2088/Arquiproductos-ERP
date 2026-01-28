# 📋 INFORME DETALLADO: Problemas BOM y Pricing
**Fecha:** 2026-01-19  
**Equipo:** Desarrollo Adaptio ERP  
**Módulo:** Sales Quotes - BOM Configurator

---

## 🔴 PROBLEMAS IDENTIFICADOS

### 1. **Precios en $0.00 (CRÍTICO)**
**Síntoma:**
- Quote Lines muestran `LIST PRICE: $0.00` y `TOTAL: $0.00`
- Subtotal, Tax y Total están en $0.00
- El BOM se genera pero no se calculan los precios

**Evidencia:**
- Tabla de Quote Lines muestra valores en $0.00
- Console logs no muestran errores de cálculo de precios (o están silenciados)

---

### 2. **Error: `Could not find product_type_id for productType: "roller-shade"`**
**Síntoma:**
- Warning en console: `⚠️ Could not find product_type_id for productType: "roller-shade". BOM generation may fail.`
- El `product_type_id` no se resuelve correctamente

**Ubicación del código:**
- `src/pages/sales/QuoteNew.tsx:603`

**Impacto:**
- Si `product_type_id` es `null`, `generate_bom_from_slots()` no puede ejecutarse
- El BOM no se genera → No hay precios

---

### 3. **Errores en `useBOMTemplates` al obtener ProductTypes**
**Síntoma:**
- Console errors: `[useBOMTemplates] Error fetching ProductTypes "[circular]"`
- Múltiples warnings sobre ProductTypes no encontrados

**Impacto:**
- El configurador no puede cargar los BOMTemplates disponibles
- No se puede validar si un template requiere hardware_color

---

### 4. **Validación de Hardware Color (RESUELTO PARCIALMENTE)**
**Síntoma:**
- Error: "Hardware color is required" aparece incluso cuando el usuario no ha llegado al paso Hardware
- El hardware color se inicializa con 'White' pero la validación se ejecuta antes

**Estado:**
- ✅ Parcialmente resuelto: Se inicializa con 'White' antes de validar
- ⚠️ Puede persistir si el config no se actualiza correctamente

---

## 🔍 HIPÓTESIS DE CAUSAS

### Hipótesis 1: Desalineación entre `productType` (string) y `code` en ProductTypes
**Causa probable:**
- El configurator usa `productType: "roller-shade"` (con guión)
- La BD puede tener `code: "roller"`, `code: "ROLLER"`, o `code: "roller_shade"` (con guión bajo)
- El código intenta 3 estrategias de búsqueda pero todas fallan

**Evidencia:**
```typescript
// QuoteNew.tsx:547-577
.eq('code', productConfig.productType)  // Busca "roller-shade"
.ilike('code', productConfig.productType)  // Busca "roller-shade" (case-insensitive)
```

**Solución propuesta:**
1. Normalizar el `productType` antes de buscar (ej: `"roller-shade"` → `"roller"`)
2. Agregar mapeo explícito: `{ "roller-shade": "roller", "dual-shade": "dual", ... }`
3. Verificar en BD qué códigos existen realmente

---

### Hipótesis 2: BOM no se genera porque `product_type_id` es `null`
**Causa probable:**
- Si `product_type_id` es `null`, el código salta la generación del BOM:
  ```typescript
  if (productTypeId) {
    // Generate BOM...
  }
  ```
- Sin BOM → No hay `BOMInstanceLines` → No hay precios

**Evidencia:**
- Console warning: `Could not find product_type_id`
- Precios en $0.00

**Solución propuesta:**
1. **CRÍTICO:** Asegurar que `product_type_id` se resuelva correctamente
2. Agregar fallback: Si no se encuentra, buscar por nombre o usar un ProductType por defecto
3. Mostrar error claro al usuario si no se puede resolver

---

### Hipótesis 3: Cálculo de precios no se ejecuta o falla silenciosamente
**Causa probable:**
- El cálculo de precios está dentro de un `try-catch` que puede estar silenciando errores
- Los `BOMInstanceLines` pueden no tener `resolved_part_id` (NULL)
- Los `CatalogItemsMSRP` pueden no tener `msrp_sale_out` para los items del BOM

**Evidencia:**
- Código en `QuoteNew.tsx:1189-1290` tiene try-catch que solo muestra warning
- No hay logs de `💰 BOM Total Pricing` en console (o están ocultos)

**Solución propuesta:**
1. Agregar logging detallado en cada paso del cálculo
2. Verificar que `BOMInstanceLines` tengan `resolved_part_id` no NULL
3. Verificar que `CatalogItemsMSRP` tenga datos para los items del BOM
4. Mostrar error visible al usuario si el cálculo falla

---

### Hipótesis 4: `list_unit_price_snapshot` no se actualiza correctamente
**Causa probable:**
- El código actualiza `list_unit_price_snapshot` pero puede haber un problema de timing
- La tabla puede estar mostrando valores cacheados o antiguos
- El `refetchLines()` puede no estar funcionando correctamente

**Evidencia:**
- Código actualiza `list_unit_price_snapshot` en línea 1272
- Llama a `refetchLines()` pero puede no estar esperando

**Solución propuesta:**
1. Verificar que el `UPDATE` se ejecute correctamente (check `updateError`)
2. Asegurar que `refetchLines()` espere a que termine el UPDATE
3. Agregar loading state mientras se calculan los precios

---

## 🛠️ SOLUCIONES PROPUESTAS

### Solución 1: Normalizar y mapear `productType` → `code` (PRIORIDAD ALTA)
**Archivo:** `src/pages/sales/QuoteNew.tsx`

```typescript
// Agregar mapeo explícito
const PRODUCT_TYPE_CODE_MAP: Record<string, string[]> = {
  'roller-shade': ['roller', 'ROLLER', 'roller_shade', 'roller-shade'],
  'dual-shade': ['dual', 'DUAL', 'dual_shade', 'dual-shade'],
  'triple-shade': ['triple', 'TRIPLE', 'triple_shade', 'triple-shade'],
  'drapery': ['drapery', 'DRAPERY'],
  'awning': ['awning', 'AWNING'],
};

// Función para resolver product_type_id
async function resolveProductTypeId(
  productType: string,
  organizationId: string
): Promise<string | null> {
  const possibleCodes = PRODUCT_TYPE_CODE_MAP[productType] || [productType];
  
  for (const code of possibleCodes) {
    // Try exact match
    const { data } = await supabase
      .from('ProductTypes')
      .select('id')
      .eq('organization_id', organizationId)
      .eq('code', code)
      .eq('deleted', false)
      .limit(1);
    
    if (data && data.length > 0) return data[0].id;
    
    // Try case-insensitive
    const { data: dataCI } = await supabase
      .from('ProductTypes')
      .select('id')
      .eq('organization_id', organizationId)
      .ilike('code', code)
      .eq('deleted', false)
      .limit(1);
    
    if (dataCI && dataCI.length > 0) return dataCI[0].id;
  }
  
  return null;
}
```

---

### Solución 2: Mejorar logging y error handling en cálculo de precios (PRIORIDAD ALTA)
**Archivo:** `src/pages/sales/QuoteNew.tsx`

```typescript
// Agregar logging detallado
if (import.meta.env.DEV) {
  console.log('🔍 BOM Pricing Calculation:', {
    bomInstanceId,
    bomLinesCount: bomLines?.length || 0,
    partIds: partIds,
    msrpRowsCount: msrpRows?.length || 0,
  });
  
  // Log cada línea del BOM
  bomLines?.forEach((line, idx) => {
    console.log(`  Line ${idx + 1}:`, {
      partId: line.resolved_part_id,
      qty: line.qty,
      msrp: msrpMap.get(line.resolved_part_id) || line.catalog_item?.msrp || 0,
      cost: line.catalog_item?.cost_exw || 0,
    });
  });
}

// Verificar que haya líneas del BOM
if (!bomLines || bomLines.length === 0) {
  console.error('❌ No BOMInstanceLines found for bomInstanceId:', bomInstanceId);
  useUIStore.getState().addNotification({
    type: 'error',
    title: 'BOM Empty',
    message: 'No components found in BOM. Please check BOMTemplate configuration.',
  });
  return;
}

// Verificar que haya resolved_part_id
const linesWithoutPart = bomLines.filter(l => !l.resolved_part_id);
if (linesWithoutPart.length > 0) {
  console.warn('⚠️ Some BOM lines have no resolved_part_id:', linesWithoutPart);
}
```

---

### Solución 3: Verificar datos en BD (PRIORIDAD MEDIA)
**Script SQL:** `backups/DIAGNOSTIC_PRICING.sql`

```sql
-- 1. Verificar ProductTypes y sus códigos
SELECT id, code, name, organization_id 
FROM public."ProductTypes" 
WHERE deleted = false
ORDER BY code;

-- 2. Verificar BOMInstance reciente
SELECT 
  bi.id,
  bi.quote_line_id,
  bi.bom_template_id,
  bt.code as template_code,
  COUNT(bil.id) as lines_count
FROM public."BOMInstances" bi
JOIN public."BOMTemplates" bt ON bt.id = bi.bom_template_id
LEFT JOIN public."BOMInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE bi.deleted = false
ORDER BY bi.created_at DESC
LIMIT 5;

-- 3. Verificar BOMInstanceLines con precios
SELECT 
  bil.id,
  bil.resolved_part_id,
  bil.qty,
  ci.sku,
  ci.name,
  ci.msrp,
  msrp.msrp_sale_out
FROM public."BOMInstanceLines" bil
LEFT JOIN public."CatalogItems" ci ON ci.id = bil.resolved_part_id
LEFT JOIN public."CatalogItemsMSRP" msrp ON msrp.catalog_item_id = bil.resolved_part_id
WHERE bil.bom_instance_id = (
  SELECT id FROM public."BOMInstances" 
  WHERE deleted = false 
  ORDER BY created_at DESC 
  LIMIT 1
)
LIMIT 20;

-- 4. Verificar QuoteLines con precios
SELECT 
  ql.id,
  ql.quote_id,
  ql.msrp,
  ql.list_unit_price_snapshot,
  ql.cost_exw,
  ql.total_cost,
  bi.id as bom_instance_id
FROM public."QuoteLines" ql
LEFT JOIN public."BOMInstances" bi ON bi.quote_line_id = ql.id AND bi.deleted = false
WHERE ql.organization_id = 'YOUR_ORG_ID'
ORDER BY ql.created_at DESC
LIMIT 5;
```

---

### Solución 4: Agregar validación y fallback para `product_type_id` (PRIORIDAD ALTA)
**Archivo:** `src/pages/sales/QuoteNew.tsx`

```typescript
// Después de intentar resolver product_type_id
if (!productTypeId) {
  const errorMsg = `Could not resolve product_type_id for productType: "${productConfig.productType}". Please verify ProductTypes table has a record with matching code.`;
  console.error('❌', errorMsg);
  
  useUIStore.getState().addNotification({
    type: 'error',
    title: 'Product Type Not Found',
    message: `The product type "${productConfig.productType}" could not be found in the database. Please contact support.`,
  });
  
  // NO continuar si no hay product_type_id - el BOM no se puede generar
  return;
}
```

---

## 📊 CHECKLIST DE DIAGNÓSTICO

### Paso 1: Verificar ProductTypes en BD
- [ ] Ejecutar: `SELECT code, name FROM "ProductTypes" WHERE deleted = false;`
- [ ] Verificar que exista un ProductType con código que coincida con `"roller-shade"` o `"roller"`
- [ ] Si no existe, crear o actualizar el código

### Paso 2: Verificar BOMInstance se genera
- [ ] Abrir console del navegador
- [ ] Configurar un producto y guardar
- [ ] Buscar log: `✅ BOM Instance created (from slots):`
- [ ] Si no aparece, verificar error en console

### Paso 3: Verificar BOMInstanceLines tienen resolved_part_id
- [ ] Ejecutar script SQL de Solución 3
- [ ] Verificar que `resolved_part_id` no sea NULL
- [ ] Si es NULL, verificar que `QuoteLineComponents` tenga las selecciones del usuario

### Paso 4: Verificar CatalogItemsMSRP tiene datos
- [ ] Ejecutar: `SELECT catalog_item_id, msrp_sale_out FROM "CatalogItemsMSRP" WHERE catalog_item_id IN (...);`
- [ ] Verificar que los items del BOM tengan `msrp_sale_out`
- [ ] Si no tienen, verificar que `CatalogItems` tenga `msrp` como fallback

### Paso 5: Verificar QuoteLine se actualiza
- [ ] Después de guardar, ejecutar: `SELECT msrp, list_unit_price_snapshot FROM "QuoteLines" WHERE id = '...';`
- [ ] Verificar que `list_unit_price_snapshot` tenga valor > 0
- [ ] Si es 0, verificar logs de `💰 BOM Total Pricing`

---

## 🎯 PLAN DE ACCIÓN RECOMENDADO

### Fase 1: Resolver `product_type_id` (URGENTE)
1. ✅ Ejecutar script SQL para verificar códigos de ProductTypes
2. ✅ Implementar Solución 1 (mapeo de productType → code)
3. ✅ Agregar validación y error handling (Solución 4)
4. ✅ Probar que `product_type_id` se resuelve correctamente

### Fase 2: Mejorar cálculo de precios (ALTA PRIORIDAD)
1. ✅ Implementar Solución 2 (logging detallado)
2. ✅ Ejecutar script SQL de diagnóstico (Solución 3)
3. ✅ Verificar que `BOMInstanceLines` tengan `resolved_part_id`
4. ✅ Verificar que `CatalogItemsMSRP` tenga datos
5. ✅ Corregir cualquier problema encontrado

### Fase 3: Validar y probar (MEDIA PRIORIDAD)
1. ✅ Probar flujo completo: Configurar → Guardar → Ver precios
2. ✅ Verificar que precios se muestren en tabla
3. ✅ Verificar que subtotal/total se calculen correctamente
4. ✅ Documentar cualquier edge case encontrado

---

## 📝 NOTAS ADICIONALES

### Errores en Console (No críticos pero a revisar)
- `Multiple GoTrueClient instances detected`: No afecta funcionalidad, pero debería limpiarse
- `Error getting user profile undefined`: Revisar hook de autenticación
- `ProductStep: No UI metadata for ProductType code: honey_comb`: Agregar metadata o ignorar si no se usa

### Mejoras Futuras
- Agregar loading state mientras se calculan precios
- Mostrar progreso: "Calculating BOM prices..."
- Cachear `product_type_id` para evitar búsquedas repetidas
- Agregar retry logic si el cálculo de precios falla

---

## 🔗 ARCHIVOS RELACIONADOS

- `src/pages/sales/QuoteNew.tsx` - Lógica principal de guardado y cálculo de precios
- `src/pages/sales/ProductConfigurator.tsx` - Validación de configuración
- `src/pages/sales/curtain-config/HardwareStep.tsx` - Inicialización de hardware color
- `database/migrations/20260119_bom_padre_hijo_separation.sql` - Función `generate_bom_from_slots`
- `backups/FIX_TEMPLATE_FINGERPRINT.sql` - Script para actualizar fingerprints de templates

---

**Generado por:** Auto (Cursor AI)  
**Revisión requerida por:** Equipo de Desarrollo
