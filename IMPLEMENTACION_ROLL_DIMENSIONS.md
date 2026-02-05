# Implementación Roll Dimensions (Width & Length)

**Fecha:** 2026-02-02  
**Estado:** ✅ Completado

## Objetivo

Implementar soporte completo para dimensiones de roll (ancho y largo) con múltiples unidades de medida (m, yd, ft, in), con normalización automática a metros para cálculos internos.

## Cambios Realizados

### 1. Backend (Base de Datos)

**Columnas ya existentes en `CatalogItems`:**
- `roll_width_value` numeric - Valor de ancho ingresado por usuario
- `roll_width_uom` text - Unidad de medida (m/yd/ft/in)
- `roll_width_m` numeric - Ancho normalizado en metros (calculado por trigger)
- `roll_length_value` numeric - Valor de largo ingresado por usuario
- `roll_length_uom` text - Unidad de medida (m/yd/ft/in)
- `roll_length_m` numeric - Largo normalizado en metros (calculado por trigger)
- `roll_width` numeric - Campo legacy (compatibilidad)

**Constraints ya existentes:**
```sql
CONSTRAINT "catalogitems_roll_width_uom_chk" 
  CHECK ((roll_width_uom IS NULL) OR (roll_width_uom = ANY (ARRAY['m','yd','ft','in'])))

CONSTRAINT "catalogitems_roll_length_uom_chk" 
  CHECK ((roll_length_uom IS NULL) OR (roll_length_uom = ANY (ARRAY['m','yd','ft','in'])))
```

**Trigger de normalización ya existente:**
- `trg_catalogitems_sync_roll_dimensions` (BEFORE INSERT OR UPDATE)
- Función: `catalogitems_sync_roll_dimensions()`
- Convierte automáticamente value + uom → *_m usando factores:
  - m = 1
  - yd = 0.9144
  - ft = 0.3048
  - in = 0.0254

**Migration 58 - Actualización:**
- ✅ Actualiza `trg_catalogitems_write_conversions()` para usar `roll_width_m` (normalizado) con fallback a `roll_width` (legacy)
- ✅ Actualiza el trigger para dispararse cuando cambien los nuevos campos (`roll_width_value`, `roll_width_uom`, `roll_width_m`)
- ✅ Mantiene backward compatibility: si `roll_width_m` es NULL pero `roll_width` existe, usa el legacy

### 2. Frontend (TypeScript/React)

**Archivos modificados:**
- `src/pages/catalog/CatalogItemNew.tsx`

**Schema del formulario actualizado:**
```typescript
roll_width: z.number().min(0).optional().nullable(), // Legacy
roll_width_value: z.number().min(0).optional().nullable(),
roll_width_uom: z.enum(['m', 'yd', 'ft', 'in']).optional().nullable(),
roll_length_value: z.number().min(0).optional().nullable(),
roll_length_uom: z.enum(['m', 'yd', 'ft', 'in']).optional().nullable(),
```

**UI - Sección Roll (Profile tab):**

```
Fila después de Category:
[Roll Width]              [Unit of Measure*]       [Measure Basis*]
  [value input] [UOM ▼]   [select]                [select]
  = X.XXXX m (read-only)

[Roll Length]             [Product Types...]
  [value input] [UOM ▼]
  = X.XXXX m (read-only)
```

**Inputs Roll Width:**
- Input numérico: `roll_width_value`
- Select UOM: `roll_width_uom` (opciones: m, yd, ft, in)
- Helper text: `= {roll_width_m} m` (read-only, calculado por trigger)

**Inputs Roll Length:**
- Input numérico: `roll_length_value`
- Select UOM: `roll_length_uom` (opciones: m, yd, ft, in)
- Helper text: `= {roll_length_m} m` (read-only, calculado por trigger)

**Comportamiento:**
1. Usuario ingresa `roll_width_value = 60` y selecciona `roll_width_uom = 'in'`
2. Al guardar, el backend ejecuta el trigger `catalogitems_sync_roll_dimensions()`
3. El trigger calcula: `roll_width_m = 60 * 0.0254 = 1.524` metros
4. Frontend recarga y muestra: `= 1.5240 m` debajo del input
5. Lo mismo para `roll_length`

**Resolver actualizado:**
- Normaliza `NaN` → `null` para `roll_width_value` y `roll_length_value`
- Al desmarcar "Roll Item", limpia todos los campos de roll incluyendo los nuevos

**Persistencia:**
- `defaultValues` incluyen los nuevos campos con UOM default = 'm'
- `loadItem()` carga los valores desde la BD
- `onSubmit()` guarda `roll_width_value`, `roll_width_uom`, `roll_length_value`, `roll_length_uom`
- Después de guardar, recarga `roll_width_m` y `roll_length_m` para mostrar valores normalizados

### 3. Conversiones (CatalogItemConversions)

**Actualización del trigger:**
- Antes usaba `NEW.roll_width` (legacy) directamente
- Ahora usa `COALESCE(NEW.roll_width_m, NEW.roll_width)` - prioriza normalizado, fallback a legacy
- Trigger actualizado para dispararse cuando cambien `roll_width_value`, `roll_width_uom`, `roll_width_m`

**Backward compatibility:**
- Si un item tiene `roll_width` (legacy) pero no tiene `roll_width_value/uom`, sigue funcionando
- Si un item tiene ambos, se usa `roll_width_m` (más preciso)

## Flujo de Usuario

### Crear item tipo Roll:

1. Usuario marca "Roll Item" checkbox
2. Aparecen campos: Collection, Variant, Roll Type, Roll Pricing Mode
3. En la fila de dimensiones:
   - **Roll Width**: ingresa `1.37` y selecciona `m` → verá `= 1.3700 m` después de guardar
   - O ingresa `60` y selecciona `in` → verá `= 1.5240 m` después de guardar
4. **Roll Length** (opcional): ingresa `30` y selecciona `yd` → verá `= 27.4320 m` después de guardar
5. Al guardar:
   - Backend recibe: `roll_width_value=60, roll_width_uom='in'`
   - Trigger calcula: `roll_width_m=1.524`
   - Frontend recarga y muestra el valor normalizado

### Editar item existente (legacy):

1. Item tiene `roll_width = 1.5` (legacy, en metros)
2. Frontend muestra: campos nuevos vacíos, pero el sistema usa `roll_width` como fallback
3. Usuario puede migrar ingresando `roll_width_value=1.5, roll_width_uom='m'`
4. Desde ese momento se usa `roll_width_m` (normalizado por trigger)

## Archivos

- **Migración:** `database/migrations/58_update_roll_dimensions_conversions.sql`
- **Frontend:** `src/pages/catalog/CatalogItemNew.tsx`
- **Este doc:** `IMPLEMENTACION_ROLL_DIMENSIONS.md`

## Reglas de Validación

**Frontend (Zod schema):**
- `roll_width_value`: número >= 0, opcional, nullable
- `roll_width_uom`: enum ['m', 'yd', 'ft', 'in'], opcional, nullable
- `roll_length_value`: número >= 0, opcional, nullable
- `roll_length_uom`: enum ['m', 'yd', 'ft', 'in'], opcional, nullable

**Backend (Trigger):**
- Solo calcula `*_m` si ambos `value` y `uom` están presentes
- Si value o uom es NULL → `*_m` queda NULL

## Testing

### Test 1: Crear roll con width en pulgadas
```sql
INSERT INTO "CatalogItems" (
  organization_id, sku, name, unit_of_measure, measure_basis,
  is_roll, roll_type, collection_name, variant_name,
  roll_width_value, roll_width_uom
) VALUES (
  'org-id', 'TEST-001', 'Test Fabric', 'm', 'linear',
  true, 'fabric', 'Test Collection', 'White',
  60, 'in'
);

-- Verificar:
SELECT roll_width_value, roll_width_uom, roll_width_m 
FROM "CatalogItems" 
WHERE sku = 'TEST-001';

-- Esperado: roll_width_m = 1.524
```

### Test 2: Actualizar roll existente con length en yardas
```sql
UPDATE "CatalogItems"
SET roll_length_value = 30, roll_length_uom = 'yd'
WHERE sku = 'TEST-001';

-- Verificar:
SELECT roll_length_value, roll_length_uom, roll_length_m 
FROM "CatalogItems" 
WHERE sku = 'TEST-001';

-- Esperado: roll_length_m = 27.432
```

### Test 3: Conversiones usan width normalizado
```sql
UPDATE "CatalogItems"
SET cost_exw = 100
WHERE sku = 'TEST-001';

-- Verificar conversions:
SELECT cost_exw_per_m, cost_exw_per_m2, roll_width_input
FROM "CatalogItemConversions"
WHERE catalog_item_id = (SELECT id FROM "CatalogItems" WHERE sku = 'TEST-001');

-- Esperado: roll_width_input = 1.524 (usa roll_width_m)
--           cost_exw_per_m2 calculado con 1.524 m de ancho
```

## Notas Técnicas

1. **Campo legacy `roll_width`**: Se mantiene por compatibilidad pero se recomienda migrar a `roll_width_value + roll_width_uom`
2. **Normalización en trigger BEFORE**: Los valores `*_m` se calculan ANTES de guardar el registro, por lo que están disponibles inmediatamente
3. **Trigger de conversions**: Se ejecuta DESPUÉS (AFTER trigger), así que ya tiene acceso a `roll_width_m` calculado
4. **UI reactiva**: Después de guardar, el frontend recarga `roll_width_m` y `roll_length_m` para mostrar los valores normalizados
5. **UOM defaults**: Si el usuario no selecciona UOM, se usa 'm' por defecto

## Próximos Pasos (Opcional)

- [ ] Migrar items existentes: poblar `roll_width_value/uom` desde `roll_width` legacy
- [ ] Deprecar `roll_width` en nueva versión (mantener por ahora)
- [ ] Añadir conversión automática en UI: si usuario ingresa en `roll_width` legacy, sugerir migrar a `roll_width_value + uom`
- [ ] Dashboard/Reports: usar `roll_width_m` y `roll_length_m` para cálculos de inventario y estadísticas
