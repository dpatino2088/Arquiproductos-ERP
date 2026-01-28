# PATCH: SKU Resolution Fix - COMPLETADO

## 🎯 Objetivo del Patch

**Asegurar que el SKU real siempre llegue al filtro de templates**
- El problema: `bottom_bar_sku` no estaba llegando correctamente desde la UI al hook `useBOMTemplates`
- La causa: Lógica legacy que podía usar `code` en vez de `sku`, o estado que no se guardaba correctamente

## ✅ Cambios Implementados

### 1. Helper `getSelectionSku()` en `selection.ts`

```typescript
export function getSelectionSku(s?: RoleSelection | null): string | undefined {
  if (!s || s.state !== "selected") return undefined;
  
  // ✅ Priorizar sku, luego code (backward compat), luego nada
  const v = (s.sku || (s as any).code || "").trim();
  return v.length > 0 ? v : undefined;
}
```

**Propósito:**
- Extrae el SKU real de una `RoleSelection`
- Blindaje para legacy `code` (backward compat)
- Siempre retorna `undefined` si no hay SKU válido

### 2. Mejora de `toRoleSelection()` en `selection.ts`

**Antes:**
- No manejaba explícitamente el caso `sku === null && catalog_item_id === null` como NONE

**Después:**
- ✅ Caso especial: `sku === null && catalog_item_id === null` → `NONE` (explícito)
- ✅ Valida que `cleanSku` y `catalog_item_id` existan antes de crear `SELECTED`
- ✅ Más robusto contra valores vacíos/undefined

### 3. Actualización de `ProductConfigurator.tsx`

**Cambios:**
- ✅ Importa `getSelectionSku` desde `selection.ts`
- ✅ Convierte `bottom_bar_sku` y `tube_sku` a `RoleSelection` usando `toRoleSelection()`
- ✅ Usa `getSelectionSku()` para extraer SKU real en `templateFilters`
- ✅ Agrega log de debug crítico antes de llamar a `useBOMTemplates`:

```typescript
console.debug("[ProductConfigurator] bottom bar selection", {
  raw_config: {
    bottom_bar_sku: bottomBarSkuValue,
    bottom_bar_item_id: bottomBarItemIdValue,
  },
  roleSelection: bottomBarSelection,
  resolvedSku: bottomBarSku,
});
```

**Resultado esperado:**
- `resolvedSku: "RCA-04-W"` cuando se selecciona Bottom Bar
- `resolvedSku: undefined` cuando está UNSET

### 4. Logs de Debug en `useBOMTemplates.ts`

**Agregados dos logs críticos:**

1. **Antes del filtro de bottom_bar:**
```typescript
console.debug("[useBOMTemplates] bottom_bar filter input", {
  bottom_bar_sku: filters?.bottom_bar_sku,
  bottom_bar_item_id: filters?.bottom_bar_item_id,
  hasSlots: slotsByTemplate.size,
  templateCountBefore: mappedTemplates.length,
  currentTemplateId: template.id,
  currentTemplateName: template.name,
});
```

2. **Dentro del match de SKU:**
```typescript
console.debug("[useBOMTemplates] bottom_bar match", {
  template_id: template.id,
  template_name: template.name,
  expectedSku,
  slotSku,
  matches,
  item_role: slot.item_role,
  catalog_item_id: slot.catalog_item_id,
  sampleSlots: sample.map(x => ({
    sku: x.sku || 'NO_SKU',
    catalog_item_id: x.catalog_item_id,
    item_role: x.item_role,
  })),
});
```

### 5. Blindaje en `HardwareStep.tsx`

**Agregado log de debug al seleccionar Bottom Bar:**
```typescript
console.debug("[HardwareStep] Bottom Bar selected", {
  item_id: item.id,
  item_sku: item.sku,
  item_name: item.name,
  skuToSave,
});
```

**Asegura:**
- Siempre se guarda `item.sku` (nunca `code`)
- Se hace `trim()` para limpiar espacios
- Log para validar qué se está guardando

## 📁 Archivos Modificados

1. `src/lib/bom/selection.ts`
   - Agregado `getSelectionSku()` helper
   - Mejorado `toRoleSelection()` para manejar `null/null` explícito

2. `src/pages/sales/ProductConfigurator.tsx`
   - Usa `getSelectionSku()` para `bottom_bar_sku` y `tube_sku`
   - Agregado log de debug crítico

3. `src/hooks/useBOMTemplates.ts`
   - Agregados logs de debug antes y durante el filtro de bottom_bar

4. `src/pages/sales/curtain-config/HardwareStep.tsx`
   - Agregado log de debug al seleccionar Bottom Bar

## 🧪 Validación con Logs

### Paso 1: Seleccionar Bottom Bar en UI

**En DevTools Console, buscar:**
```
[HardwareStep] Bottom Bar selected
```

**Resultado esperado:**
```javascript
{
  item_id: "57c04500-3931-44fd-9272-05e199f1b6c2",
  item_sku: "RCA-04-W",
  item_name: "Bottom Bar",
  skuToSave: "RCA-04-W"
}
```

### Paso 2: Verificar que llega a ProductConfigurator

**En DevTools Console, buscar:**
```
[ProductConfigurator] bottom bar selection
```

**Resultado esperado:**
```javascript
{
  raw_config: {
    bottom_bar_sku: "RCA-04-W",
    bottom_bar_item_id: "57c04500-3931-44fd-9272-05e199f1b6c2"
  },
  roleSelection: { state: "selected", sku: "RCA-04-W", catalog_item_id: "..." },
  resolvedSku: "RCA-04-W"  // ✅ ESTO ES CRÍTICO: debe ser string, no undefined
}
```

**Si `resolvedSku: undefined` → El bug está aquí**

### Paso 3: Verificar que llega al hook

**En DevTools Console, buscar:**
```
[useBOMTemplates] bottom_bar filter input
```

**Resultado esperado:**
```javascript
{
  bottom_bar_sku: "RCA-04-W",  // ✅ Debe ser string, no undefined
  bottom_bar_item_id: "57c04500-3931-44fd-9272-05e199f1b6c2",
  hasSlots: 10,
  templateCountBefore: 10,
  currentTemplateId: "...",
  currentTemplateName: "..."
}
```

**Si `bottom_bar_sku: undefined` → El bug está en ProductConfigurator**

### Paso 4: Verificar el match

**En DevTools Console, buscar:**
```
[useBOMTemplates] bottom_bar match
```

**Resultado esperado:**
```javascript
{
  template_id: "...",
  template_name: "...",
  expectedSku: "RCA-04-W",
  slotSku: "RCA-04-W",
  matches: true,  // ✅ Debe ser true
  item_role: "bottom_bar",
  catalog_item_id: "...",
  sampleSlots: [...]
}
```

**Si `matches: false` → Verificar que `expectedSku === slotSku`**

## 🔍 Diagnóstico Rápido

### Si `resolvedSku: undefined` en ProductConfigurator:

1. Verificar que `HardwareStep` está guardando `item.sku` correctamente
2. Verificar que `config.bottom_bar_sku` tiene valor en el estado
3. Verificar que `toRoleSelection()` está retornando `SELECTED` correctamente

### Si `bottom_bar_sku: undefined` en useBOMTemplates:

1. Verificar que `getSelectionSku(bottomBarSelection)` retorna string
2. Verificar que `templateFilters.bottom_bar_sku` se está pasando correctamente

### Si `matches: false` en el match:

1. Verificar que `expectedSku` y `slotSku` son exactamente iguales (case-sensitive)
2. Verificar que `slot.sku` existe y no es `null`
3. Verificar que `CatalogItems.is_active = true` para el item

## ✅ Estado

- [x] Helper `getSelectionSku()` agregado
- [x] `toRoleSelection()` mejorado
- [x] `ProductConfigurator.tsx` usa `getSelectionSku()`
- [x] Logs de debug agregados en todos los puntos críticos
- [x] Blindaje en `HardwareStep.tsx`
- [ ] Validación en UI (pendiente usuario)

## 📝 Notas Técnicas

- **SKU vs Code**: El campo real en DB es `CatalogItems.sku`, nunca `code`
- **Backward Compat**: `getSelectionSku()` acepta `code` por si acaso, pero siempre prioriza `sku`
- **Estado UNSET**: Cuando `bottom_bar_sku` es `undefined` o `''`, el filtro NO se aplica (templates siguen apareciendo)
- **Estado SELECTED**: Cuando `bottom_bar_sku` es string válido, el filtro se aplica por SKU exacto
