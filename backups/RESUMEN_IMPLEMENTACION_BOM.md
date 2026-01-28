# Resumen: Implementación Completa BOM Configurador

## 🎯 Objetivo Alcanzado

Se implementó un **configurador de BOM basado en fingerprints** que:
1. Permite configurar productos (Roller, Dual, Triple, Drapery) mediante wizard de 5 pasos
2. Resuelve templates usando match exacto de fingerprint (6 columnas)
3. Genera QuoteLine + BOMInstance + BOMInstanceLines en una transacción
4. Maneja pricing, validaciones, y opciones de configuración

## 📦 Archivos Creados

### Frontend (React/TypeScript)

1. **`src/lib/bom/types.ts`**
   - Tipos TypeScript para fingerprints, config state, slots, metadata

2. **`src/lib/bom/roles.ts`** (actualizado)
   - Roles canónicos según lista exacta del usuario (28 roles)

3. **`src/lib/bom/resolveBomTemplate.ts`**
   - `resolveBomTemplate(orgId, productTypeId, fingerprint)` → template + slots

4. **`src/lib/bom/generateBomInstance.ts`**
   - `generateBomInstance({ orgId, quoteLineId, template, configState })` → instanceId

5. **`src/lib/bom/createQuoteLineFromRollerConfig.ts`**
   - Flujo completo: valida, crea QuoteLine, guarda options, genera BOM

6. **`src/hooks/useRollerCatalogItems.ts`**
   - Hook para fetch dinámico de items por `item_role` + `color`

7. **`src/components/configurator/RollerBOMConfigurator.tsx`**
   - Wizard principal con 5 pasos, navegación, validaciones

8. **`src/components/configurator/steps/*.tsx`** (5 archivos)
   - ProductTypeStep: Selección de product type
   - MeasurementsStep: Width/Height inputs
   - FabricStep: Collection + Variant (dropdown + cards)
   - HardwareStep: Headbox, System Size, Color, Bottom Bar, Side Channel
   - OperatingSystemStep: Manual/Motor + Motor/Drive selection

9. **`src/pages/sales/QuoteNew.tsx`** (actualizado)
   - Integrado RollerBOMConfigurator
   - Toggle dev para alternar entre new y legacy
   - Handler `handleRollerBOMConfigComplete`

### Backend (SQL)

1. **`backups/populate_bom_fingerprints_and_slots.sql`** ⭐
   - **Script principal para ejecutar**
   - Actualiza BOMTemplates con fingerprints completos
   - Crea BOMTemplateSlots para cada template
   - Maneja conflictos de UNIQUE INDEX

2. **`backups/MAPPING_TEMPLATES_TO_FINGERPRINTS.md`**
   - Documentación completa del mapping
   - Tabla de todos los templates con fingerprints
   - Explicación de resolución de conflictos

3. **`backups/INSTRUCCIONES_POBLAR_BOM.md`**
   - Guía paso a paso para ejecutar los scripts
   - Queries de verificación
   - Testing manual

4. **`backups/bom_templates_optionA_fixed_v3.sql`** (existente, actualizado anteriormente)
   - Crea BOMComponents (legacy, para RPC)

## 🔧 Arquitectura Técnica

### Fingerprint (6 columnas)

```typescript
{
  product_type: 'roller' | 'dual' | 'triple' | 'drapery',
  headbox_type: 'none' | 'cassette',
  system_size: 's' | 'm' | 'l' | 'xl',
  color: 'white' | 'black' | etc,
  side_channel_mode: 'none' | 'side_only' | 'side_plus_bottom',
  operating_system: 'manual' | 'motor'
}
```

### BOMTemplateSlots (Nueva tabla)

| Column | Type | Descripción |
|--------|------|-------------|
| id | uuid | PK |
| organization_id | uuid | FK |
| bom_template_id | uuid | FK |
| item_role | text | Role del componente (tube, motor, drive, etc.) |
| required | boolean | Si el slot es requerido |
| catalog_item_id | uuid \| null | SKU fijo, o NULL si user-selectable |
| qty | numeric | Cantidad |
| notes | text | Notas opcionales |

### BOMComponents (Tabla existente - legacy)

Mantener para compatibilidad con RPC `generate_bom_instance_for_quote_line()`.

## 📊 Templates Creados

### Roller Shade (6 templates)
- ✅ ROLLER_MANUAL_M
- ✅ ROLLER_MANUAL_DOBLE_M (con side+bottom channel)
- ✅ ROLLER_MOTORIZADA_M
- ✅ ROLLER_MOTORIZADA_DOBLE_M (con side+bottom channel)
- ✅ MOTORIZADA_SENCILLA_L
- ✅ MOTORIZADA_DOBLE_L (con side+bottom channel)

### Dual Shade (2 templates)
- ✅ DOBLE_SHADE (sin cassette)
- ✅ DOBLE_SHADE_MOTORIZADA (con cassette)

### Triple Shade (2 templates)
- ✅ TRIPLE_SHADE
- ✅ TRIPLE_SHADE_DOBLE (con side+bottom channel)

### Drapery (5 templates)
- ✅ PA_O_FIJO_RIPPLE_Y_PLEAT (paño fijo, size S)
- ✅ RIEL_MANUAL_RIPPLE (white)
- ✅ RIEL_MANUAL_PLEAT (black)
- ✅ RIEL_MOTORIZADO_RIPPLE (white)
- ✅ RIEL_MOTORIZADO_PLEAT (black)

**Total: 15 templates**

## 🚀 Uso del Sistema

### 1. En QuoteNew

```tsx
// El toggle useRollerBOM está en true por defecto
<RollerBOMConfigurator
  quoteId={quoteId}
  onComplete={handleRollerBOMConfigComplete}
  onClose={() => setShowConfigurator(false)}
/>
```

### 2. Flujo de Usuario

1. Crear Quote
2. Click "Add Line"
3. Wizard de 5 pasos:
   - **Product Type**: Selecciona Roller
   - **Measurements**: 2.5m × 3.0m
   - **Fabric**: Collection → Variant
   - **Hardware**: 
     - Headbox: None/Cassette
     - System Size: M
     - Color: White
     - Bottom Bar: (select card)
     - Side Channel Mode: None/Side Only/Side+Bottom
   - **Operating System**:
     - Manual/Motor
     - Select Motor or Drive (cards)
     - Optional: Tube selection
4. Click "Generate BOM"
5. Sistema:
   - Construye fingerprint
   - Resuelve template (match exacto)
   - Crea QuoteLine con pricing
   - Guarda options en QuoteLineComponents
   - Genera BOMInstance
   - Crea BOMInstanceLines (resuelve SKUs por slot)

### 3. Resolución de SKUs en BOMInstanceLines

Por cada `BOMTemplateSlot`:

```
IF slot.catalog_item_id NOT NULL:
  → Usa ese SKU fijo
ELSE IF usuario seleccionó el role (motor, drive, headbox, etc):
  → Usa la selección del usuario
ELSE:
  → Fallback: primer CatalogItem activo con ese item_role
```

## 🔍 Verificación en BD

```sql
-- QuoteLine creado
SELECT 
  id, 
  quote_id, 
  catalog_item_id,
  width_m, 
  height_m,
  collection_name,
  variant_name,
  quantity,
  line_total
FROM "QuoteLines" 
WHERE quote_id = '<quote_id>' 
ORDER BY created_at DESC LIMIT 1;

-- Options guardadas
SELECT 
  component_role, 
  payload 
FROM "QuoteLineComponents" 
WHERE quote_line_id = '<line_id>' 
  AND kind='option' 
  AND deleted=false;

-- BOMInstance creado
SELECT 
  id, 
  bom_template_id,
  quote_line_id
FROM "BOMInstances" 
WHERE quote_line_id = '<line_id>' 
  AND deleted=false;

-- Template usado
SELECT 
  code, 
  name,
  product_type,
  headbox_type,
  system_size,
  color,
  side_channel_mode,
  operating_system
FROM "BOMTemplates"
WHERE id = (SELECT bom_template_id FROM "BOMInstances" WHERE quote_line_id='<line_id>' AND deleted=false);

-- BOMInstanceLines creadas
SELECT 
  part_role, 
  qty, 
  uom,
  ci.sku,
  ci.name as part_name,
  unit_cost_exw,
  total_cost_exw
FROM "BOMInstanceLines" bil
JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE bil.bom_instance_id = '<instance_id>';
```

## ⚠️ Notas Importantes

### Conflictos de Fingerprint Resueltos

- **Drapery**: Usamos diferentes `color` y `system_size` para evitar duplicados
- **Dual**: Separamos por `headbox_type` (none vs cassette)
- **Metadata**: Incluye `allows_color_override=true` y `style` para flexibilidad

### Metadata Importante

```json
{
  "defaults": {
    "tube_type": "RTU-42"  // Default para templates M
  },
  "rules": {
    "cassette_requires_system_size": "m",
    "bottom_channel_requires_side_channel": true
  },
  "pricing": {
    "bottom_bar_wrapped_pct": 0.08  // 8% surcharge
  },
  "style": "ripple" | "pleat" | "fixed",  // Solo drapery
  "priority": 10,  // Para desambiguar si hay match múltiple
  "allows_color_override": true  // Color es solo para uniqueness
}
```

### Compatibilidad

- ✅ Nueva UI usa BOMTemplateSlots
- ✅ RPC existente usa BOMComponents
- ✅ Ambos coexisten sin problemas
- ✅ Migración gradual posible

## 📝 TODOs Post-Implementación

1. 🔲 Verificar que todos los SKUs referenciados existen en CatalogItems
2. 🔲 Asegurar que todos los items tienen `item_role` correcto
3. 🔲 Testing exhaustivo de todas las combinaciones
4. 🔲 Ajustar fingerprints basándose en feedback real
5. 🔲 Considerar agregar más variantes de color (silver, bronze, etc.)
6. 🔲 Poblar SystemSizeRules para validaciones de capacidad
7. 🔲 Decidir si mantener ambos sistemas o migrar completamente a uno

## 🎉 Estado Actual

- ✅ **Frontend**: Completamente implementado y listo
- ✅ **Backend SQL**: Scripts listos para ejecutar
- ✅ **Documentación**: Completa
- ✅ **Integration**: QuoteNew actualizado
- 🔲 **Database**: Pendiente ejecutar scripts
- 🔲 **Testing**: Pendiente testing manual

El sistema está listo para usarse una vez ejecutados los scripts SQL.
