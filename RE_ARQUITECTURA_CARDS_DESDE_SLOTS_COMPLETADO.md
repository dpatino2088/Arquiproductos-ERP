# RE-ARQUITECTURA: Cards desde Slots de Templates Candidatos - COMPLETADO

## 🎯 Objetivo

Cambiar el configurador para que las cards (opciones de SKUs) se carguen desde `BOMTemplateSlots` de templates candidatos, en vez de desde `CatalogItems` por role. Esto asegura que solo se muestren SKUs que realmente existen en los templates candidatos.

## ✅ Cambios Implementados

### 1. Nuevo Hook: `useBOMTemplateRoleOptions.ts`

**Ubicación:** `src/hooks/useBOMTemplateRoleOptions.ts`

**Propósito:**
- Obtiene opciones (SKUs) por role desde `BOMTemplateSlots` de templates candidatos
- Reemplaza `useRollerCatalogItems` para roles que filtran templates

**Entrada:**
- `candidateTemplateIds: string[]` - IDs de templates candidatos
- `role: string` - Role a filtrar (ej: 'bottom_bar', 'tube', 'headbox')
- `enabled: boolean` - Si debe hacer fetch (default: true)

**Salida:**
- `items: BOMTemplateRoleOption[]` - Lista de CatalogItems con { id, sku, name, image_url, ... }
- `loading: boolean`
- `error: string | null`

**Query:**
1. Select DISTINCT `catalog_item_id` de `BOMTemplateSlots` donde:
   - `bom_template_id IN (candidateTemplateIds)`
   - `item_role = role` (case-insensitive)
   - `catalog_item_id IS NOT NULL`
   - `deleted = false`, `archived = false`
2. Join a `CatalogItems` por `id`:
   - `organization_id = activeOrganizationId`
   - `is_active = true`
   - `deleted = false`, `archived = false`
3. Filtrar items con `sku` válido (no null, no vacío)
4. Ordenar por `name`, luego por `sku`

### 2. Modificación de `ProductConfigurator.tsx`

**Cambios:**
- ✅ Separar candidatos base de filtros por selección
- ✅ Obtener `candidateTemplateIds` desde templates base (filtros fuertes: product_type, hardware_color, operation_type)
- ✅ Pasar `candidateTemplateIds` a `HardwareStep` y `OperatingSystemStep`
- ✅ Agregar logs de diagnóstico

**Flujo:**
1. **FASE 2A:** Obtener candidatos base con `baseFilters` (solo `operation_type`)
2. **FASE 2B:** Aplicar filtros completos (`templateFilters`) para narrow down
3. Exponer `candidateTemplateIds` para que los steps puedan cargar opciones desde slots

### 3. Modificación de `HardwareStep.tsx`

**Cambios:**
- ✅ Reemplazar `useRollerCatalogItems` con `useBOMTemplateRoleOptions` para:
  - `bottom_bar`
  - `headbox`
  - `side_channel`
  - `bottom_channel`
- ✅ Aceptar `candidateTemplateIds` como prop
- ✅ Agregar logs de diagnóstico

**Roles actualizados:**
- `bottom_bar`: desde slots de candidatos ✅
- `headbox`: desde slots de candidatos ✅
- `side_channel`: desde slots de candidatos (NO filtra templates) ✅
- `bottom_channel`: desde slots de candidatos (NO filtra templates) ✅

### 4. Logs de Diagnóstico Agregados

**En `ProductConfigurator.tsx`:**
```typescript
console.debug("[ProductConfigurator] Candidate templates (base filters)", {
  productTypeId,
  hardwareColor,
  operationType,
  candidateCount: candidateTemplateIds.length,
  candidateIds: candidateTemplateIds.slice(0, 5),
});

console.debug("[ProductConfigurator] Narrow down after bottom_bar selection", {
  bottom_bar_sku: templateFilters.bottom_bar_sku,
  candidatesBefore: candidateTemplateIds.length,
  templatesAfter: bomTemplatesForDebug.length,
  filteredOut: candidateTemplateIds.length - bomTemplatesForDebug.length,
});
```

**En `HardwareStep.tsx`:**
```typescript
console.debug("[HardwareStep] Candidate templates", {
  candidateCount: candidateTemplateIds.length,
  hasHardwareColor,
  candidateIds: candidateTemplateIds.slice(0, 5),
});

console.debug("[HardwareStep] Bottom Bar options from slots", {
  role: 'bottom_bar',
  optionsCount: bottomBarOptions.length,
  options: bottomBarOptions.slice(0, 5).map(i => ({ sku: i.sku, name: i.name })),
});
```

**En `useBOMTemplateRoleOptions.ts`:**
```typescript
console.debug('[useBOMTemplateRoleOptions] Fetching options', {
  role,
  normalizedRole,
  candidateTemplateIds: candidateTemplateIds.length,
  enabled,
});

console.debug('[useBOMTemplateRoleOptions] Success', {
  role,
  optionsCount: mappedItems.length,
  options: mappedItems.slice(0, 5).map(i => ({ sku: i.sku, name: i.name })),
});
```

## 📁 Archivos Modificados

1. **`src/hooks/useBOMTemplateRoleOptions.ts`** (NUEVO)
   - Hook para obtener opciones desde slots de templates candidatos

2. **`src/pages/sales/ProductConfigurator.tsx`**
   - Separar candidatos base de filtros por selección
   - Exponer `candidateTemplateIds` a steps

3. **`src/pages/sales/curtain-config/HardwareStep.tsx`**
   - Reemplazar `useRollerCatalogItems` con `useBOMTemplateRoleOptions`
   - Aceptar `candidateTemplateIds` como prop

## 🧪 Validación

### Caso 1: Bottom Bar = RCA-04-W

**Pasos:**
1. Seleccionar Hardware Color "White"
2. Ver opciones de Bottom Bar (deben venir de slots de candidatos)
3. Seleccionar Bottom Bar "RCA-04-W"

**Resultado Esperado:**
- ✅ `candidateTemplateIds` debe tener 3 templates (como en SQL)
- ✅ Opciones de Bottom Bar deben mostrar solo SKUs que existen en slots de esos 3 templates
- ✅ Al seleccionar "RCA-04-W", `bomTemplatesForDebug` debe reducirse a templates que tienen ese SKU

### Caso 2: Bottom Bar = RCA-04-W_2 (no existe en slots)

**Pasos:**
1. Seleccionar Hardware Color "White"
2. Intentar seleccionar Bottom Bar "RCA-04-W_2" (si aparece en la lista)

**Resultado Esperado:**
- ✅ Si "RCA-04-W_2" NO existe en slots de candidatos, NO debe aparecer en la lista
- ✅ Si aparece y se selecciona, `bomTemplatesForDebug` debe quedar en 0 (ningún template tiene ese SKU)

### Caso 3: Side/Bottom Channel

**Pasos:**
1. Seleccionar Side Channel "None" o un SKU específico
2. Marcar/desmarcar "ADD BOTTOM CHANNEL"

**Resultado Esperado:**
- ✅ UI cambia (selección se guarda)
- ✅ `candidateTemplateIds` NO cambia (side_channel y bottom_channel NO filtran templates)
- ✅ Opciones de Side/Bottom Channel vienen de slots de candidatos

## 🔍 Cómo Validar con Logs

1. Abrir DevTools Console
2. Filtrar por `[ProductConfigurator]`, `[HardwareStep]`, `[useBOMTemplateRoleOptions]`
3. Verificar:
   - `Candidate templates (base filters)`: muestra conteo inicial de candidatos
   - `Bottom Bar options from slots`: muestra opciones cargadas desde slots
   - `Narrow down after bottom_bar selection`: muestra cómo se reducen candidatos al seleccionar

**Ejemplo de log esperado:**

```
[ProductConfigurator] Candidate templates (base filters) {
  productTypeId: "c50f6735-64e5-4e60-adb8-e4d426172fab",
  hardwareColor: "White",
  operationType: null,
  candidateCount: 10,
  candidateIds: [...]
}

[HardwareStep] Bottom Bar options from slots {
  role: 'bottom_bar',
  optionsCount: 3,
  options: [
    { sku: "RCA-04-W", name: "Bottom Bar" },
    { sku: "RCA-04-W_2", name: "Bottom Bar" },
    { sku: "RC3126-W", name: "Bottom rail square" }
  ]
}

[ProductConfigurator] Narrow down after bottom_bar selection {
  bottom_bar_sku: "RCA-04-W",
  candidatesBefore: 10,
  templatesAfter: 3,
  filteredOut: 7
}
```

## ⚠️ Restricciones Respetadas

- ✅ No inventar columnas: usa `CatalogItems.sku`, `CatalogItems.is_active`
- ✅ No introducir SQL en Supabase editor dentro del TS
- ✅ Mantener cambios mínimos y claros
- ✅ `side_channel` y `bottom_channel` NO filtran templates (solo afectan BOM generation)

## 📝 Notas Técnicas

- **Candidatos Base:** Filtros fuertes (product_type, hardware_color, operation_type) determinan el set inicial de templates candidatos
- **Narrow Down:** Al seleccionar un SKU, se reduce el set de candidatos usando filtros por selección
- **Cards desde Slots:** Las opciones de cards siempre vienen de slots de templates candidatos, nunca de CatalogItems por role
- **Roles No Filtrantes:** `side_channel` y `bottom_channel` se cargan desde slots pero NO reducen candidatos

## ✅ Estado

- [x] Hook `useBOMTemplateRoleOptions` creado
- [x] `ProductConfigurator` separa candidatos base de filtros por selección
- [x] `HardwareStep` usa `useBOMTemplateRoleOptions` en vez de `useRollerCatalogItems`
- [x] Logs de diagnóstico agregados
- [x] `candidateTemplateIds` se pasa a steps que lo necesitan
- [ ] Validación en UI (pendiente usuario)
- [ ] Actualizar `OperatingSystemStep` para usar el nuevo hook (pendiente)

## 🚀 Próximos Pasos

1. **Actualizar `OperatingSystemStep.tsx`:**
   - Reemplazar `useRollerCatalogItems` con `useBOMTemplateRoleOptions` para `motor` y `drive`
   - Aceptar `candidateTemplateIds` como prop

2. **Validar en UI:**
   - Verificar que solo se muestren SKUs que existen en slots de candidatos
   - Verificar que al seleccionar un SKU, los candidatos se reduzcan correctamente
   - Verificar que side/bottom channel NO reduzcan candidatos

3. **Optimizaciones futuras:**
   - Cachear opciones por role si los candidatos no cambian
   - Pre-cargar opciones de roles siguientes cuando sea posible
