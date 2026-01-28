# Implementación Roller BOM Configurator

## Resumen

Se ha implementado un configurador completo de BOM para Roller Shades basado en el sistema de **fingerprint** que coincide exactamente con la estructura de `BOMTemplates` en la base de datos.

## Arquitectura

### 1. Tipos y Contratos (`src/lib/bom/types.ts`)

```typescript
interface BomFingerprint {
  product_type: string;            // 'roller'
  headbox_type: 'none' | 'cassette';
  system_size: 's' | 'm' | 'l' | 'xl';
  color: string;                   // 'white' | 'black' | etc.
  side_channel_mode: 'none' | 'side_only' | 'side_plus_bottom';
  operating_system: 'manual' | 'motor';
}
```

El fingerprint coincide exactamente con las columnas de `BOMTemplates`:
- `product_type` (text)
- `headbox_type` (enum: 'none' | 'cassette')
- `system_size` (enum: 's' | 'm' | 'l' | 'xl')
- `color` (text)
- `side_channel_mode` (enum: 'none' | 'side_only' | 'side_plus_bottom')
- `operating_system` (enum: 'manual' | 'motor')

### 2. Resolución de Templates (`src/lib/bom/resolveBomTemplate.ts`)

```typescript
resolveBomTemplate(organizationId, productTypeId, fingerprint)
```

- Busca `BOMTemplate` con match exacto del fingerprint
- Filtra por: `is_active=true`, `deleted=false`, `archived=false`
- Obtiene `BOMTemplateSlots` asociados
- Retorna template completo con slots

### 3. Generación de BOM (`src/lib/bom/generateBomInstance.ts`)

```typescript
generateBomInstance({ organizationId, quoteLineId, template, configState })
```

- Crea/actualiza `BOMInstance` (soft-delete de previos)
- Por cada `BOMTemplateSlot`:
  - Si `slot.catalog_item_id` existe → usa ese SKU fijo
  - Si usuario seleccionó el role → usa la selección del usuario
  - Fallback → primer `CatalogItem` activo con ese `item_role`
- Crea `BOMInstanceLines` con qty, costs, cut dimensions

### 4. Creación de QuoteLine (`src/lib/bom/createQuoteLineFromRollerConfig.ts`)

```typescript
createQuoteLineFromRollerConfig({ organizationId, quoteId, config, customerType, costSettings, editingLineId })
```

Flujo completo:
1. Valida fabric, measurements, product_type_id
2. Obtiene `CatalogItem` y MSRP
3. Calcula pricing (tier discounts, margins)
4. Crea/actualiza `QuoteLine` con snapshots de pricing
5. Guarda opciones en `QuoteLineComponents` (kind='option')
6. Genera `BOMInstance` usando fingerprint

### 5. Componente Principal (`src/components/configurator/RollerBOMConfigurator.tsx`)

Wizard de 5 pasos:
1. **ProductType** - Selecciona 'roller'
2. **Measurements** - Width/Height (mm → m)
3. **Fabric** - Collection + Variant (dropdown con search + cards)
4. **Hardware** - Headbox, System Size, Color, Bottom Bar, Side Channel
5. **Operating System** - Manual/Motor + selección de componentes

### 6. Steps Individuales

- `ProductTypeStep.tsx` - Cards de product types (filtrados por 'roller')
- `MeasurementsStep.tsx` - Inputs de width/height, mount type, location
- `FabricStep.tsx` - Dropdown con search para collections + cards de variants
- `HardwareStep.tsx` - Cards para todas las opciones de hardware
- `OperatingSystemStep.tsx` - Cards para motor/drive/tube

### 7. Hook de Catalog Items (`src/hooks/useRollerCatalogItems.ts`)

```typescript
useRollerCatalogItems({ organizationId, role, color, enabled })
```

- Fetch dinámico de `CatalogItems` por `item_role`
- Filtra por `color` si se especifica
- Solo items activos (`is_active=true`)
- Retorna `CatalogItemOption[]` para cards

### 8. Roles Canónicos Actualizados (`src/lib/bom/roles.ts`)

Lista completa según especificación (todo en minúsculas):
```typescript
CANONICAL_COMPONENT_ROLES = [
  'tube', 'track', 'bottom_bar', 'bottom_channel', 'hem_weight',
  'side_channel', 'top_rail', 'headbox', 'bracket', 'idler',
  'drive', 'motor', 'chain', 'chain_stop', 'chain_tensioner',
  'wand', 'end_cap', 'filler', 'tape', 'consumable', 'fastener',
  'accessory', 'carrier', 'belt', 'belt_connector', 'hook', 'brush', 'fabric'
]
```

## Integración con QuoteNew

### Estado Agregado

```typescript
const [useRollerBOM, setUseRollerBOM] = useState(true); // Toggle
const [initialRollerConfig, setInitialRollerConfig] = useState<Partial<RollerBOMConfigState> | undefined>(undefined);
```

### Handler Nuevo

```typescript
const handleRollerBOMConfigComplete = async (rollerConfig) => {
  // Usa createQuoteLineFromRollerConfig para:
  // - Crear QuoteLine
  // - Guardar options
  // - Generar BOMInstance
}
```

### UI

```tsx
{showConfigurator && quoteId && (
  <>
    {useRollerBOM ? (
      <RollerBOMConfigurator
        quoteId={quoteId}
        onComplete={handleRollerBOMConfigComplete}
        onClose={...}
        initialConfig={initialRollerConfig}
        editingLineId={editingLineId}
      />
    ) : (
      <ProductConfigurator ... /> // Legacy
    )}
  </>
)}
```

## Reglas de Negocio Implementadas

1. **Cassette → System Size 'm'**
   - Si `headbox_type='cassette'`, `system_size` se fuerza a 'm'
   - Otros system_sizes se deshabilitan en UI

2. **Bottom Channel requiere Side Channel**
   - `side_channel_mode` solo permite: 'none', 'side_only', 'side_plus_bottom'
   - No se puede seleccionar bottom sin side

3. **Validaciones de Completitud**
   - Measurements: width_mm, height_mm requeridos
   - Fabric: fabric_catalog_item_id requerido
   - Cassette: headbox_item_id requerido si headbox_type='cassette'
   - Motor: motor_item_id requerido si operating_system='motor'
   - Manual: drive_item_id requerido si operating_system='manual'
   - Side Channel: side_channel_item_id requerido si mode != 'none'
   - Bottom Channel: bottom_channel_item_id requerido si mode='side_plus_bottom'

4. **Pricing**
   - MSRP obligatorio (bloquea si no existe)
   - Tier discounts por customer_type
   - Margin floor enforcement
   - Snapshots guardados en QuoteLine

## Uso

```tsx
// En QuoteNew.tsx
<RollerBOMConfigurator
  quoteId={quoteId}
  onComplete={async (config) => {
    // Crea QuoteLine + BOMInstance automáticamente
  }}
  onClose={() => setShowConfigurator(false)}
  initialConfig={optionalInitialConfig}
  editingLineId={optionalEditingLineId}
/>
```

## Testing Manual

1. Crear Quote nuevo
2. Click "Add Line"
3. Wizard de 5 pasos:
   - Seleccionar Roller product type
   - Ingresar measurements (ej: 2.5m × 3.0m)
   - Seleccionar collection + variant
   - Configurar hardware (cassette/none, size, color, bottom bar, side channel)
   - Seleccionar operating system (motor/manual) + componentes
4. Click "Generate BOM"
5. Verificar en DB:
   ```sql
   -- QuoteLine creado
   SELECT * FROM "QuoteLines" WHERE quote_id = '<quote_id>' ORDER BY created_at DESC LIMIT 1;
   
   -- Options guardadas
   SELECT component_role, payload FROM "QuoteLineComponents" 
   WHERE quote_line_id = '<line_id>' AND kind='option' AND deleted=false;
   
   -- BOMInstance creado
   SELECT * FROM "BOMInstances" WHERE quote_line_id = '<line_id>' AND deleted=false;
   
   -- BOMInstanceLines creadas
   SELECT part_role, qty, resolved_part_id FROM "BOMInstanceLines" 
   WHERE bom_instance_id = '<instance_id>';
   ```

## Notas Técnicas

- **BOMInstances no tiene columna `metadata`**: Las selecciones se usan para resolver SKUs; el metadata puede agregarse después si se necesita.
- **BOMTemplateSlots vs BOMComponents**: Esta implementación usa `BOMTemplateSlots` (tabla más simple). Si necesitas migrar a `BOMComponents`, ajusta `resolveBomTemplate.ts` para usar la query correcta.
- **Roles canónicos**: Todo en minúsculas, sin legacy roles.
- **Toggle dev**: En desarrollo, hay un botón para alternar entre el nuevo configurador y el legacy.

## Próximos Pasos

1. Poblar `BOMTemplates` con todos los fingerprints necesarios
2. Poblar `BOMTemplateSlots` para cada template
3. Asegurar que todos los `CatalogItems` tienen `item_role` correcto
4. Testing exhaustivo de todas las combinaciones
5. Eliminar ProductConfigurator legacy cuando esté estable
