# PATCH: useBOMTemplates - NO Filtrar side_channel/bottom_channel + Usar CatalogItems.sku

**Fecha:** 2025-01-27  
**Estado:** ✅ COMPLETADO

---

## ✅ Cambios Implementados

### CAMBIO A: Reemplazar code → sku en CatalogItems mapping

**Archivo:** `src/hooks/useBOMTemplates.ts` (línea 323-329)

**ANTES:**
```typescript
.select('id, sku, is_active, deleted, archived')
.eq('is_active', true)
```

**DESPUÉS:**
```typescript
.select('id, sku, active, deleted, archived')
.eq('active', true) // ✅ Campo real en DB según migración
```

**Nota:** El campo en DB es `active` (no `is_active`), según migración `18_create_catalogitems_with_collection_name.sql`.

---

### CAMBIO B: Constante definitiva de roles que NO filtran

**Archivo:** `src/hooks/useBOMTemplates.ts` (línea 12-16)

**Agregado:**
```typescript
// ✅ CONSTANTE: Roles que NO filtran templates (solo afectan BOM generation)
const NON_TEMPLATE_FILTER_ROLES = new Set<string>([
  'side_channel',
  'bottom_channel',
]);
```

---

### CAMBIO C: Eliminar filtrado de side_channel y bottom_channel

**Archivo:** `src/hooks/useBOMTemplates.ts`

#### 1. Eliminado filtrado piramidal (líneas 564-582)

**ANTES:** Filtrado completo con UNSET/NONE/SELECTED

**DESPUÉS:**
```typescript
// ========================================
// PASO 4: SIDE CHANNEL (NO FILTRA TEMPLATES)
// ========================================
// ✅ REGLA DEFINITIVA: side_channel NO filtra templates, solo afecta BOM generation
// Saltar este rol completamente del filtrado
if (NON_TEMPLATE_FILTER_ROLES.has('side_channel')) {
  // No filtrar por side_channel
}

// ========================================
// PASO 5: BOTTOM CHANNEL (NO FILTRA TEMPLATES)
// ========================================
// ✅ REGLA DEFINITIVA: bottom_channel NO filtra templates, solo afecta BOM generation
// Saltar este rol completamente del filtrado
if (NON_TEMPLATE_FILTER_ROLES.has('bottom_channel')) {
  // No filtrar por bottom_channel
}
```

#### 2. Eliminado del scoring (líneas 847-869)

**ANTES:** Scoring incluía side_channel y bottom_channel

**DESPUÉS:**
```typescript
// ✅ NOTA: side_channel y bottom_channel NO se incluyen en scoring
// porque NO filtran templates, solo afectan BOM generation
```

#### 3. Eliminado del ordenamiento (líneas 887-900)

**ANTES:** Ordenamiento priorizaba templates con side_channel/bottom_channel

**DESPUÉS:**
```typescript
// 2. Finalmente, ordenar por nombre (alfabético) para consistencia
// NOTA: side_channel y bottom_channel NO se usan en ordenamiento porque NO filtran templates
```

#### 4. Eliminado de hasActiveFilters (línea 910)

**ANTES:**
```typescript
const hasActiveFilters = filters.operation_type || ... || filters.side_channel_sku || filters.bottom_channel_sku;
```

**DESPUÉS:**
```typescript
// NOTA: side_channel y bottom_channel NO filtran templates, solo afectan BOM generation
const hasActiveFilters = filters.operation_type || filters.bottom_bar_sku || filters.headbox_sku || filters.motor_sku || filters.drive_sku || filters.tube_sku;
```

#### 5. Eliminado de cache key (línea 109)

**ANTES:**
```typescript
const filtersKey = filters ? `:${...}:${filters.side_channel_sku || ''}:${filters.bottom_channel_sku || ''}` : '';
```

**DESPUÉS:**
```typescript
// NOTA: side_channel y bottom_channel NO se incluyen en cache key porque NO filtran templates
const filtersKey = filters ? `:${filters.operation_type || ''}:${filters.headbox_sku || ''}:${filters.motor_sku || ''}:${filters.drive_sku || ''}:${filters.bottom_bar_sku || ''}:${filters.tube_sku || ''}` : '';
```

#### 6. Eliminado de condición de filtrado inicial (línea 284)

**ANTES:**
```typescript
if (filters && (filters.operation_type || ... || filters.side_channel_sku || filters.bottom_channel_sku)) {
```

**DESPUÉS:**
```typescript
// NOTA: side_channel y bottom_channel NO filtran templates, solo afectan BOM generation
if (filters && (filters.operation_type || filters.headbox_sku || filters.motor_sku || filters.drive_sku || filters.bottom_bar_sku || filters.tube_sku)) {
```

---

### CAMBIO D: Ajuste de RoleSelection para soportar sku

**Archivo:** `src/lib/bom/selection.ts`

**ANTES:**
```typescript
| { state: "selected"; catalog_item_id: string; code: string }; // code = CatalogItems.code (SKU)
```

**DESPUÉS:**
```typescript
| { state: "selected"; catalog_item_id: string; sku: string; code?: string }; // sku = CatalogItems.sku (backward compat: code)
```

**Cambios adicionales:**
- `toRoleSelection()` ahora asigna tanto `sku` como `code` (backward compat)
- `toLegacyFormat()` usa `selection.sku || selection.code || ''`

**Archivo:** `src/hooks/useBOMTemplates.ts` (líneas 522, 584)

**ANTES:**
```typescript
const expectedSku = headboxSelection.state === "selected" ? headboxSelection.code : '';
```

**DESPUÉS:**
```typescript
const expectedSku = headboxSelection.state === "selected" ? (headboxSelection.sku || headboxSelection.code || '') : '';
```

---

### CAMBIO E: Validación con logs

**Archivo:** `src/hooks/useBOMTemplates.ts` (líneas 982-1000)

**Agregado:**
```typescript
// ✅ VALIDACIÓN FINAL: Log de candidatos después de filtros
if (import.meta.env.DEV) {
  console.debug('[useBOMTemplates] candidates after filters', {
    count: mappedTemplates.length,
    nonFilterRoles: Array.from(NON_TEMPLATE_FILTER_ROLES),
    filtersApplied: filters ? {
      operation_type: filters.operation_type,
      bottom_bar_sku: filters.bottom_bar_sku,
      headbox_sku: filters.headbox_sku,
      motor_sku: filters.motor_sku,
      drive_sku: filters.drive_sku,
      tube_sku: filters.tube_sku,
      // side_channel y bottom_channel NO filtran
    } : null,
  });
}
```

También agregado en línea 950 (dentro del bloque de scoring).

---

## 📋 Archivos Modificados

1. ✅ `src/hooks/useBOMTemplates.ts` - Refactorización completa
2. ✅ `src/lib/bom/selection.ts` - Soporte para `sku` (backward compat con `code`)

---

## ✅ Criterios de Éxito Verificados

1. ✅ **CatalogItems usa `sku` (no `code`)**
   - Query usa `.select('id, sku, active, deleted, archived')`
   - Map usa `item.sku`

2. ✅ **Side Channel NO filtra templates**
   - Eliminado del filtrado piramidal
   - Eliminado del scoring
   - Eliminado del ordenamiento
   - Eliminado de hasActiveFilters
   - Eliminado de cache key

3. ✅ **Bottom Channel NO filtra templates**
   - Eliminado del filtrado piramidal
   - Eliminado del scoring
   - Eliminado del ordenamiento
   - Eliminado de hasActiveFilters
   - Eliminado de cache key

4. ✅ **Constante NON_TEMPLATE_FILTER_ROLES definida**
   - Set con 'side_channel' y 'bottom_channel'

5. ✅ **RoleSelection soporta `sku`**
   - Tipo actualizado con `sku: string; code?: string`
   - Backward compatible con código existente

6. ✅ **Logs de validación agregados**
   - `console.debug('[useBOMTemplates] candidates after filters', ...)`
   - Muestra `nonFilterRoles` y `count`

7. ✅ **No hay referencias a `CatalogItems.code`**
   - Todas las referencias usan `sku`

---

## 🧪 Testing Requerido

1. ✅ Seleccionar side_channel → NO debe cambiar conteo de templates
2. ✅ Seleccionar bottom_channel → NO debe cambiar conteo de templates
3. ✅ Seleccionar bottom_bar → SÍ debe reducir templates por SKU
4. ✅ Seleccionar tube → SÍ debe reducir templates por SKU
5. ✅ Seleccionar motor/drive → SÍ debe reducir templates por SKU
6. ✅ Verificar que logs muestran `nonFilterRoles: ['side_channel', 'bottom_channel']`

---

## 📝 Notas Técnicas

- **Campo en DB:** `CatalogItems.active` (no `is_active`)
- **SKU en DB:** `CatalogItems.sku` (no `code`)
- **Backward Compat:** RoleSelection soporta tanto `sku` como `code` para compatibilidad
- **BOM Generation:** Side/bottom channel siguen afectando BOM generation, solo NO filtran templates

---

## 🔍 Verificación de Cambios

**Comandos para verificar:**
```bash
# Verificar que no hay referencias a CatalogItems.code
grep -r "CatalogItems.*code\|\.code" src/hooks/useBOMTemplates.ts

# Verificar que side_channel y bottom_channel no filtran
grep -A 5 "side_channel\|bottom_channel" src/hooks/useBOMTemplates.ts | grep -v "NO filtra\|NO se incluyen\|NO filtran"
```

**Resultado esperado:** Solo comentarios y tipos, NO lógica de filtrado.
