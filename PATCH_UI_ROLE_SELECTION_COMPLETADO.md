# PATCH: UI RoleSelection (unset/none/selected) + Botones "Quitar" y "Ninguno"

**Fecha:** 2025-01-27  
**Estado:** ✅ COMPLETADO

---

## ✅ Cambios Implementados

### A) Tipos y Helpers en HardwareStep

**Archivo:** `src/pages/sales/curtain-config/HardwareStep.tsx`

**Agregado:**
- Import de `RoleSelection`, `isUnset`, `isNone`, `isSelected`, `toRoleSelection`
- Conversión de config legacy a RoleSelection para headbox, side_channel, bottom_channel
- Helpers UI:
  - `setHeadboxNone()` → `{state:"none"}`
  - `clearHeadboxSelection()` → `{state:"unset"}` (usa string vacío)
  - `setHeadboxSelected(item)` → `{state:"selected", catalog_item_id, sku}`

### B) UI Headbox: Botones "Quitar" y "Ninguno"

**Archivo:** `src/pages/sales/curtain-config/HardwareStep.tsx` (líneas 310-325)

**Agregado:**
```tsx
<div className="flex gap-2 mb-3">
  <button
    type="button"
    onClick={clearHeadboxSelection}
    className={isUnset(headboxSelection) ? "bg-primary text-white" : "bg-white text-gray-700"}
  >
    Quitar selección
  </button>
  <button
    type="button"
    onClick={setHeadboxNone}
    className={isNone(headboxSelection) ? "bg-primary text-white" : "bg-white text-gray-700"}
  >
    Sin headbox
  </button>
</div>
```

**Cambios en cards:**
- Eliminado card "None" estático
- Cards ahora usan `isSelected(headboxSelection) && headboxSelection.catalog_item_id === item.id`
- `onClick` usa `setHeadboxSelected({ id, sku })`

### C) Filtros en ProductConfigurator

**Archivo:** `src/pages/sales/ProductConfigurator.tsx` (líneas 231-280)

**Agregado:**
- Conversión de config legacy a RoleSelection
- Lógica para distinguir UNSET vs NONE:
  - `headbox_sku === null && headbox_item_id === null` → NONE
  - `headbox_sku === undefined || headbox_sku === ''` → UNSET
  - `headbox_sku === string válido` → SELECTED

**Filtros pasados a useBOMTemplates:**
```typescript
headbox_sku: headboxSku, // null = NONE, undefined = UNSET, string = SELECTED
```

### D) Actualización de toRoleSelection

**Archivo:** `src/lib/bom/selection.ts`

**Mejorado:**
- Ahora acepta `undefined` explícitamente
- Maneja correctamente `null` vs `undefined` vs string vacío

---

## 📋 Archivos Modificados

1. ✅ `src/pages/sales/curtain-config/HardwareStep.tsx` - UI con botones y helpers
2. ✅ `src/pages/sales/ProductConfigurator.tsx` - Conversión a RoleSelection y filtros
3. ✅ `src/lib/bom/selection.ts` - Soporte mejorado para undefined

---

## ✅ Comportamiento Esperado

### Headbox en UNSET
- Botón "Quitar selección" activo (primary)
- Botón "Sin headbox" inactivo
- **Resultado:** Templates NO cambian (no filtra)

### Headbox en NONE
- Botón "Quitar selección" inactivo
- Botón "Sin headbox" activo (primary)
- **Resultado:** Templates excluyen los que tengan headbox con SKU activo

### Headbox en SELECTED
- Ambos botones inactivos
- Card del item seleccionado activo (primary border)
- **Resultado:** Templates filtran por SKU exacto

### Side/Bottom Channel
- Cambian la config pero NO cambian template count
- Se guardan para BOM generation

---

## 🧪 Testing Requerido

1. ✅ Click "Quitar selección" → Headbox en UNSET → Templates no cambian
2. ✅ Click "Sin headbox" → Headbox en NONE → Templates excluyen con headbox
3. ✅ Click card de headbox → Headbox en SELECTED → Templates filtran por SKU
4. ✅ Seleccionar side_channel → NO cambia template count
5. ✅ Seleccionar bottom_channel → NO cambia template count

---

## 📝 Notas Técnicas

- **UNSET:** `headbox_sku = ''` (string vacío) o `undefined`
- **NONE:** `headbox_sku = null` y `headbox_item_id = null`
- **SELECTED:** `headbox_sku = string válido` y `headbox_item_id = string válido`
- Los botones muestran estado visual (primary cuando activo)
- Side/bottom channel NO tienen botones (solo se guardan para BOM generation)
