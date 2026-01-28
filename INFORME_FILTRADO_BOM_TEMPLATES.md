# INFORME DETALLADO: Problema de Filtrado de BOM Templates

**Fecha:** 2025-01-27  
**Problema:** Filtrado piramidal de BOM Templates retorna 0 templates después de seleccionar Bottom Bar  
**Estado:** 🔴 CRÍTICO - Bloquea creación de Quote Lines

---

## 1. DIAGNÓSTICO DEL PROBLEMA

### 1.1 Síntoma Observado
- **Antes de seleccionar Bottom Bar:** Templates encontrados correctamente
- **Después de seleccionar Bottom Bar:** `0 template(s) found`
- **Resultado:** `BOM Template ID: Not resolved` → No se puede crear Quote Line

### 1.2 Causa Raíz Identificada

#### Problema Principal: Uso Incorrecto de `slot.sku`
El código actual en `src/hooks/useBOMTemplates.ts` está intentando acceder a `slot.sku` en múltiples lugares (28 ocurrencias encontradas), pero:

**❌ REALIDAD DE LA BASE DE DATOS:**
- `BOMTemplateSlots` **NO tiene columna `sku`**
- `BOMTemplateSlots` tiene: `bom_template_id`, `item_role`, `catalog_item_id`, `required`, `qty`, `notes`
- El SKU real está en `CatalogItems.code` (relacionado a través de `catalog_item_id`)

**✅ CÓDIGO ACTUAL (parcialmente correcto):**
- Líneas 314-336: SÍ obtiene SKUs de `CatalogItems` y crea un `catalogItemsMap`
- Línea 362: SÍ guarda el SKU en el objeto slot: `sku: catalogItemSku`
- **PERO:** El problema es que `catalogItemSku` puede ser `null` o `undefined` si:
  - El `catalog_item_id` no existe en `CatalogItems`
  - El `CatalogItem` está `deleted=true` o `archived=true`
  - El `CatalogItem` no tiene `code` (SKU)

#### Problema Secundario: Filtrado por Rol Incorrecto
El código intenta filtrar por roles normalizados con heurísticas:
```typescript
const isBottomBarSlot = 
  slotRole === 'bottom_bar' || 
  slotRole === 'bottom bar' ||
  slotRole.includes('bottom') && (slotRole.includes('bar') || slotRole.includes('rail'));
```

**❌ PROBLEMA:** Esto puede fallar si:
- El `item_role` en DB es exactamente `"bottom_bar"` pero la normalización lo cambia
- Hay variaciones en naming que no se capturan
- Se compara con roles que no existen

#### Problema Terciario: Falta de Validación de Obligatoriedad
El código no consulta `ProductTypeRoleRules` para saber qué roles son obligatorios/opcionales, entonces:
- Filtra por roles opcionales cuando el usuario no los ha seleccionado
- No valida que roles obligatorios estén presentes

---

## 2. ANÁLISIS DEL CÓDIGO ACTUAL

### 2.1 Flujo Actual (src/hooks/useBOMTemplates.ts)

```
1. Carga templates base:
   - BOMTemplates where organization_id, product_type_id, hardware_color
   - ✅ CORRECTO

2. Si hay filtros adicionales:
   - Carga BOMTemplateSlots (línea 290-294)
   - ✅ CORRECTO: select('bom_template_id, item_role, catalog_item_id')

3. Obtiene SKUs de CatalogItems (línea 314-336):
   - ✅ CORRECTO: Crea catalogItemsMap[id] = sku

4. Agrupa slots por template (línea 339-364):
   - ✅ CORRECTO: Guarda sku en slot.sku
   - ⚠️ PROBLEMA: Si catalogItemSku es null, slot.sku será null

5. Filtrado piramidal (línea 377+):
   - ❌ PROBLEMA: Usa slot.sku directamente sin validar null
   - ❌ PROBLEMA: Normaliza roles con heurísticas
   - ❌ PROBLEMA: No consulta ProductTypeRoleRules
```

### 2.2 Puntos de Falla Específicos

#### Falla #1: Línea 425 (Bottom Bar)
```typescript
const slotSku = (slot.sku || '').trim();
return slotSku && slotSku === expectedSku;
```
**Problema:** Si `slot.sku` es `null` (porque el CatalogItem no existe o está inactivo), el filtro falla silenciosamente.

#### Falla #2: Normalización de Roles
```typescript
const slotRole = normalizeRole(slot.role) || slot.role?.toLowerCase() || '';
const isBottomBarSlot = slotRole === 'bottom_bar' || ...
```
**Problema:** Depende de `normalizeRole()` que puede no capturar todas las variaciones.

#### Falla #3: No Valida CatalogItem Activo
El código obtiene SKUs de `CatalogItems` pero NO filtra por `active=true, deleted=false, archived=false`.

---

## 3. SOLUCIÓN REQUERIDA

### 3.1 Cambios Necesarios

#### A) Cargar ProductTypeRoleRules
```typescript
const { data: roleRules } = await supabase
  .from('ProductTypeRoleRules')
  .select('role_code, is_required')
  .eq('organization_id', activeOrganizationId)
  .eq('product_type_id', productTypeId)
  .eq('active', true)
  .eq('deleted', false)
  .eq('archived', false);
```

#### B) Cargar CatalogItems con Validación
```typescript
const { data: catalogItemsData } = await supabase
  .from('CatalogItems')
  .select('id, code, active, deleted, archived')
  .eq('organization_id', activeOrganizationId)
  .in('id', catalogItemIds)
  .eq('active', true)
  .eq('deleted', false)
  .eq('archived', false);
```

**✅ USAR `code` NO `sku`:** Según el usuario, el SKU está en `CatalogItems.code`.

#### C) Filtrado Piramidal Correcto
```typescript
// Para cada rol en orden: bottom_bar, headbox, side_channel, drive/motor, tube
for (const role of roleOrder) {
  const roleRule = roleRules.find(r => r.role_code === role);
  const isRequired = roleRule?.is_required ?? false;
  const userSelection = getUserSelectionForRole(role);
  
  if (isRequired && !userSelection) {
    // Excluir template si rol es obligatorio y usuario no lo seleccionó
    return false;
  }
  
  if (!userSelection) {
    // Si rol es opcional y no seleccionado, no filtrar
    continue;
  }
  
  // Buscar slot con item_role exacto (sin normalización)
  const matchingSlot = templateSlotsList.find(slot => 
    slot.item_role === role && 
    slot.catalog_item_id && 
    catalogItemsMap.get(slot.catalog_item_id) === userSelection.sku
  );
  
  if (!matchingSlot) {
    return false; // Template no tiene este rol con este SKU
  }
}
```

#### D) Side Channel + Bottom Channel
- `bottom_channel_sku` se deriva automáticamente de `side_channel_sku`
- `bottom_channel` NO filtra templates (solo afecta BOM generation)
- Si `side_channel=null` → `bottom_channel=null`

---

## 4. ARCHIVOS A MODIFICAR

### 4.1 Archivo Principal
- **`src/hooks/useBOMTemplates.ts`** (refactorización completa del filtrado)

### 4.2 Archivos de Soporte (si es necesario)
- **`src/lib/bom/roles.ts`** (verificar `normalizeRole()`)
- **`src/pages/sales/ProductConfigurator.tsx`** (ajustar cómo se pasan filtros)

---

## 5. IMPLEMENTACIÓN PROPUESTA

### 5.1 Estructura de Datos
```typescript
interface SlotWithCatalogItem {
  bom_template_id: string;
  item_role: string; // EXACTO de DB, sin normalizar
  catalog_item_id: string | null;
  catalog_item_code: string | null; // SKU real de CatalogItems.code
  catalog_item_active: boolean;
}

interface RoleRule {
  role_code: string;
  is_required: boolean;
}
```

### 5.2 Orden de Filtrado Piramidal
```
1. Color (hardware_color) - ya aplicado en query inicial
2. Bottom bar (obligatorio si is_required=true en ProductTypeRoleRules)
3. Headbox (opcional, bidireccional)
4. Side channel (opcional, bidireccional)
5. Bottom channel (NO filtra, solo deriva de side_channel)
6. Operating type (obligatorio, bidireccional)
7. Tube (obligatorio si is_required=true)
```

### 5.3 Logging Mejorado
```typescript
console.debug('[useBOMTemplates] FASE 1 - Base candidates:', {
  count: baseTemplates.length,
  ids: baseTemplates.map(t => t.id)
});

console.debug('[useBOMTemplates] FASE 2 - Role rules:', roleRules);

console.debug('[useBOMTemplates] FASE 3 - After bottom_bar filter:', {
  count: filteredTemplates.length,
  ids: filteredTemplates.map(t => t.id)
});
// ... para cada paso del filtrado
```

---

## 6. TESTING REQUERIDO

### 6.1 Casos de Prueba
1. ✅ Templates encontrados antes de seleccionar Bottom Bar
2. ✅ Templates encontrados después de seleccionar Bottom Bar (SKU válido)
3. ✅ 0 templates si Bottom Bar es obligatorio y no está seleccionado
4. ✅ Templates filtrados correctamente por Operating Type (motor vs manual)
5. ✅ Side Channel "None" excluye templates con side_channel
6. ✅ Bottom Channel se deriva de Side Channel
7. ✅ CatalogItems inactivos/deleted no aparecen en filtrado

### 6.2 Validación de Datos
- Verificar que `ProductTypeRoleRules` tiene datos para el `product_type_id`
- Verificar que `CatalogItems.code` contiene los SKUs correctos
- Verificar que `BOMTemplateSlots.item_role` coincide exactamente con `ProductTypeRoleRules.role_code`

---

## 7. RIESGOS Y MITIGACIONES

### 7.1 Riesgo: ProductTypeRoleRules Vacío
**Mitigación:** Si no hay reglas, asumir que todos los roles son opcionales (comportamiento actual).

### 7.2 Riesgo: CatalogItems sin `code`
**Mitigación:** Excluir slots donde `catalog_item_code` es null/empty del filtrado.

### 7.3 Riesgo: Performance (múltiples queries)
**Mitigación:** Usar `select()` con joins cuando sea posible, cachear `ProductTypeRoleRules` por `product_type_id`.

---

## 8. IMPLEMENTACIÓN COMPLETADA

### 8.1 Cambios Realizados

1. ✅ **Validación de CatalogItems Activos**
   - Filtrado por `active=true, deleted=false, archived=false`
   - Solo se incluyen CatalogItems con SKU válido en el map

2. ✅ **Uso de `item_role` Exacto**
   - Guardado `item_role` exacto de DB (sin normalizar) en cada slot
   - Comparación exacta primero, luego normalizada como fallback
   - Eliminado uso de `slot.role` (que no existía)

3. ✅ **Filtrado Mejorado por Rol**
   - Bottom Bar: Busca `item_role === 'bottom_bar'` exacto primero
   - Headbox: Busca `item_role === 'headbox'` o `'cassette'` exacto
   - Side Channel: Busca `item_role === 'side_channel'` exacto
   - Bottom Channel: Solo filtra si es "None" (no filtra si tiene valor)
   - Operating Type: Busca `item_role === 'motor'` o `'drive'` exacto
   - Tube: Busca `item_role === 'tube'` exacto

4. ✅ **Logging Mejorado**
   - Muestra `item_role` exacto y `role_normalized`
   - Indica cuántos slots tienen SKU vs sin SKU
   - Logs detallados por cada paso del filtrado

5. ✅ **Estructura de Datos Actualizada**
   ```typescript
   interface Slot {
     item_role: string;        // EXACTO de DB
     role_normalized: string;  // Para matching flexible
     catalog_item_id: string | null;
     sku: string | null;       // null si CatalogItem inactivo
   }
   ```

### 8.2 Archivos Modificados

- ✅ `src/hooks/useBOMTemplates.ts` (refactorización completa del filtrado)

### 8.4 Sistema de Selección de Roles (PASO 1.2 - COMPLETADO)

✅ **Implementado sistema de tres estados para selección de roles:**

1. **UNSET**: No se ha seleccionado nada → No aplica filtro
2. **SELECTED**: Se seleccionó un item específico → Filtra por SKU exacto
3. **NONE**: Se seleccionó explícitamente "ninguno" → Excluye templates con ese rol

**Archivos creados:**
- ✅ `src/lib/bom/selection.ts` - Tipos y helpers para RoleSelection

**Archivos modificados:**
- ✅ `src/hooks/useBOMTemplates.ts` - Refactorizado para usar RoleSelection en:
  - Headbox (opcional)
  - Side Channel (opcional)
  - Bottom Channel (opcional)

**Lógica implementada:**
```typescript
// UNSET: no filtrar
if (isUnset(selection)) {
  // continuar al siguiente paso
}

// NONE: excluir templates con rol (con SKU activo)
if (isNone(selection)) {
  const hasRoleWithSku = slots.some(s => s.item_role === role && !!s.sku);
  if (hasRoleWithSku) return false; // Excluir template
}

// SELECTED: filtrar por SKU exacto
if (isSelected(selection)) {
  const hasMatch = slots.some(s => 
    s.item_role === role && s.sku === selection.code
  );
  if (!hasMatch) return false; // Excluir template
}
```

### 8.5 Próximos Pasos

1. ⏳ Probar con datos reales
2. ⏳ Validar que no rompe funcionalidad existente
3. ⏳ Implementar UI para "Quitar selección" y "None" en ProductConfigurator
4. ⏳ Considerar agregar soporte para `ProductTypeRoleRules` (si existe en DB)
5. ⏳ Aplicar RoleSelection a roles obligatorios (bottom_bar, tube, operating_type)

---

**Notas Finales:**
- El problema es crítico porque bloquea la creación de Quote Lines
- La solución requiere cambios estructurales en el filtrado, no solo parches
- Es importante mantener compatibilidad con el flujo existente de `ProductConfigurator`
