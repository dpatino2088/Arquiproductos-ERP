# Análisis: Filtrado Progresivo de Templates - Flujo Completo

## Problema Reportado
Al cambiar de una opción a otra en el configurador (ej. Manual → Motor, o cambiar color), sale error y las opciones no cargan correctamente ("Loading drive options...").

## Flujo Actual (7 Steps)

### 1. **ProductStep** → Selección de ProductType
- **Input**: nada
- **Output**: `product_type_id`, `productType` (UI code)
- **Templates**: 
  - ✅ Limpia `bom_template_id` cuando cambia ProductType
  - ❌ NO inicializa `_hardware_filtered_templates`

### 2. **MeasurementsStep** → Dimensiones
- **Input**: `product_type_id`
- **Output**: `width_m`, `height_m`, `quantity`, `area`, `position`
- **Templates**: NO afecta filtrado

### 3. **VariantsStep** → Fabric Selection
- **Input**: `product_type_id`
- **Output**: `fabric_variant_id`, `manufacturer_id`, `collection_name`, `variant_name`
- **Templates**: NO afecta filtrado (fabric NO filtra templates)

### 4. **HardwareStep** → Color + Componentes Hardware
- **Input**: `product_type_id` + (opcional) `filteredTemplateIds`
- **Output**: 
  - `hardware_color` (White/Black/Silver) - **OBLIGATORIO**
  - `bottom_bar_item_id`, `bottom_bar_sku` - **OBLIGATORIO**
  - `headbox_item_id`, `headbox_sku` - OPCIONAL
  - `side_channel_item_id`, `side_channel_sku` - OPCIONAL
  - `bottom_channel_item_id`, `bottom_channel_sku` - OPCIONAL
- **Templates**: 
  - `finalFilteredTemplates` = filtrado progresivo desde color + bottom bar
  - Guarda en `_hardware_filtered_templates`

#### ⚠️ **PROBLEMA 1: Al cambiar color**
Cuando seleccionas un color diferente:
```javascript
onUpdate({ 
  hardware_color: newColor,
  // ... limpia todas las selecciones de componentes ...
  _hardware_filtered_templates: null,  // ❌ PROBLEMA: pone null
});
```
Esto causa que OperatingSystemStep no tenga base para cargar opciones.

#### ✅ **SOLUCIÓN 1**:
Al cambiar color, en lugar de poner `_hardware_filtered_templates: null`, debe:
1. Cargar templates base para el NUEVO color
2. Guardarlos en `_hardware_filtered_templates`
3. Así OperatingSystemStep siempre tiene una base válida

### 5. **OperatingSystemStep** → Manual/Motor + Drive/Motor + Tube
- **Input**: `_hardware_filtered_templates` (del paso anterior)
- **Output**:
  - `operation_type` ('manual' o 'motor') - **OBLIGATORIO**
  - Si manual: `drive_item_id`, `drive_sku` - **OBLIGATORIO**
  - Si motor: `motor_item_id`, `motor_sku` - **OBLIGATORIO**
  - `tube_item_id`, `tube_sku` - **OBLIGATORIO**
- **Templates**:
  - `baseTemplatesForOptions` = `_operating_system_base_templates || _hardware_filtered_templates`
  - Divide en `manualTemplateIds` y `motorTemplateIds`
  - Al seleccionar Motor/Drive/Tube, filtra y actualiza `_hardware_filtered_templates`

#### ⚠️ **PROBLEMA 2: Al cambiar Manual ↔ Motor**
```javascript
// Línea 391 (cambio a Motor):
updates._hardware_filtered_templates = uniq(templatesForMotor) ?? uniq(baseTemplatesForOptions) ?? null;
```
Si `hardwareFilteredTemplates` (del paso anterior) es `null`, entonces `baseTemplatesForOptions` es `null/undefined`, entonces `templatesForMotor` es `null`, y se guarda `null` → no hay opciones.

#### ✅ **SOLUCIÓN 2**:
1. HardwareStep NUNCA debe dejar `_hardware_filtered_templates` en null (solución 1)
2. OperatingSystemStep debe cargar templates base cuando recibe null:
   ```javascript
   // Si _hardware_filtered_templates es null, cargar TODOS los templates de ProductType + Color
   useEffect(() => {
     if ((!hardwareFilteredTemplates || hardwareFilteredTemplates.length === 0) && productTypeId && hardwareColor) {
       // Cargar templates base
     }
   }, [hardwareFilteredTemplates, productTypeId, hardwareColor]);
   ```

### 6. **AccessoriesStep** → Accesorios Opcionales
- **Input**: `_hardware_filtered_templates`
- **Output**: array de accesorios seleccionados
- **Templates**: NO afecta filtrado (accesorios no están en templates BOM)

### 7. **ReviewStep** → Revisión Final
- **Input**: toda la configuración + `_hardware_filtered_templates`
- **Output**: muestra breakdown del BOM
- **Templates**: usa `_hardware_filtered_templates` para matching final

## Reglas de Dependencia de Color

### Roles que SÍ dependen de Color:
- `bottom_bar` ✅
- `headbox` ✅
- `side_channel` ✅
- `bottom_channel` ✅
- `drive` ✅ (manual drive)

### Roles que NO dependen de Color:
- `motor` ✅
- `tube` ✅

## Cascada de Limpieza al Cambiar

### Si cambias **Color**:
→ Limpiar: Bottom Bar, Headbox, Side Channel, Bottom Channel, Drive
→ NO afecta: Motor, Tube (se cargan desde templates base del ProductType)

### Si cambias **Bottom Bar**:
→ Limpiar: Headbox, Side Channel, Bottom Channel
→ Filtrar templates

### Si cambias **Headbox**:
→ Limpiar: Side Channel, Bottom Channel
→ Filtrar templates

### Si cambias **Side Channel**:
→ Limpiar: Bottom Channel
→ Filtrar templates

### Si cambias **Manual ↔ Motor**:
→ Limpiar: Drive/Motor específico + Tube
→ Resetear a templates base del nuevo tipo (manual o motor)

### Si cambias **Drive/Motor específico**:
→ Limpiar: Tube
→ Filtrar templates

## Fix Necesario

### Fix 1: HardwareStep - Al cambiar color
Cuando el usuario selecciona o cambia el color:

```javascript
// ANTES (❌ causa null):
onUpdate({ 
  hardware_color: newColor,
  _hardware_filtered_templates: null,  // ❌
});

// DESPUÉS (✅):
// 1. Cargar templates para el nuevo color
const { data: templates } = await supabase
  .from('BOMTemplates')
  .select('id')
  .eq('organization_id', activeOrganizationId)
  .eq('product_type_id', productTypeId)
  .eq('hardware_color', newColor)
  .eq('is_active', true);

// 2. Guardar templates base
onUpdate({ 
  hardware_color: newColor,
  _hardware_filtered_templates: templates.map(t => t.id),  // ✅ Array válido
  // ... limpiar componentes ...
});
```

### Fix 2: OperatingSystemStep - Cargar base cuando recibe null
Si `_hardware_filtered_templates` es null/empty, cargar templates base:

```javascript
useEffect(() => {
  if ((!hardwareFilteredTemplates || hardwareFilteredTemplates.length === 0) 
      && productTypeId && hardwareColor) {
    // Cargar templates base para ProductType + Color
    loadBaseTemplates();
  }
}, [hardwareFilteredTemplates, productTypeId, hardwareColor]);
```

### Fix 3: useBOMTemplateOptionsSimple - Fallback más robusto
Línea 429: cuando no hay color ni filteredTemplateIds, en lugar de retornar [], cargar templates base del ProductType:

```javascript
// Si requiere color y no hay color, PERO tenemos productTypeId, cargar todos los templates
if (requiresColor && !hardwareColor && !filteredTemplateIds) {
  // Cargar TODOS los templates del ProductType (sin filtro de color)
  // para que al menos muestre algo
}
```

## Orden de Aplicación
1. Fix en HardwareStep (crítico - evita null)
2. Fix en OperatingSystemStep (safety net)
3. Fix en useBOMTemplateOptionsSimple (fallback general)
