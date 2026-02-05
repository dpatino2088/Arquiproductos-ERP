# Fix: Rates UI - Roll Pricing Mode Corrections

**Fecha:** 2026-02-02  
**Tipo:** Bug Fix + Enhancement  
**Archivos modificados:** `src/pages/catalog/CatalogItemNew.tsx`

---

## Resumen Ejecutivo

Se corrigieron errores críticos en la implementación de Rates UI que impedían que `roll_pricing_mode` funcionara correctamente para rolls que no fueran de tipo "fabric". 

### Problemas Identificados:

1. **Selector de `roll_pricing_mode` restringido**: Solo se mostraba para `rollType === 'fabric'`, pero debería estar disponible para **TODOS** los tipos de roll (fabric, window_film, vinyl, mesh, paper, other).

2. **Lógica de guardado incorrecta**: El campo `roll_pricing_mode` solo se guardaba si el roll era de tipo 'fabric':
   ```typescript
   roll_pricing_mode: values.is_roll && values.roll_type === 'fabric' ? values.roll_pricing_mode : null,
   ```

3. **Falta de validación**: No había validación en el schema de Zod para requerir `roll_pricing_mode` cuando `is_roll` es true.

4. **Falta de feedback visual**: No se mostraban errores de validación al usuario cuando faltaba el `roll_pricing_mode`.

### Impacto:

- ❌ Rolls de tipo "window_film", "vinyl", "mesh", etc. no podían tener `roll_pricing_mode` configurado
- ❌ La UI de Rates mostraba "Missing Roll Pricing Mode" incluso después de seleccionar un valor
- ❌ El `systemUOM` se determinaba incorrectamente para rolls no-fabric
- ❌ Los cálculos de precio no funcionaban correctamente para estos items

---

## Solución Implementada

### 1. Selector de Roll Pricing Mode (Profile Tab)

**Antes:**
```tsx
{rollType === 'fabric' && (
  <div className="col-span-4">
    <Label htmlFor="roll_pricing_mode" className="text-xs">Roll Pricing Mode</Label>
    <SelectShadcn
      value={watch('roll_pricing_mode') || ''}
      onValueChange={(value) => setValue('roll_pricing_mode', value as any)}
      disabled={isReadOnly}
    >
      <SelectTrigger className="h-auto py-1 text-xs">
        <SelectValue placeholder="Select mode" />
      </SelectTrigger>
      <SelectContent>
        <SelectItem value="per_linear_meter">Per Linear Meter</SelectItem>
        <SelectItem value="per_square_meter">Per Square Meter</SelectItem>
        <SelectItem value="per_unit">Per Unit</SelectItem>
      </SelectContent>
    </SelectShadcn>
  </div>
)}
```

**Después:**
```tsx
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

**Cambios:**
- ✅ Removida condición `rollType === 'fabric'` - ahora visible para TODOS los rolls
- ✅ Agregado asterisco (*) para indicar campo requerido
- ✅ Agregadas unidades de medida en las opciones: ($/m), ($/m²), ($/ea)
- ✅ Agregado texto de ayuda explicativo
- ✅ Agregado mensaje de error de validación

### 2. Lógica de Guardado (onSubmit)

**Antes:**
```typescript
roll_pricing_mode: values.is_roll && values.roll_type === 'fabric' ? values.roll_pricing_mode : null,
```

**Después:**
```typescript
roll_pricing_mode: values.is_roll ? values.roll_pricing_mode : null,
```

**Cambios:**
- ✅ Removida restricción `values.roll_type === 'fabric'`
- ✅ Ahora se guarda `roll_pricing_mode` para TODOS los rolls

### 3. Validación en Schema de Zod

**Agregado:**
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

**Cambios:**
- ✅ Nueva validación que requiere `roll_pricing_mode` cuando `is_roll` es true
- ✅ Mensaje de error claro para el usuario

---

## Integración con Backend

### Trigger de Base de Datos

El trigger `trg_catalogitems_validate_roll_pricing_mode` (ya existente en BD) funciona como fallback:

```sql
CREATE OR REPLACE FUNCTION "public"."trg_catalogitems_validate_roll_pricing_mode"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.is_roll then
    if new.roll_pricing_mode is null then
      new.roll_pricing_mode := 'per_linear_meter';
    end if;
    
    if new.roll_pricing_mode = 'per_square_meter' then
      if new.roll_width is null or new.roll_width <= 0 then
        raise exception 'roll_width is required (>0, meters) when roll_pricing_mode = per_square_meter';
      end if;
    end if;
  else
    new.roll_pricing_mode := null;
  end if;
  
  return new;
end;
$$;
```

**Comportamiento:**
- ✅ Si `is_roll = true` y `roll_pricing_mode` es null → establece 'per_linear_meter' por defecto
- ✅ Si `roll_pricing_mode = 'per_square_meter'` → valida que `roll_width > 0`
- ✅ Si `is_roll = false` → establece `roll_pricing_mode = null`

### Tabla CatalogItemConversions

El trigger `catalogitems_write_conversions` (ya existente) se ejecuta automáticamente:

```sql
CREATE TRIGGER catalogitems_write_conversions
AFTER INSERT OR UPDATE OF cost_exw, unit_of_measure, roll_width, is_roll 
ON "CatalogItems"
FOR EACH ROW 
EXECUTE FUNCTION trg_catalogitems_write_conversions();
```

**Comportamiento:**
- ✅ Calcula automáticamente `cost_exw_per_m` y `cost_exw_per_m2`
- ✅ Guarda en `CatalogItemConversions` para uso futuro del motor de pricing

---

## Flujo Completo (Usuario)

### Crear Nuevo Roll (Ejemplo: Window Film)

1. **Profile Tab:**
   - Marcar checkbox "Is Roll"
   - Seleccionar "Roll Type" = "window_film"
   - **NUEVO:** Selector de "Roll Pricing Mode" ahora visible
   - Seleccionar "Per Linear Meter ($/m)" o "Per Square Meter ($/m²)"
   - Si selecciona "Per Square Meter", ingresar `roll_width` (requerido)

2. **Rates Tab:**
   - System UOM se determina automáticamente según `roll_pricing_mode`:
     - `per_linear_meter` → $/m
     - `per_square_meter` → $/m²
     - `per_unit` → $/ea
   - Ingresar "System Rate" en la unidad determinada
   - Opcionalmente: ingresar "User Input" en otra unidad (ej. $/ft) para conversión automática

3. **Guardar:**
   - ✅ `roll_pricing_mode` se guarda correctamente
   - ✅ Trigger de BD valida y establece default si es null (fallback)
   - ✅ Trigger calcula conversiones en `CatalogItemConversions`
   - ✅ No se muestra "Missing Roll Pricing Mode" en Rates tab

### Editar Roll Existente (Sin roll_pricing_mode)

1. **Al cargar:**
   - Si el roll en BD tiene `roll_pricing_mode = null`
   - El trigger de BD establece 'per_linear_meter' por defecto al cargar
   - UI muestra valor por defecto o permite seleccionar

2. **Editar:**
   - Usuario puede cambiar `roll_pricing_mode` según necesidad
   - Si cambia de 'per_linear_meter' a 'per_square_meter' → debe ingresar `roll_width`
   - Validaciones se ejecutan en tiempo real

3. **Guardar:**
   - ✅ Nuevo `roll_pricing_mode` se guarda
   - ✅ System UOM se actualiza automáticamente en Rates tab
   - ✅ Conversiones se recalculan en `CatalogItemConversions`

---

## Testing

### Checklist de Validación

#### 1. Crear Nuevos Rolls

- [ ] **Roll Fabric** con `roll_pricing_mode = 'per_square_meter'`
  - [ ] Selector visible y funcional en Profile tab
  - [ ] Requiere `roll_width > 0`
  - [ ] System UOM = $/m² en Rates tab
  - [ ] Se guarda correctamente en BD
  - [ ] No muestra "Missing Roll Pricing Mode"

- [ ] **Roll Window Film** con `roll_pricing_mode = 'per_linear_meter'`
  - [ ] Selector visible y funcional en Profile tab
  - [ ] System UOM = $/m en Rates tab
  - [ ] Se guarda correctamente en BD

- [ ] **Roll Vinyl** con `roll_pricing_mode = 'per_unit'`
  - [ ] Selector visible y funcional en Profile tab
  - [ ] System UOM = $/ea en Rates tab
  - [ ] Se guarda correctamente en BD

- [ ] **Roll Mesh** sin `roll_pricing_mode` (dejar vacío al crear)
  - [ ] Trigger de BD establece 'per_linear_meter' por defecto
  - [ ] System UOM = $/m en Rates tab
  - [ ] Validación de frontend pide seleccionar explícitamente (mejora UX)

#### 2. Editar Rolls Existentes

- [ ] Editar roll fabric existente
  - [ ] `roll_pricing_mode` se carga correctamente
  - [ ] Puede cambiar entre modos
  - [ ] Cambios se guardan correctamente

- [ ] Editar roll window_film sin `roll_pricing_mode`
  - [ ] Trigger establece default al cargar
  - [ ] Puede seleccionar explícitamente
  - [ ] Se guarda correctamente

#### 3. Validaciones

- [ ] Intentar crear roll sin `roll_pricing_mode`
  - [ ] Muestra error de validación en Profile tab
  - [ ] No permite guardar hasta que se seleccione

- [ ] Seleccionar `per_square_meter` sin `roll_width`
  - [ ] Trigger de BD rechaza con error
  - [ ] UI muestra mensaje de error apropiado

- [ ] Cambiar de roll a no-roll
  - [ ] `roll_pricing_mode` se limpia (null)
  - [ ] No se muestra en UI
  - [ ] System UOM cambia a 'ea' (default)

#### 4. Integración con Rates Tab

- [ ] Cambiar `roll_pricing_mode` en Profile tab
  - [ ] System UOM en Rates tab se actualiza automáticamente
  - [ ] Conversiones de User Input a System Rate funcionan correctamente
  - [ ] Warning "Missing Roll Pricing Mode" desaparece

- [ ] Ingresar User Input en $/ft con `roll_pricing_mode = 'per_linear_meter'`
  - [ ] Conversión a $/m funciona correctamente
  - [ ] System Rate se actualiza
  - [ ] `cost_exw` se sincroniza

- [ ] Ingresar User Input en $/ft² con `roll_pricing_mode = 'per_square_meter'`
  - [ ] Conversión a $/m² funciona correctamente
  - [ ] System Rate se actualiza
  - [ ] `cost_exw` se sincroniza

#### 5. Backend y Triggers

- [ ] Verificar en BD después de guardar:
  - [ ] `CatalogItems.roll_pricing_mode` tiene valor correcto
  - [ ] `CatalogItemConversions.cost_exw_per_m` calculado correctamente
  - [ ] `CatalogItemConversions.cost_exw_per_m2` calculado correctamente
  - [ ] `CatalogItemsMSRP` recomputado si aplica

---

## Próximos Pasos

### Fase Actual: ✅ UI Normalizada (Completado)

- ✅ Selector de `roll_pricing_mode` funcional para todos los rolls
- ✅ Validaciones en frontend y backend
- ✅ Sincronización con `cost_exw` (legacy)
- ✅ Conversiones UOM funcionando
- ✅ Feedback visual completo para usuario

### Fase Siguiente: Motor de Pricing (Pendiente)

Según `IMPLEMENTACION_RATES_UI_NORMALIZACION.md` sección 8 "Próximos Pasos":

1. **Modificar `compute_quote_line_cost()`** (archivo: `database/migrations/55_update_compute_cost_with_bom.sql`):
   - Sustituir lógica simple `cost_exw * qty`
   - Usar `roll_pricing_mode` + `CatalogItemConversions`
   - Aplicar rate correcto según tipo de medida

2. **Actualizar `get_unit_cost_in_uom()`** (archivo: `database/migrations/200_robust_uom_fabric_pricing_model.sql`):
   - Opcional: usar `cost_exw_per_m` / `cost_exw_per_m2` directamente
   - Eliminar derivación desde `cost_exw + roll_width`

3. **Frontend `calculateQuoteLinePrice()`** (archivo: `src/lib/pricing.ts`):
   - Ya usa `catalogItem.cost_exw`, no requiere cambios si backend actualiza correctamente
   - O extender para usar nuevos campos si backend los expone

---

## Archivos Modificados

### `src/pages/catalog/CatalogItemNew.tsx`

**Cambios realizados:**

1. **Líneas ~968-995** (Profile Tab - Roll Section):
   - Removida condición `rollType === 'fabric'`
   - Selector ahora visible para TODOS los rolls
   - Agregadas descripciones en opciones
   - Agregado texto de ayuda
   - Agregado mensaje de error de validación

2. **Línea ~573** (onSubmit):
   - Removida restricción `values.roll_type === 'fabric'`
   - Ahora guarda `roll_pricing_mode` para todos los rolls

3. **Líneas ~96-106** (Zod Schema):
   - Agregada validación `.refine()` para requerir `roll_pricing_mode` cuando `is_roll = true`

---

## Notas Técnicas

### Compatibilidad

- ✅ **Backward compatible**: Rolls existentes sin `roll_pricing_mode` obtienen default 'per_linear_meter' vía trigger
- ✅ **Forward compatible**: La tabla `CatalogItemConversions` ya existe y está lista para motor de pricing futuro
- ✅ **Legacy support**: `cost_exw` sigue sincronizado para compatibilidad con código legacy

### Restricciones de BD (Verificadas)

```sql
-- En CatalogItems
CONSTRAINT "catalogitems_roll_pricing_mode_chk" 
  CHECK ((roll_pricing_mode IS NULL) OR 
         (roll_pricing_mode IN ('per_linear_meter', 'per_square_meter', 'per_unit')))

-- Trigger valida roll_width cuando per_square_meter
if new.roll_pricing_mode = 'per_square_meter' then
  if new.roll_width is null or new.roll_width <= 0 then
    raise exception 'roll_width is required (>0, meters) when roll_pricing_mode = per_square_meter';
  end if;
end if;
```

### UOM Conversions (ya implementado en `src/lib/uom-conversions.ts`)

- ✅ `toMeters()`: cm, mm, in, ft, yd → m
- ✅ `toSquareMetersFromArea()`: cm², mm², in², ft², yd² → m²
- ✅ `normalizeRateToSystem()`: Convierte rates entre unidades
- ✅ `determineSystemUOM()`: Determina UOM de sistema según propiedades del item
- ✅ `isCompatibleUOM()`: Valida compatibilidad de UOMs

---

## Documentación Relacionada

- `IMPLEMENTACION_RATES_UI_NORMALIZACION.md` - Especificación completa de UI de Rates
- `INFORME_PRICING_QUOTE_CATALOG_ITEM.md` - Análisis de motor de pricing (próxima fase)
- `backups/2026-02_02_v1_full.sql` - Dump de BD con schema actual

---

**Fix completado:** 2026-02-02  
**Testeado:** Pendiente (ver checklist arriba)  
**Aprobado para producción:** Pendiente testing
