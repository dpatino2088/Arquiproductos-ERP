# FIX: Re-arquitectura Unificado - COMPLETADO

## 🎯 Objetivo

Arreglar la re-arquitectura "Cards desde Slots" para que funcione correctamente:
- **Problema:** `candidateTemplateIds` estaba demasiado amplio (ej: 10 templates) y por eso aparecían SKUs que no pertenecían al set correcto
- **Solución:** Un solo pipeline que retorna `baseTemplates` y `filteredTemplates` separados, usando el MISMO flujo que construye `mappedTemplates` y el debug "Template Found"

## ✅ Cambios Implementados

### 1. Modificación de `useBOMTemplates.ts`

**Cambios:**
- ✅ Agregado estado `baseTemplates` para guardar templates después de filtros estructurales, antes de selections
- ✅ Guardar `baseTemplates` justo después de mapear datos de la query inicial (línea ~283)
- ✅ Guardar `filteredTemplates` después de aplicar todos los filtros de selección
- ✅ Retornar ambos: `baseTemplates` y `filteredTemplates` (alias `templates`)
- ✅ Agregar logs de diagnóstico para ambos sets

**Flujo Interno:**
1. Query inicial: Filtra por `product_type_id`, `hardware_color`, `organization_id`, `active`, `deleted`, `archived`
2. **`baseTemplates`**: Se guarda aquí (después de filtros estructurales)
3. Aplicar filtros de selección: `bottom_bar`, `tube`, `headbox`, `motor`, `drive`, `operation_type`
4. **`filteredTemplates`**: Se guarda aquí (después de selections)

**Logs Agregados:**
```typescript
console.debug('[useBOMTemplates] Base templates (after structural filters)', {
  count: baseTemplatesResult.length,
  productTypeId,
  hardwareColor,
  operationType: filters?.operation_type || null,
  templateIds: baseTemplatesResult.slice(0, 5).map(t => t.id),
  templateNames: baseTemplatesResult.slice(0, 5).map(t => t.name),
});

console.debug('[useBOMTemplates] Filtered templates (after selections)', {
  baseCount: baseTemplatesResult.length,
  filteredCount: filteredTemplatesResult.length,
  filteredOut: baseTemplatesResult.length - filteredTemplatesResult.length,
  filteredTemplateIds: filteredTemplatesResult.slice(0, 5).map(t => t.id),
});
```

### 2. Modificación de `ProductConfigurator.tsx`

**Cambios:**
- ✅ Eliminada la query "base candidates" separada
- ✅ Usar un solo hook `useBOMTemplates` que retorna ambos sets
- ✅ Obtener `baseTemplateIds` y `filteredTemplateIds` desde el mismo pipeline
- ✅ Pasar ambos sets a `HardwareStep` y `OperatingSystemStep`

**Antes:**
```typescript
// ❌ Dos queries separadas
const { templates: candidateTemplates } = useBOMTemplates(..., baseFilters);
const { templates: bomTemplatesForDebug } = useBOMTemplates(..., templateFilters);
```

**Después:**
```typescript
// ✅ Un solo pipeline
const { 
  templates: filteredTemplates, // Después de selections
  baseTemplates, // Después de filtros estructurales
  loading: templatesLoading 
} = useBOMTemplates(..., templateFilters);
```

### 3. Modificación de `HardwareStep.tsx`

**Cambios:**
- ✅ Recibir `baseTemplateIds` y `filteredTemplateIds` como props (en vez de `candidateTemplateIds`)
- ✅ **Bottom Bar**: Usar `baseTemplateIds` (primer step, antes de selections)
- ✅ **Headbox**: Usar `filteredTemplateIds` si existe, sino `baseTemplateIds` (después de seleccionar bottom_bar, para ver narrowing real)
- ✅ **Side/Bottom Channel**: Usar `filteredTemplateIds` si existe, sino `baseTemplateIds` (NO filtran templates)

**Lógica de Opciones:**
- `bottom_bar`: Siempre desde `baseTemplateIds` (primer step)
- `headbox`: Desde `filteredTemplateIds` si existe (ya reducido por bottom_bar), sino `baseTemplateIds`
- `side_channel` / `bottom_channel`: Desde `filteredTemplateIds` si existe, sino `baseTemplateIds` (pero NO filtran templates)

## 📁 Archivos Modificados

1. **`src/hooks/useBOMTemplates.ts`**
   - Agregado estado `baseTemplates`
   - Guardar `baseTemplates` después de filtros estructurales
   - Retornar `baseTemplates` y `filteredTemplates` separados
   - Logs de diagnóstico agregados

2. **`src/pages/sales/ProductConfigurator.tsx`**
   - Eliminada query separada de base candidates
   - Usar un solo pipeline `useBOMTemplates`
   - Obtener `baseTemplateIds` y `filteredTemplateIds`
   - Pasar ambos a steps

3. **`src/pages/sales/curtain-config/HardwareStep.tsx`**
   - Recibir `baseTemplateIds` y `filteredTemplateIds` como props
   - Bottom Bar desde `baseTemplateIds`
   - Headbox desde `filteredTemplateIds` (si existe) o `baseTemplateIds`
   - Side/Bottom Channel desde `filteredTemplateIds` (si existe) o `baseTemplateIds`

## 🧪 Validación

### Caso 1: White + Manual (o contexto real)

**Pasos:**
1. Seleccionar Hardware Color "White"
2. Seleccionar Operating Type "Manual" (si aplica)

**Resultado Esperado:**
- ✅ `baseTemplates` debe ser ~3 (no 10)
- ✅ `baseTemplateIds` debe tener 3 IDs
- ✅ Bottom Bar options solo debe incluir SKUs presentes en esos 3 templates

**Logs Esperados:**
```
[useBOMTemplates] Base templates (after structural filters) {
  count: 3,
  productTypeId: "...",
  hardwareColor: "White",
  operationType: "manual",
  templateIds: [...]
}

[HardwareStep] Bottom Bar options from base templates {
  baseTemplateCount: 3,
  optionsCount: 2, // Solo SKUs que existen en esos 3 templates
  options: [...]
}
```

### Caso 2: Seleccionar Bottom Bar SKU que NO existe

**Pasos:**
1. Seleccionar Hardware Color "White"
2. Ver opciones de Bottom Bar (solo SKUs de los 3 base templates)
3. Si aparece un SKU que NO existe en esos templates, seleccionarlo

**Resultado Esperado:**
- ✅ `filteredTemplates` debe quedar en 0
- ✅ `filteredTemplateIds` debe ser array vacío
- ✅ UI debe mostrar "0 templates found"
- ✅ Opciones siguientes (headbox, etc.) deben estar vacías

**Logs Esperados:**
```
[useBOMTemplates] Filtered templates (after selections) {
  baseCount: 3,
  filteredCount: 0,
  filteredOut: 3,
  filteredTemplateIds: []
}

[HardwareStep] Templates received {
  baseCount: 3,
  filteredCount: 0,
  ...
}
```

### Caso 3: Seleccionar Bottom Bar SKU válido

**Pasos:**
1. Seleccionar Hardware Color "White"
2. Seleccionar Bottom Bar "RCA-04-W" (que existe en los 3 base templates)

**Resultado Esperado:**
- ✅ `filteredTemplates` debe reducirse (ej: de 3 a 1 o 2)
- ✅ `filteredTemplateIds` debe tener menos IDs que `baseTemplateIds`
- ✅ Headbox options debe venir de `filteredTemplateIds` (ya reducido)
- ✅ Solo mostrar SKUs que existen en los templates filtrados

**Logs Esperados:**
```
[useBOMTemplates] Filtered templates (after selections) {
  baseCount: 3,
  filteredCount: 1,
  filteredOut: 2,
  filteredTemplateIds: ["template-id-1"]
}

[HardwareStep] Headbox options from filtered templates {
  filteredTemplateCount: 1,
  optionsCount: 2, // Solo SKUs de ese 1 template
  options: [...]
}
```

## 🔍 Cómo Validar con Logs

1. Abrir DevTools Console
2. Filtrar por `[useBOMTemplates]`, `[ProductConfigurator]`, `[HardwareStep]`
3. Verificar:
   - `Base templates (after structural filters)`: muestra conteo de templates base
   - `Filtered templates (after selections)`: muestra cómo se reducen templates
   - `Templates pipeline`: muestra ambos conteos en ProductConfigurator
   - `Bottom Bar options from base templates`: muestra opciones desde templates base
   - `Headbox options from filtered templates`: muestra opciones desde templates filtrados

## ⚠️ Restricciones Respetadas

- ✅ No inventar columnas: usa `CatalogItems.sku`, `CatalogItems.is_active`
- ✅ Un solo pipeline: `useBOMTemplates` retorna ambos sets
- ✅ `side_channel` y `bottom_channel` NO filtran templates (solo afectan BOM generation)

## 📝 Notas Técnicas

- **Base Templates:** Templates después de filtros estructurales (product_type, hardware_color, operation_type)
- **Filtered Templates:** Templates después de aplicar selections (bottom_bar, tube, headbox, motor, drive)
- **Cards desde Slots:** Las opciones siempre vienen de slots de templates, nunca de CatalogItems por role
- **Narrowing Real:** Al seleccionar un SKU, los templates se reducen y las opciones siguientes reflejan ese narrowing

## ✅ Estado

- [x] `useBOMTemplates` retorna `baseTemplates` y `filteredTemplates`
- [x] `ProductConfigurator` usa un solo pipeline
- [x] `HardwareStep` recibe `baseTemplateIds` y `filteredTemplateIds`
- [x] Bottom Bar usa `baseTemplateIds`
- [x] Headbox usa `filteredTemplateIds` (si existe)
- [x] Logs de diagnóstico agregados
- [ ] Validación en UI (pendiente usuario)
- [ ] Actualizar `OperatingSystemStep` para usar el nuevo sistema (pendiente)

## 🚀 Próximos Pasos

1. **Actualizar `OperatingSystemStep.tsx`:**
   - Recibir `baseTemplateIds` y `filteredTemplateIds` como props
   - Motor/Drive options deben venir de slots de `filteredTemplateIds` (ya reducido por bottom_bar/tube)

2. **Validar en UI:**
   - Verificar que `baseTemplates` es ~3 (no 10) para White + Manual
   - Verificar que Bottom Bar options solo muestra SKUs de esos 3 templates
   - Verificar que al seleccionar un SKU inválido, `filteredTemplates` queda en 0
   - Verificar que Headbox options refleja el narrowing real
