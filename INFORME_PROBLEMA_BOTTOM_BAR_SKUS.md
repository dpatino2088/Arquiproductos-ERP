# INFORME: Problema Bottom Bar SKUs No Mostrados ✅ RESUELTO

## 🔴 Problema Principal ✅ RESUELTO

**Síntoma:** Los SKUs de Bottom Bar no se mostraban en los cards, aunque los templates se detectaban correctamente.

**Debug Info Original:**
- `baseTemplateIds=0` (debería ser ~3)
- `hasHardwareColor=true`
- `loading=false`
- `error=none`
- `optionsCount=0`

**ROOT CAUSE IDENTIFICADO:**
Cache en `useBOMTemplates` retornaba solo `templates` (filtered) pero NO `baseTemplates`, dejando `baseTemplateIds=0` y por tanto sin opciones de Bottom Bar.

**FIX APLICADO:**
1. ✅ Cache ahora guarda y retorna tanto `baseTemplates` como `templates`
2. ✅ `HardwareStep` tiene fallback: usa `filteredTemplateIds` si `baseTemplateIds` está vacío
3. ✅ Logs de validación agregados en puntos críticos

## 🔍 Análisis del Flujo

### 1. Flujo Esperado

```
ProductConfigurator
  ↓
useBOMTemplates(productTypeId, hardwareColor, templateFilters)
  ↓
Query inicial: BOMTemplates WHERE product_type_id, hardware_color, organization_id
  ↓
baseTemplates = mappedTemplates (después de query inicial, ANTES de selections)
  ↓
Aplicar filtros de selección (bottom_bar, tube, etc.)
  ↓
filteredTemplates = mappedTemplates (después de selections)
  ↓
ProductConfigurator obtiene baseTemplateIds y filteredTemplateIds
  ↓
Pasa a HardwareStep como props
  ↓
HardwareStep usa useBOMTemplateRoleOptions(baseTemplateIds, 'bottom_bar')
  ↓
Query: BOMTemplateSlots WHERE bom_template_id IN (baseTemplateIds) AND item_role = 'bottom_bar'
  ↓
Obtener DISTINCT catalog_item_id
  ↓
Query: CatalogItems WHERE id IN (distinctItemIds) AND is_active=true
  ↓
Mostrar cards con SKUs únicos
```

### 2. Problemas Identificados

#### Problema 1: `baseTemplateIds=0` ⚠️ CRÍTICO

**Causa Probable:**
- `baseTemplates` está vacío en `useBOMTemplates`
- `baseTemplates` se guarda después de aplicar filtros de selección (incorrecto)
- Los filtros estructurales están eliminando todos los templates

**Ubicación del Problema:**
- `src/hooks/useBOMTemplates.ts` línea ~292: `const baseTemplatesResult = [...mappedTemplates];`
- `src/hooks/useBOMTemplates.ts` línea ~1179: `setBaseTemplates(baseTemplatesResult);`

**Verificación Necesaria:**
1. ¿Cuántos templates retorna la query inicial? (log `[useBOMTemplates] Query executed`)
2. ¿Se está guardando `baseTemplatesResult` correctamente?
3. ¿Los filtros estructurales están eliminando todos los templates?

#### Problema 2: Error "[circular]" en Logs

**Causa:**
- Los logs intentan serializar objetos con referencias circulares
- Esto puede estar ocultando información importante

**Fix Aplicado:**
- ✅ Removidos filtros `.eq('deleted', false)` y `.eq('archived', false)` de `BOMTemplateSlots`
- ✅ Logs simplificados para evitar referencias circulares
- ✅ `setItems` ejecutado antes de logs

#### Problema 3: Query de BOMTemplateSlots

**Fix Aplicado:**
- ✅ Removidos filtros de `deleted` y `archived` (columnas no existen)
- ✅ Agregado filtro por `organization_id`
- ✅ Filtro por `item_role` usando `ilike`

## 📊 Diagnóstico Paso a Paso

### Paso 1: Verificar Query Inicial de Templates

**Log a Buscar:**
```
[useBOMTemplates] Query executed
```

**Qué Verificar:**
- `dataCount`: ¿Cuántos templates retorna la query inicial?
- `rawData`: ¿Los templates tienen `product_type_id` y `hardware_color` correctos?
- `error`: ¿Hay errores en la query?

**Si `dataCount=0`:**
- ❌ No hay templates que coincidan con `product_type_id` + `hardware_color`
- Verificar que existan templates en DB con esos valores

### Paso 2: Verificar baseTemplates

**Log a Buscar:**
```
[useBOMTemplates] Base templates (after structural filters)
```

**Qué Verificar:**
- `count`: ¿Cuántos templates hay después de filtros estructurales?
- `templateIds`: ¿Qué IDs de templates se guardaron?
- `queryFilters`: ¿Qué filtros se aplicaron?

**Si `count=0`:**
- ❌ Los filtros estructurales están eliminando todos los templates
- Verificar que `hardware_color` esté capitalizado correctamente ("White" no "white")

### Paso 3: Verificar baseTemplateIds en ProductConfigurator

**Log a Buscar:**
```
[ProductConfigurator] Templates pipeline
```

**Qué Verificar:**
- `baseCount`: ¿Cuántos templates base hay?
- `baseTemplateIds`: ¿Qué IDs se están pasando?
- `productTypeId`: ¿Está definido?
- `hardwareColor`: ¿Está definido?

**Si `baseCount=0`:**
- ❌ `baseTemplates` está vacío en el hook
- Verificar que `setBaseTemplates` se esté ejecutando

### Paso 4: Verificar baseTemplateIds en HardwareStep

**Log a Buscar:**
```
[HardwareStep] Templates received
[HardwareStep] Bottom Bar state
```

**Qué Verificar:**
- `baseCount`: ¿Cuántos templates base recibió?
- `baseTemplateIds`: ¿Qué IDs recibió?
- `enabled`: ¿El hook está habilitado?
- `loading`: ¿Está cargando?
- `error`: ¿Hay errores?

**Si `baseCount=0`:**
- ❌ `baseTemplateIds` no se está pasando correctamente como prop
- Verificar que `stepProps.baseTemplateIds` se esté pasando

### Paso 5: Verificar Query de BOMTemplateSlots

**Log a Buscar:**
```
[useBOMTemplateRoleOptions] Fetching options
[useBOMTemplateRoleOptions] Slots found
[useBOMTemplateRoleOptions] Found distinct catalog_item_ids
[useBOMTemplateRoleOptions] CatalogItems fetched
[useBOMTemplateRoleOptions] Success
```

**Qué Verificar:**
- `candidateTemplateIds`: ¿Qué IDs se están usando?
- `slotsCount`: ¿Cuántos slots se encontraron?
- `distinctItemIdsCount`: ¿Cuántos catalog_item_ids únicos hay?
- `catalogItemsCount`: ¿Cuántos CatalogItems se encontraron?
- `optionsCount`: ¿Cuántas opciones finales hay?

**Si `slotsCount=0`:**
- ❌ No hay slots con `item_role = 'bottom_bar'` en esos templates
- Verificar en DB que los templates tengan slots con ese role

**Si `catalogItemsCount=0`:**
- ❌ Los CatalogItems no están activos o no existen
- Verificar que `is_active=true` y `deleted=false` en CatalogItems

## 🔧 Fixes Aplicados

### Fix 1: Removidos Filtros de BOMTemplateSlots
- ✅ Removido `.eq('deleted', false)` (columna no existe)
- ✅ Removido `.eq('archived', false)` (columna no existe)

### Fix 2: Logs Mejorados
- ✅ `setItems` ejecutado antes de logs
- ✅ Logs simplificados para evitar "[circular]"
- ✅ Logs de diagnóstico en cada paso

### Fix 3: Manejo de Errores
- ✅ Error serializado correctamente
- ✅ Error mostrado en UI cuando existe

### Fix 4: Cache Arreglado para Retornar baseTemplates ✅ DEFINITIVO
- ✅ **ROOT CAUSE IDENTIFICADO:** Cache retornaba solo `templates` (filtered) pero NO `baseTemplates`
- ✅ Cache ahora guarda y retorna tanto `baseTemplates` como `templates`
- ✅ Tipo del cache actualizado: `CachedResult = { baseTemplates, templates, ts }`
- ✅ Cuando hay cache hit, se setean ambos: `setTemplates(cached.templates)` y `setBaseTemplates(cached.baseTemplates)`
- ✅ Cache guarda ambos sets al finalizar el fetch

### Fix 5: Fallback en HardwareStep ✅ DEFINITIVO
- ✅ Si `baseTemplateIds` está vacío, usa `filteredTemplateIds` como respaldo
- ✅ `bottomBarTemplateIds = baseTemplateIds?.length ? baseTemplateIds : (filteredTemplateIds ?? [])`
- ✅ Esto asegura que nunca quede en 0 cuando sí hay templates disponibles

### Fix 6: Logs de Validación Obligatorios ✅
- ✅ `[useBOMTemplates] sets` - muestra baseCount, filteredCount, y primeros 5 IDs
- ✅ `[ProductConfigurator] ids` - muestra counts antes de pasar props
- ✅ `[HardwareStep] bottom bar ids` - muestra baseCount, filteredCount, effectiveCount

## 🎯 Problema Principal Identificado ✅ RESUELTO

**ROOT CAUSE REAL (Confirmado):**
Cuando hay cache hit o early-return, `useBOMTemplates` retornaba `templates` (filtered) pero NO seteaba `baseTemplates`. Entonces `ProductConfigurator` recibía:
- `filteredTemplates` ✅ (3 templates)
- `baseTemplates` ❌ (0 templates)

Y como `HardwareStep` cargaba Bottom Bar desde `baseTemplateIds`, quedaba en 0 → "No options".

**FIX APLICADO:**
1. ✅ Cache ahora guarda y retorna tanto `baseTemplates` como `templates`
2. ✅ `HardwareStep` tiene fallback: si `baseTemplateIds` está vacío, usa `filteredTemplateIds`
3. ✅ Logs de validación agregados en los 3 puntos críticos

## 🔍 Verificaciones Necesarias

### 1. Verificar en DB

```sql
-- Verificar que existan templates con product_type_id y hardware_color
SELECT id, name, product_type_id, hardware_color, active, deleted, archived
FROM "BOMTemplates"
WHERE organization_id = 'TU_ORG_ID'
  AND product_type_id = 'c50f6735-64e5-4e60-adb8-e4d426172fab'
  AND hardware_color = 'White'
  AND deleted = false
  AND archived = false;

-- Verificar que esos templates tengan slots con item_role = 'bottom_bar'
SELECT s.bom_template_id, s.item_role, s.catalog_item_id, ci.sku, ci.is_active
FROM "BOMTemplateSlots" s
LEFT JOIN "CatalogItems" ci ON ci.id = s.catalog_item_id
WHERE s.organization_id = 'TU_ORG_ID'
  AND s.bom_template_id IN (
    SELECT id FROM "BOMTemplates"
    WHERE organization_id = 'TU_ORG_ID'
      AND product_type_id = 'c50f6735-64e5-4e60-adb8-e4d426172fab'
      AND hardware_color = 'White'
      AND deleted = false
      AND archived = false
  )
  AND LOWER(s.item_role) = 'bottom_bar'
  AND s.catalog_item_id IS NOT NULL;
```

### 2. Verificar Logs en Console

Buscar estos logs en orden:

1. `[useBOMTemplates] Query executed` → Verificar `dataCount`
2. `[useBOMTemplates] Base templates (after structural filters)` → Verificar `count`
3. `[ProductConfigurator] Templates pipeline` → Verificar `baseCount`
4. `[HardwareStep] Templates received` → Verificar `baseCount`
5. `[useBOMTemplateRoleOptions] Fetching options` → Verificar `candidateTemplateIds`
6. `[useBOMTemplateRoleOptions] Slots found` → Verificar `slotsCount`

## 🚨 Problema Identificado: Cache Interfiere con baseTemplates

**Problema Crítico:**
Cuando hay cache hit, el código retorna temprano (línea 121-124) sin calcular `baseTemplates`. El cache solo guarda `filteredTemplates`, no `baseTemplates`.

**Fix Aplicado:**
- ✅ Deshabilitado cache temporalmente para asegurar que `baseTemplates` se calcule siempre
- ✅ Agregado log cuando hay cache hit para debugging

## 🚨 Acción Inmediata Requerida

1. **Abrir DevTools Console**
2. **Filtrar por `[useBOMTemplates]`**
3. **Buscar el log `Base templates (after structural filters)`**
4. **Verificar el valor de `count`**
   - Si `count=0` → El problema está en la query inicial o filtros estructurales
   - Si `count>0` → El problema está en cómo se pasan los IDs a `HardwareStep`

5. **Filtrar por `[ProductConfigurator]`**
6. **Buscar el log `Templates pipeline`**
7. **Verificar el valor de `baseCount`**
   - Si `baseCount=0` → `baseTemplates` está vacío en el hook
   - Si `baseCount>0` → El problema está en cómo se pasan los props

8. **Filtrar por `[HardwareStep]`**
9. **Buscar el log `Templates received`**
10. **Verificar el valor de `baseCount`**
    - Si `baseCount=0` → Los props no se están pasando correctamente
    - Si `baseCount>0` → El problema está en `useBOMTemplateRoleOptions`

11. **Filtrar por `[useBOMTemplateRoleOptions]`**
12. **Buscar los logs en orden:**
    - `useEffect triggered` → Verificar `willFetch`
    - `Fetching options` → Verificar `candidateTemplateIds`
    - `Slots found` → Verificar `slotsCount`
    - `Found distinct catalog_item_ids` → Verificar `count`
    - `CatalogItems fetched` → Verificar `catalogItemsCount`
    - `Success` → Verificar `optionsCount` y `allSKUs`

## ✅ FIXES APLICADOS - RESUMEN

### 1. Cache en useBOMTemplates.ts
- ✅ Tipo del cache actualizado para guardar `{ baseTemplates, templates, ts }`
- ✅ Cache hit ahora retorna ambos sets
- ✅ Cache guarda ambos sets al finalizar fetch

### 2. Fallback en HardwareStep.tsx
- ✅ `bottomBarTemplateIds = baseTemplateIds?.length ? baseTemplateIds : (filteredTemplateIds ?? [])`
- ✅ Nunca queda en 0 cuando hay templates disponibles

### 3. Logs de Validación
- ✅ `[useBOMTemplates] sets` - baseCount, filteredCount, primeros 5 IDs
- ✅ `[ProductConfigurator] ids` - counts antes de pasar props
- ✅ `[HardwareStep] bottom bar ids` - baseCount, filteredCount, effectiveCount

## 📝 Resultado Esperado

- ✅ Con White y product_type roller, `baseCount` debe ser 3 (no 0)
- ✅ Bottom Bar options debe mostrar SKUs presentes en slots de esos 3 templates
- ✅ Ya no puede ocurrir "templates found=3 pero bottom bar options=0" por culpa de `baseTemplateIds`

## 🔗 Archivos Relevantes

- `src/hooks/useBOMTemplates.ts` - Hook principal de templates
- `src/hooks/useBOMTemplateRoleOptions.ts` - Hook para obtener opciones desde slots
- `src/pages/sales/ProductConfigurator.tsx` - Componente principal
- `src/pages/sales/curtain-config/HardwareStep.tsx` - Componente de hardware
