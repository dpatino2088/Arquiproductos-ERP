# 📋 Análisis: Flujo Quote → BOM

## 🎯 ESTADO ACTUAL (Enero 2026)

### ✅ **IMPLEMENTADO** - Flujo Quote → BOM Funcionando

**Cambios realizados en `src/pages/sales/QuoteNew.tsx` (líneas 830-930):**
- ✅ Guardado de `QuoteLineComponents` con `kind='option'` implementado
- ✅ Eliminada llamada a `generate_configured_bom_for_quote_line` (no existía)
- ✅ Implementada llamada correcta a `generate_bom_instance_for_quote_line()`
- ✅ Soft-delete de options previas al editar (preserva accessories)
- ✅ Logs DEV para debugging

### ✅ LO QUE TENEMOS

#### 1. **BOM Templates (Implementado)**
- ✅ `BOMTemplates` + `BOMComponents` existen y funcionan
- ✅ Función `generate_bom_instance_for_quote_line()` creada
- ✅ Función `resolve_component_item_id()` creada
- ✅ Función `select_best_bom_template()` creada
- ✅ Función `build_quote_line_config()` creada
- ✅ `CatalogItems.item_role` agregado con CHECK constraint
- ✅ UI de BOM Templates funcional

#### 2. **Quotes & QuoteLines (Funcional)**
- ✅ `QuoteNew.tsx` permite crear/editar quotes
- ✅ `ProductConfigurator` muestra pasos de configuración
- ✅ Guarda en `QuoteLines`:
  - `width_m`, `height_m` (medidas)
  - `collection_name`, `variant_name` (tela)
  - `hardware_color`, `cassette`, `side_channel`, `side_channel_type`
  - `drive_type`, `tube_type`, `bottom_rail_type`
  - `bom_template_id`, `product_type_id`

#### 3. **QuoteLineComponents (Tabla existe, pero NO se usa correctamente)**
- ✅ Tabla existe en DB con columnas:
  - `kind` (option | override)
  - `component_role` (text)
  - `catalog_item_id` (uuid)
  - `payload` (jsonb)
- ⚠️ **PROBLEMA**: Solo se usa para guardar `accessories` con `source='accessory'`
- ❌ **FALTA**: NO se guardan las opciones de configuración (hardware_color, cassette, etc.) como `kind='option'`

---

## ❌ PROBLEMA PRINCIPAL

### **El configurador NO alimenta `QuoteLineComponents` correctamente**

El flujo actual:
```typescript
// QuoteNew.tsx línea 843-861
await supabase.rpc('generate_configured_bom_for_quote_line', {
  p_quote_line_id: finalLineId,
  p_product_type_id: productTypeId,
  p_organization_id: activeOrganizationId,
  p_drive_type: operationType,
  p_bottom_rail_type: ...,
  p_cassette: ...,
  p_hardware_color: ...,
  // etc.
});
```

**Problemas:**
1. ❌ Esta función RPC **NO EXISTE** en el dump v2
2. ❌ NO guarda `QuoteLineComponents` con `kind='option'`
3. ❌ Las opciones se pasan como parámetros directos, no como JSONB `payload`

### **Lo que DEBERÍA hacer:**

```typescript
// Guardar hardware_color como QuoteLineComponent
await supabase.from('QuoteLineComponents').insert({
  organization_id: activeOrganizationId,
  quote_line_id: finalLineId,
  kind: 'option',
  component_role: 'hardware_color',
  payload: { hardware_color: 'White' }, // ← ESTO ES LO QUE build_quote_line_config() espera
  deleted: false,
});

// Guardar otras opciones...
await supabase.from('QuoteLineComponents').insert({
  organization_id: activeOrganizationId,
  quote_line_id: finalLineId,
  kind: 'option',
  component_role: 'drive_type',
  payload: { drive_type: 'manual' },
  deleted: false,
});
```

**Luego, llamar a la función BOM:**
```typescript
await supabase.rpc('generate_bom_instance_for_quote_line', {
  p_org_id: activeOrganizationId,
  p_quote_line_id: finalLineId,
  p_product_type_id: productTypeId,
});
```

Esta función:
1. Lee `QuoteLineComponents` con `build_quote_line_config()` → genera `config_jsonb`
2. Selecciona el mejor `BOMTemplate` con `select_best_bom_template()`
3. Crea `BomInstance` y `BomInstanceLines`
4. Resuelve cada componente con `resolve_component_item_id()`

---

## 🔧 SOLUCIÓN

### **OPCIÓN A: Implementar guardado de QuoteLineComponents en QuoteNew.tsx (RECOMENDADO)**

Modificar `QuoteNew.tsx` línea 830-866 para:

```typescript
// PASO 1: Guardar opciones de configuración como QuoteLineComponents
if (finalLineId) {
  // Limpiar opciones anteriores (cuando editing)
  await supabase
    .from('QuoteLineComponents')
    .update({ deleted: true })
    .eq('quote_line_id', finalLineId)
    .eq('kind', 'option')
    .eq('organization_id', activeOrganizationId);

  // Insertar nuevas opciones
  const configOptions = [];

  // Hardware color (REQUERIDO para hardware)
  if ((productConfig as any).hardware_color) {
    configOptions.push({
      organization_id: activeOrganizationId,
      quote_line_id: finalLineId,
      kind: 'option',
      component_role: 'hardware_color',
      payload: { hardware_color: (productConfig as any).hardware_color },
      source: 'configured_component',
      deleted: false,
    });
  }

  // Drive type
  if ((productConfig as any).drive_type) {
    configOptions.push({
      organization_id: activeOrganizationId,
      quote_line_id: finalLineId,
      kind: 'option',
      component_role: 'drive_type',
      payload: { drive_type: (productConfig as any).drive_type },
      source: 'configured_component',
      deleted: false,
    });
  }

  // Cassette
  if ((productConfig as any).cassette) {
    configOptions.push({
      organization_id: activeOrganizationId,
      quote_line_id: finalLineId,
      kind: 'option',
      component_role: 'cassette',
      payload: { cassette: (productConfig as any).cassette },
      source: 'configured_component',
      deleted: false,
    });
  }

  // Side channel
  if (sideChannelBool) {
    configOptions.push({
      organization_id: activeOrganizationId,
      quote_line_id: finalLineId,
      kind: 'option',
      component_role: 'side_channel',
      payload: { 
        side_channel: sideChannelBool,
        side_channel_type: sideChannelTypeNormalized 
      },
      source: 'configured_component',
      deleted: false,
    });
  }

  // Bottom rail type
  if ((productConfig as any).bottom_rail_type) {
    configOptions.push({
      organization_id: activeOrganizationId,
      quote_line_id: finalLineId,
      kind: 'option',
      component_role: 'bottom_rail_type',
      payload: { bottom_rail_type: (productConfig as any).bottom_rail_type },
      source: 'configured_component',
      deleted: false,
    });
  }

  // Tube type
  if ((productConfig as any).tube_type) {
    configOptions.push({
      organization_id: activeOrganizationId,
      quote_line_id: finalLineId,
      kind: 'option',
      component_role: 'tube_type',
      payload: { tube_type: (productConfig as any).tube_type },
      source: 'configured_component',
      deleted: false,
    });
  }

  // Insertar todas las opciones
  if (configOptions.length > 0) {
    const { error: optionsError } = await supabase
      .from('QuoteLineComponents')
      .insert(configOptions);

    if (optionsError) {
      console.error('Error saving config options:', optionsError);
      throw new Error('Failed to save configuration options');
    }
  }

  // PASO 2: Generar BOM Instance
  if (productTypeId) {
    try {
      const { data: bomData, error: bomError } = await supabase.rpc(
        'generate_bom_instance_for_quote_line',
        {
          p_org_id: activeOrganizationId,
          p_quote_line_id: finalLineId,
          p_product_type_id: productTypeId,
        }
      );

      if (bomError) {
        console.error('BOM generation error:', bomError);
        // No throw - BOM generation es opcional
      } else if (import.meta.env.DEV) {
        console.log('✅ BOM Instance created:', bomData);
      }
    } catch (bomError) {
      console.warn('BOM generation failed:', bomError);
    }
  }
}
```

### **Campos a Guardar como QuoteLineComponents (kind='option')**

| Campo Config | component_role | payload |
|-------------|----------------|---------|
| `hardware_color` | `'hardware_color'` | `{ "hardware_color": "White" }` |
| `drive_type` | `'drive_type'` | `{ "drive_type": "manual" }` |
| `cassette` | `'cassette'` | `{ "cassette": true }` |
| `cassette_type` | `'cassette_type'` | `{ "cassette_type": "standard" }` |
| `side_channel` | `'side_channel'` | `{ "side_channel": true, "side_channel_type": "side_only" }` |
| `bottom_rail_type` | `'bottom_rail_type'` | `{ "bottom_rail_type": "standard" }` |
| `tube_type` | `'tube_type'` | `{ "tube_type": "RTU-42" }` |
| `operating_system_variant` | `'operating_system_variant'` | `{ "operating_system_variant": "CM-09" }` |

---

## 🧪 VERIFICACIÓN

### **1. Crear Quote con Roller Shade Manual**

Configuración:
- Width: 1.5m, Height: 2.0m
- Collection: "Screen", Variant: "White"
- Drive Type: Manual
- Hardware Color: White
- Cassette: Yes
- Side Channel: Yes (side_only)

Debe crear:
1. ✅ `QuoteLine` con medidas, collection, variant
2. ✅ 7-8 `QuoteLineComponents` con `kind='option'`:
   - `hardware_color: { "hardware_color": "White" }`
   - `drive_type: { "drive_type": "manual" }`
   - `cassette: { "cassette": true }`
   - `side_channel: { "side_channel": true, "side_channel_type": "side_only" }`
   - etc.
3. ✅ `BomInstance` creado con `config_jsonb` = agregación de payloads
4. ✅ `BomInstanceLines` con componentes resueltos (fabric, bracket, tube, etc.)

### **2. Query de Verificación**

```sql
-- Ver las opciones guardadas
SELECT 
  qlc.component_role,
  qlc.kind,
  qlc.payload,
  qlc.source
FROM public."QuoteLineComponents" qlc
WHERE qlc.quote_line_id = 'YOUR_QUOTE_LINE_ID'
  AND qlc.deleted = false
ORDER BY qlc.created_at;

-- Ver el BOM generado
SELECT 
  bi.id as instance_id,
  bi.config_jsonb,
  bil.part_role,
  bil.resolved_sku,
  bil.qty,
  bil.uom,
  ci.sku,
  ci.name
FROM public."BomInstances" bi
JOIN public."BomInstanceLines" bil ON bil.bom_instance_id = bi.id
JOIN public."CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE bi.quote_line_id = 'YOUR_QUOTE_LINE_ID'
  AND bi.deleted = false
ORDER BY bil.part_role;
```

---

## 📝 PRÓXIMOS PASOS

### ✅ **Prioridad 1: COMPLETADO - Implementar guardado de QuoteLineComponents**
- ✅ Modificado `QuoteNew.tsx` línea 830-930
- ✅ Eliminada llamada a `generate_configured_bom_for_quote_line` (no existía)
- ✅ Agregada lógica para guardar options como `QuoteLineComponents` con `kind='option'`
- ✅ Llamada a `generate_bom_instance_for_quote_line()` implementada correctamente

### ✅ **Prioridad 2: COMPLETADO - Verificar datos requeridos**
- ✅ `QuoteLines.collection_name`, `QuoteLines.variant_name` (para fabric)
- ✅ `QuoteLines.width_m`, `QuoteLines.height_m` (para cálculos)
- ✅ `hardware_color` se guarda como QuoteLineComponent con payload JSONB

### 🧪 **Prioridad 3: TESTING REQUERIDO**
- Crear Quote con Roller Shade Manual
- Verificar que `QuoteLineComponents` se creen correctamente
- Verificar que `BomInstance` se genere automáticamente
- Verificar que los componentes se resuelvan correctamente

---

## 🔍 RESUMEN TÉCNICO

### **Flujo Correcto (Quote → BOM)**

```
1. Usuario configura producto en ProductConfigurator
   ↓
2. Al guardar, QuoteNew.tsx crea:
   - QuoteLine (con medidas, collection, variant, product_type_id, bom_template_id)
   - QuoteLineComponents (kind='option' con payload para hardware_color, drive_type, etc.)
   ↓
3. Llamar RPC: generate_bom_instance_for_quote_line(org_id, quote_line_id, product_type_id)
   ↓
4. Esta función internamente:
   - build_quote_line_config() → agrega payloads en config_jsonb
   - select_best_bom_template() → encuentra el template
   - Crea BomInstance con config_jsonb
   - Itera BOMComponents y crea BomInstanceLines
   - resolve_component_item_id() resuelve cada SKU por role+color o collection+variant
   ↓
5. Resultado: BomInstance + BomInstanceLines listo para Manufacturing
```

### **Contrato de Datos (LOCKED)**

#### **QuoteLines (siempre)**
- `width_m`, `height_m` (requerido para qty calc)
- `collection_name`, `variant_name` (requerido para fabric resolution)
- `product_type_id` (requerido para template selection)
- `bom_template_id` (opcional, si auto-select falla)

#### **QuoteLineComponents (kind='option')**
- `hardware_color` → `{ "hardware_color": "White" }`
- `drive_type` → `{ "drive_type": "manual" }`
- `cassette` → `{ "cassette": true }`
- `side_channel` → `{ "side_channel": true, "side_channel_type": "side_only" }`
- `tube_type` → `{ "tube_type": "RTU-42" }`
- etc.

#### **CatalogItems (requerido)**
- Rolls: `is_roll=true`, `collection_name`, `variant_name`
- Hardware: `is_roll=false`, `item_role`, `color`

---

## 🚨 ACCIÓN INMEDIATA REQUERIDA

**Modificar `src/pages/sales/QuoteNew.tsx` para:**
1. Guardar `QuoteLineComponents` con `kind='option'` y `payload` JSONB
2. Eliminar llamada a `generate_configured_bom_for_quote_line` (no existe)
3. Llamar a `generate_bom_instance_for_quote_line()` (la correcta)

---

## ✅ **IMPLEMENTACIÓN COMPLETADA**

### **Cambios realizados:**

1. **`src/pages/sales/QuoteNew.tsx` (líneas 830-930)**:
   - ✅ Eliminada llamada a `generate_configured_bom_for_quote_line` (RPC inexistente)
   - ✅ Implementado guardado de configuración como `QuoteLineComponents` con `kind='option'`
   - ✅ Soft-delete de options previas (preserva accessories)
   - ✅ Implementada llamada correcta a `generate_bom_instance_for_quote_line()`
   - ✅ Logs DEV para debugging

2. **Opciones guardadas como QuoteLineComponents:**
   - `hardware_color` → `{ "hardware_color": "White" }`
   - `drive_type` → `{ "drive_type": "manual" }`
   - `cassette` → `{ "cassette": true }`
   - `cassette_type` → `{ "cassette_type": "standard" }`
   - `side_channel` → `{ "side_channel": true, "side_channel_type": "side_only" }`
   - `bottom_rail_type` → `{ "bottom_rail_type": "standard" }`
   - `tube_type` → `{ "tube_type": "RTU-42" }`
   - `operating_system_variant` → `{ "operating_system_variant": "CM-09" }`

---

## 🧪 **INSTRUCCIONES DE TESTING**

### **TEST 1: Crear Quote con Roller Shade Manual**

1. Ir a `/sales/quotes/new`
2. Crear Quote básico (quote_no, customer opcional, status=draft)
3. Click "Add Product"
4. Seleccionar "Roller Shade"
5. Configurar:
   - **Measurements**: Width: 1500mm, Height: 2000mm
   - **Variants**: Collection "Screen", Variant "White"
   - **Hardware**: Color "White", Cassette: Yes, Side Channel: Yes (side_only)
   - **Operating System**: Manual
6. Guardar

### **Verificaciones en DB:**

#### **A) Verificar QuoteLineComponents creados:**
```sql
SELECT 
  qlc.component_role,
  qlc.kind,
  qlc.payload,
  qlc.source,
  qlc.deleted
FROM public."QuoteLineComponents" qlc
JOIN public."QuoteLines" ql ON ql.id = qlc.quote_line_id
JOIN public."Quotes" q ON q.id = ql.quote_id
WHERE q.quote_no = 'TU_QUOTE_NO'
  AND qlc.deleted = false
ORDER BY 
  CASE qlc.kind 
    WHEN 'option' THEN 1 
    WHEN 'override' THEN 2 
    ELSE 3 
  END,
  qlc.component_role;
```

**Resultado esperado:** 7-8 filas con `kind='option'` y payloads JSONB correctos.

#### **B) Verificar BomInstance creado:**
```sql
SELECT 
  bi.id as instance_id,
  bi.config_jsonb,
  bi.bom_template_id,
  bt.code as template_code,
  bt.name as template_name
FROM public."BomInstances" bi
JOIN public."BOMTemplates" bt ON bt.id = bi.bom_template_id
JOIN public."QuoteLines" ql ON ql.id = bi.quote_line_id
JOIN public."Quotes" q ON q.id = ql.quote_id
WHERE q.quote_no = 'TU_QUOTE_NO'
  AND bi.deleted = false
ORDER BY bi.created_at DESC;
```

**Resultado esperado:** 1 fila con `config_jsonb` conteniendo todas las options agregadas.

#### **C) Verificar BomInstanceLines creados:**
```sql
SELECT 
  bil.part_role,
  bil.resolved_sku,
  bil.qty,
  bil.uom,
  bil.unit_cost_exw,
  bil.total_cost_exw,
  ci.sku as catalog_sku,
  ci.name as catalog_name,
  ci.item_role,
  ci.color
FROM public."BomInstanceLines" bil
JOIN public."BomInstances" bi ON bi.id = bil.bom_instance_id
JOIN public."CatalogItems" ci ON ci.id = bil.resolved_part_id
JOIN public."QuoteLines" ql ON ql.id = bi.quote_line_id
JOIN public."Quotes" q ON q.id = ql.quote_id
WHERE q.quote_no = 'TU_QUOTE_NO'
  AND bi.deleted = false
ORDER BY bil.part_role;
```

**Resultado esperado:** 10-15 filas con componentes resueltos (fabric, bracket, tube, end_cap, etc.).

#### **D) Verificar resolución de hardware por color:**
```sql
-- Debe haber encontrado items con item_role + color matcheando hardware_color de config
SELECT 
  bil.part_role,
  ci.sku,
  ci.item_role,
  ci.color,
  bi.config_jsonb->>'hardware_color' as config_color
FROM public."BomInstanceLines" bil
JOIN public."BomInstances" bi ON bi.id = bil.bom_instance_id
JOIN public."CatalogItems" ci ON ci.id = bil.resolved_part_id
JOIN public."QuoteLines" ql ON ql.id = bi.quote_line_id
JOIN public."Quotes" q ON q.id = ql.quote_id
WHERE q.quote_no = 'TU_QUOTE_NO'
  AND bi.deleted = false
  AND ci.is_roll = false -- Hardware items
  AND ci.color IS NOT NULL
ORDER BY bil.part_role;
```

**Resultado esperado:** Items con `color='White'` matcheando `config_color='White'`.

---

## 🎯 **SIGUIENTE PASO**

**Crear un Quote de prueba y verificar con los queries de arriba.**
