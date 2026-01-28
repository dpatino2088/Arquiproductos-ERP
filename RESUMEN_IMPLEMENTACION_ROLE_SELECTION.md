# RESUMEN: Implementación del Sistema de Selección de Roles

**Fecha:** 2025-01-27  
**Estado:** ✅ COMPLETADO (PASO 1.2)

---

## ✅ Cambios Implementados

### 1. Nuevo Sistema de Tipos (`src/lib/bom/selection.ts`)

Se creó un sistema de tipos para manejar tres estados claros de selección:

```typescript
export type RoleSelection =
  | { state: "unset" }      // No seleccionado, no filtra
  | { state: "none" }       // Explícitamente "ninguno", excluye templates con rol
  | { state: "selected"; catalog_item_id: string; code: string }; // SKU seleccionado
```

**Helpers creados:**
- `isUnset(s)` - Verifica si no está seleccionado
- `isNone(s)` - Verifica si es "ninguno"
- `isSelected(s)` - Verifica si tiene un item seleccionado
- `toRoleSelection(sku, catalog_item_id)` - Convierte formato legacy a RoleSelection
- `toLegacyFormat(selection)` - Convierte RoleSelection a formato legacy (para compatibilidad)

### 2. Refactorización del Filtrado (`src/hooks/useBOMTemplates.ts`)

Se actualizó el filtrado para usar el nuevo sistema en roles opcionales:

#### Headbox (opcional)
- ✅ **UNSET**: No filtra
- ✅ **NONE**: Excluye templates con headbox (con SKU activo)
- ✅ **SELECTED**: Filtra por SKU exacto

#### Side Channel (opcional)
- ✅ **UNSET**: No filtra
- ✅ **NONE**: Excluye templates con side_channel (con SKU activo)
- ✅ **SELECTED**: Filtra por SKU exacto

#### Bottom Channel (opcional)
- ✅ **UNSET**: No filtra (solo afecta BOM generation)
- ✅ **NONE**: Excluye templates con bottom_channel (con SKU activo)
- ✅ **SELECTED**: No filtra (solo afecta BOM generation)

### 3. Lógica de Filtrado

**Regla definitiva implementada:**

```typescript
// Para roles opcionales:
// - UNSET: no aplicas filtro por ese rol
// - SELECTED: filtras templates que tengan ese rol con ese SKU
// - NONE: filtras templates que NO tengan ese rol (o lo tengan sin SKU activo)
```

**Nota importante:** El fix anterior de "sku null si item inactivo" hace que NONE funcione perfecto:
- Si un CatalogItem está inactivo/deleted/archived, `slot.sku` será `null`
- NONE solo excluye templates donde `hasRoleWithSku = slots.some(s => s.item_role === role && !!s.sku)`
- Por lo tanto, templates con slots de CatalogItems inactivos NO se excluyen cuando el usuario selecciona NONE

---

## 📋 Archivos Modificados

1. ✅ `src/lib/bom/selection.ts` (NUEVO)
2. ✅ `src/hooks/useBOMTemplates.ts` (REFACTORIZADO)

---

## ⏳ Próximos Pasos (Pendientes)

### PASO 1.3: UI en ProductConfigurator

Necesario implementar en la UI:

1. **Botón "Quitar selección"** en cada card seleccionable
   - Setea `{state:"unset"}`

2. **Card "None / Sin..."** para roles opcionales
   - Setea `{state:"none"}`

3. **Handlers de selección:**
   ```typescript
   function setNone(role: keyof ConfigSelections) {
     setSelections(prev => ({ ...prev, [role]: { state: "none" } }));
   }
   function clearSelection(role: keyof ConfigSelections) {
     setSelections(prev => ({ ...prev, [role]: { state: "unset" } }));
   }
   function setSelected(role: keyof ConfigSelections, item: { id: string; code: string }) {
     setSelections(prev => ({ ...prev, [role]: { state: "selected", catalog_item_id: item.id, code: item.code } }));
   }
   ```

### PASO 2: Roles Obligatorios

Aplicar el mismo sistema a:
- `bottom_bar` (obligatorio)
- `tube` (obligatorio)
- `operating_type` (obligatorio, pero es especial porque no es un SKU único)

**Reglas para obligatorios:**
- **UNSET**: El usuario no puede avanzar (UI bloquea) o el resolver marca "incompleto"
- **NONE**: No permitido (UI lo bloquea)
- **SELECTED**: Filtra por SKU exacto

### PASO 3: ProductTypeRoleRules

Si existe la tabla `ProductTypeRoleRules` en DB:
- Cargar reglas de obligatoriedad por `product_type_id`
- Usar `is_required` para determinar si un rol es obligatorio u opcional
- Aplicar validaciones según `is_required`

---

## 🧪 Testing Requerido

1. ✅ Verificar que UNSET no filtra (templates disponibles)
2. ✅ Verificar que NONE excluye templates con rol (con SKU activo)
3. ✅ Verificar que NONE NO excluye templates con rol pero CatalogItem inactivo
4. ✅ Verificar que SELECTED filtra por SKU exacto
5. ✅ Verificar compatibilidad con formato legacy (sku string | null)

---

## 📝 Notas Técnicas

- El sistema es **backward compatible**: `toRoleSelection()` convierte formato legacy automáticamente
- Los slots con `sku === null` (CatalogItem inactivo) se tratan como "no existe el rol" para NONE
- El filtrado usa `item_role` exacto de DB primero, luego normalizado como fallback
- Solo se consideran CatalogItems con `active=true, deleted=false, archived=false`
