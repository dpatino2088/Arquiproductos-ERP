# Implementación: UI de Rates con Normalización de UOM

**Fecha:** 2026-02-02  
**Objetivo:** Mostrar SIEMPRE los precios normalizados del sistema en Catalog > Edit Item > tab "Rates"

---

## 1. Resumen Ejecutivo

Se implementó una nueva UI para el tab "Rates" en CatalogItemNew que:

1. **Normaliza rates al sistema UOM** según tipo de ítem:
   - Rolls: $/m (per_linear_meter) o $/m² (per_square_meter) o $/ea (per_unit) según `roll_pricing_mode`
   - Tubes/Profiles/Tracks/Headbox (lineales): $/m
   - Piezas unitarias: $/ea

2. **Muestra trazabilidad**:
   - System Rate (principal) - usado para cálculos
   - User Input Rate (opcional, informativo) - para conversiones desde otras unidades

3. **Helpers centralizados** para conversiones UOM:
   - `toMeters()`, `toSquareMeters()`, `normalizeRateToSystem()`
   - Soporte para: m, cm, mm, in, ft, yd (lineales y áreas)

4. **Validaciones** según tipo de ítem y `roll_pricing_mode`

---

## 2. Archivos Creados/Modificados

### 2.1 Archivos Nuevos

#### `src/lib/uom-conversions.ts` (nuevo)
Helpers de conversión de unidades:

- **`toMeters(value, uom)`**: Convierte cualquier medida lineal a metros
- **`toSquareMeters(width, width_uom, height, height_uom)`**: Convierte dimensiones a m²
- **`toSquareMetersFromArea(value, uom)`**: Convierte medida de área a m²
- **`normalizeRateToSystem(value, from_uom, target_uom)`**: Normaliza un rate/precio a UOM de sistema
- **`determineSystemUOM(item)`**: Determina la UOM de sistema según propiedades del ítem
- **`formatSystemUOM(uom)`**, **`formatUserUOM(uom)`**: Formateo para display
- **`isCompatibleUOM(user_uom, system_uom)`**: Valida compatibilidad de UOMs

**Soporte de unidades:**
- Lineales: m, cm, mm, in, ft, yd
- Áreas: m², cm², mm², in², ft², yd²
- Unidades: ea, pcs, unit, piece

#### `src/types/rates.ts` (nuevo)
Tipos TypeScript para rates:

- **`SystemUOM`**: 'm' | 'm2' | 'ea'
- **`CatalogItemRate`**: Modelo de rate con system + user values
- **`CatalogItemWithRate`**: Ítem de catálogo extendido con rate
- **`validateRate()`**: Validación de rate según tipo de ítem

### 2.2 Archivos Modificados

#### `src/pages/catalog/CatalogItemNew.tsx`

**Cambios en schema:**
- Corregido: `fabric_pricing_mode` → **`roll_pricing_mode`** (valores reales de BD)
- Enum correcto: `'per_linear_meter'` | `'per_square_meter'` | `'per_unit'`

**Nuevo estado para rates:**
```typescript
const [systemUOM, setSystemUOM] = useState<SystemUOM>('ea');
const [rateSystemValue, setRateSystemValue] = useState<string>('');
const [rateUserValue, setRateUserValue] = useState<string>('');
const [rateUserUOM, setRateUserUOM] = useState<string>('');
const [rateValidationError, setRateValidationError] = useState<string | null>(null);
```

**Nuevo useEffect:**
- Determina `systemUOM` automáticamente según `is_roll`, `roll_pricing_mode`, `measure_basis`
- Sincroniza `rateSystemValue` con `cost_exw` (legacy compatibility)

**Nueva UI en tab "Rates":**

1. **System Rate (Normalized)** - Input principal
   - Muestra `${systemUOM}` determinado automáticamente
   - Sincroniza con `cost_exw` para backward compatibility
   - Descripción contextual según tipo (roll/linear/unit)

2. **User Input (Optional)** - Input secundario
   - Permite ingresar rate en unidad preferida del usuario ($/ft, $/yd, etc.)
   - Auto-convierte a system rate usando `normalizeRateToSystem()`
   - Validación de UOM compatible

3. **Rates Summary Table**
   - Columnas: System Unit | System Rate | User Unit (info) | User Rate (info)
   - System Rate en grande (principal)
   - User Rate en pequeño (secundario, informativo)

4. **Validación**
   - Warning si roll item sin `roll_pricing_mode`
   - Error si User UOM no compatible con System UOM

5. **MSRP Section** (sin cambios)
   - Mantiene display de CatalogItemsMSRP (read-only, computed backend)

**Profile tab:**
- Selector de `roll_pricing_mode` actualizado con valores correctos:
  - 'per_linear_meter'
  - 'per_square_meter'
  - 'per_unit'

---

## 3. Lógica de Determinación de System UOM

```typescript
if (item.is_roll) {
  if (roll_pricing_mode === 'per_square_meter') return 'm2';
  if (roll_pricing_mode === 'per_linear_meter') return 'm';
  if (roll_pricing_mode === 'per_unit') return 'ea';
  // Default: fabric → m2, otros → m
  return is_fabric ? 'm2' : 'm';
}

if (measure_basis === 'linear') return 'm';

if (category/role matches: tube|profile|track|headbox|rail|cassette|bottom|side) return 'm';

if (measure_basis === 'area') return 'm2';

return 'ea'; // default
```

---

## 4. Flujo de Conversión de Rates

### Ejemplo 1: Roll fabric con per_square_meter

1. User entra: **$5.50/ft²**
2. Sistema determina: `systemUOM = 'm2'` (porque `roll_pricing_mode = 'per_square_meter'`)
3. Conversión: `$5.50/ft² → $59.20/m²` (usando `normalizeRateToSystem()`)
4. Display principal: **$59.20/m²** (System Rate)
5. Display secundario: **$5.50/ft²** (User Rate, info)

### Ejemplo 2: Tube con measure_basis = 'linear'

1. User entra: **$10/ft**
2. Sistema determina: `systemUOM = 'm'` (porque `measure_basis = 'linear'`)
3. Conversión: `$10/ft → $32.81/m`
4. Display principal: **$32.81/m** (System Rate)
5. Display secundario: **$10/ft** (User Rate, info)

### Ejemplo 3: Accesorio unitario

1. User entra: **$2/ea**
2. Sistema determina: `systemUOM = 'ea'` (porque `measure_basis = 'unit'`)
3. No conversión (ya en system unit)
4. Display: **$2/ea**

---

## 5. Validaciones Implementadas

### En `validateRate()`

- ✅ Roll sin `roll_pricing_mode` → Error
- ✅ Roll con `per_square_meter` → System UOM debe ser 'm2'
- ✅ Roll con `per_linear_meter` → System UOM debe ser 'm'
- ✅ Roll con `per_unit` → System UOM debe ser 'ea'
- ✅ Linear item → System UOM debe ser 'm'
- ✅ Unit item → System UOM debe ser 'ea'
- ✅ Rate value negativo → Error
- ✅ User UOM sin value → Warning

### En UI

- ⚠️ Warning si `is_roll = true` y `roll_pricing_mode = null`
- ❌ Error si User UOM no compatible con System UOM (ej. ingresar 'm2' cuando system es 'm')

---

## 6. Backward Compatibility

### Con `cost_exw` (legacy)

- `rateSystemValue` se sincroniza con `cost_exw` automáticamente
- Al cambiar `rateSystemValue`, se actualiza `cost_exw` vía `setValue('cost_exw', numValue)`
- Esto asegura que:
  - Backend triggers que usan `cost_exw` siguen funcionando
  - `compute_quote_line_cost()` sigue usando `cost_exw * computed_qty`
  - `msrp_compute_for_item()` sigue usando `cost_exw` como base

### Con `CatalogItemConversions`

- La tabla ya existe en BD y se actualiza automáticamente vía trigger `catalogitems_write_conversions`
- Guarda: `cost_exw_per_m`, `cost_exw_per_m2` (computed desde `cost_exw`, `unit_of_measure`, `roll_width`)
- **La UI NO escribe directamente** en `CatalogItemConversions`; solo lee `cost_exw` legacy
- Cuando el motor de pricing se modifique (siguiente fase), podrá usar `cost_exw_per_m` / `cost_exw_per_m2` directamente

---

## 7. No Cambios en Backend (según requisito)

- ✅ NO se modificó `compute_quote_line_cost()`
- ✅ NO se modificó `calculate_quote_line_price()`
- ✅ NO se modificó `msrp_compute_for_item()`
- ✅ NO se modificaron triggers de costing

**Solo UI + normalización/visualización.** El backend sigue usando `cost_exw` como único valor.

---

## 8. Próximos Pasos (Motor de Pricing)

Cuando se modifique el motor (fuera de scope de este PR):

1. **`compute_quote_line_cost()`** (archivo: `database/migrations/55_update_compute_cost_with_bom.sql`):
   - En rama ELSE (sin BOM), sustituir:
     ```sql
     v_base_material_cost := cost_exw * GREATEST(computed_qty, qty, 1)
     ```
   - Por lógica que use `roll_pricing_mode` y `CatalogItemConversions`:
     ```sql
     -- Si roll con per_square_meter:
     v_base_material_cost := cost_exw_per_m2 * computed_qty_m2
     
     -- Si roll con per_linear_meter:
     v_base_material_cost := cost_exw_per_m * computed_qty_m
     
     -- Si roll con per_unit o item regular:
     v_base_material_cost := cost_exw * qty
     ```

2. **`get_unit_cost_in_uom()`** (archivo: `database/migrations/200_robust_uom_fabric_pricing_model.sql`):
   - Opcional: usar `CatalogItemConversions.cost_exw_per_m` / `cost_exw_per_m2` directamente en lugar de derivar desde `cost_exw + roll_width`

3. **Frontend (`src/lib/pricing.ts`):**
   - `calculateQuoteLinePrice()` ya usa `catalogItem.cost_exw`, no requiere cambios si el backend actualiza `cost_exw` apropiadamente
   - O, si se prefiere, se puede extender para usar `cost_exw_per_m` / `cost_exw_per_m2` desde un nuevo campo en la respuesta

---

## 9. Testing

### Manual Testing Checklist

- [ ] Crear roll fabric con `roll_pricing_mode = 'per_square_meter'`
  - [ ] Verificar que System Unit = $/m²
  - [ ] Ingresar User Rate en $/ft², verificar auto-conversión a $/m²
  
- [ ] Crear roll fabric con `roll_pricing_mode = 'per_linear_meter'`
  - [ ] Verificar que System Unit = $/m
  - [ ] Ingresar User Rate en $/ft, verificar auto-conversión a $/m
  
- [ ] Crear tube con `measure_basis = 'linear'`
  - [ ] Verificar que System Unit = $/m
  
- [ ] Crear accessory con `measure_basis = 'unit'`
  - [ ] Verificar que System Unit = $/ea
  
- [ ] Editar item existente, verificar que `cost_exw` se mantiene sincronizado
  
- [ ] Guardar item, verificar que:
  - [ ] `CatalogItems.cost_exw` se guarda correctamente
  - [ ] `CatalogItemConversions` se actualiza automáticamente (vía trigger backend)
  - [ ] `CatalogItemsMSRP` se recomputa correctamente (vía trigger backend)

---

## 10. Resumen de Entregables

### Código

✅ **3 archivos nuevos:**
- `src/lib/uom-conversions.ts` (helpers de conversión)
- `src/types/rates.ts` (tipos TypeScript)
- `IMPLEMENTACION_RATES_UI_NORMALIZACION.md` (este documento)

✅ **1 archivo modificado:**
- `src/pages/catalog/CatalogItemNew.tsx` (tab Rates + schema)

### Features

✅ **UI de Rates normalizada:**
- System Rate (principal)
- User Input Rate (opcional, informativo)
- Tabla resumen con ambas unidades
- Auto-conversión entre UOMs
- Validaciones por tipo de ítem

✅ **Helpers centralizados:**
- Conversión lineal/área/unidad
- Determinación automática de System UOM
- Validación de compatibilidad de UOMs

✅ **Backward compatibility:**
- Sincronización con `cost_exw` legacy
- No cambios en backend (solo UI)

### Documentación

✅ **Este documento incluye:**
- Resumen ejecutivo
- Archivos creados/modificados
- Lógica de determinación de System UOM
- Flujos de conversión (ejemplos)
- Validaciones implementadas
- Backward compatibility strategy
- Testing checklist
- Próximos pasos (motor de pricing)

---

## 11. Notas Técnicas

### Schema de BD (verificado contra dump 2026-02-02)

```sql
CREATE TABLE "CatalogItems" (
  roll_pricing_mode text,
  roll_width numeric(12,4),
  cost_exw numeric(12,4),
  ...
  CONSTRAINT catalogitems_roll_pricing_mode_chk 
    CHECK (roll_pricing_mode IS NULL OR 
           roll_pricing_mode IN ('per_linear_meter', 'per_square_meter', 'per_unit'))
);

CREATE TABLE "CatalogItemConversions" (
  catalog_item_id uuid PRIMARY KEY,
  organization_id uuid NOT NULL,
  cost_exw_input numeric,
  unit_of_measure_input text,
  roll_width_input numeric,
  cost_exw_per_m numeric,        -- ✅ Ya calculado por backend
  cost_exw_per_m2 numeric,       -- ✅ Ya calculado por backend
  computed_at timestamptz
);
```

### Función Backend (ya existe, no modificada)

```sql
CREATE FUNCTION compute_roll_conversions(
  p_cost_exw numeric, 
  p_uom text, 
  p_roll_width numeric
) 
RETURNS TABLE(cost_exw_per_m numeric, cost_exw_per_m2 numeric);
```

### Trigger Backend (ya existe, no modificado)

```sql
CREATE TRIGGER catalogitems_write_conversions
AFTER INSERT OR UPDATE OF cost_exw, unit_of_measure, roll_width, is_roll 
ON "CatalogItems"
FOR EACH ROW 
EXECUTE FUNCTION trg_catalogitems_write_conversions();
```

---

## 12. Correcciones Post-Implementación (2026-02-02)

### Problemas Identificados

Durante la revisión del dump actualizado y testing de la UI, se identificaron los siguientes problemas:

1. **Selector de `roll_pricing_mode` restringido solo a fabric**:
   - ❌ Solo visible cuando `rollType === 'fabric'`
   - ✅ **Fix:** Ahora visible para TODOS los tipos de roll

2. **Lógica de guardado incorrecta**:
   - ❌ `roll_pricing_mode` solo se guardaba si `roll_type === 'fabric'`
   - ✅ **Fix:** Ahora se guarda para todos los rolls

3. **Falta de validación en schema**:
   - ❌ No había validación para requerir `roll_pricing_mode` cuando `is_roll = true`
   - ✅ **Fix:** Agregada validación `.refine()` en Zod schema

4. **Falta de feedback visual**:
   - ❌ No se mostraban errores de validación en UI
   - ✅ **Fix:** Agregado mensaje de error debajo del selector

### Archivos con Correcciones

**`src/pages/catalog/CatalogItemNew.tsx`:**

1. **Profile Tab** (líneas ~968-995):
   ```typescript
   {/* Roll Pricing Mode - Available for ALL roll types */}
   <div className="col-span-4">
     <Label htmlFor="roll_pricing_mode" className="text-xs">Roll Pricing Mode *</Label>
     <SelectShadcn
       value={watch('roll_pricing_mode') || ''}
       onValueChange={(value) => setValue('roll_pricing_mode', value as any)}
       disabled={isReadOnly}
     >
       <SelectTrigger className="h-auto py-1 text-xs">
         <SelectValue placeholder="Select mode" />
       </SelectTrigger>
       <SelectContent>
         <SelectItem value="per_linear_meter">Per Linear Meter ($/m)</SelectItem>
         <SelectItem value="per_square_meter">Per Square Meter ($/m²)</SelectItem>
         <SelectItem value="per_unit">Per Unit ($/ea)</SelectItem>
       </SelectContent>
     </SelectShadcn>
     <p className="text-xs text-gray-500 mt-1">
       How this roll is priced in quotes. Determines the system rate unit.
     </p>
     {errors.roll_pricing_mode && (
       <p className="text-xs text-red-600 mt-1">{errors.roll_pricing_mode.message}</p>
     )}
   </div>
   ```

2. **onSubmit** (línea ~573):
   ```typescript
   roll_pricing_mode: values.is_roll ? values.roll_pricing_mode : null,
   ```

3. **Zod Schema** (líneas ~96-106):
   ```typescript
   .refine((data) => {
     // If is_roll=true, roll_pricing_mode is required
     if (data.is_roll && !data.roll_pricing_mode) return false;
     return true;
   }, {
     message: 'Roll pricing mode is required for roll items',
     path: ['roll_pricing_mode'],
   })
   ```

### Archivos Adicionales Creados

- ✅ `FIX_RATES_ROLL_PRICING_MODE.md` - Documentación completa de las correcciones
- ✅ `scripts/verify_roll_pricing_modes.sql` - Script de verificación SQL

### Testing Post-Fix

Ejecutar checklist completo en `FIX_RATES_ROLL_PRICING_MODE.md` sección "Testing".

---

**Implementación completada:** 2026-02-02  
**Correcciones aplicadas:** 2026-02-02  
**Próximo paso:** Modificar motor de pricing para usar `roll_pricing_mode` + `CatalogItemConversions`  
(Ver: `INFORME_PRICING_QUOTE_CATALOG_ITEM.md` punto 5 para ubicación exacta de intervención)
