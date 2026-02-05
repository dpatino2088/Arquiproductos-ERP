# Corrección: Rates UI - Precio Base vs Conversiones

**Fecha:** 2026-02-02  
**Tipo:** Corrección conceptual crítica  
**Estado:** Error identificado por usuario

---

## Problema Identificado

La implementación anterior del tab "Rates" tenía un error conceptual fundamental:

### ❌ Implementación INCORRECTA (anterior):
- Intentaba "normalizar" todos los precios a unidades del sistema (m, m², ea)
- Modificaba `cost_exw` para guardarlo siempre en unidades normalizadas
- El "User Input" era opcional/secundario

### ✅ Implementación CORRECTA (requerida):
- **`cost_exw`** debe guardarse EN LA UNIDAD ORIGINAL (`unit_of_measure`)
- El tab "Rates" debe MOSTRAR el precio base y sus CONVERSIONES (calculadas automáticamente)
- Las conversiones son SOLO LECTURA (no editables)

---

## Cómo Funciona el Sistema (Backend)

El backend **ya está implementado correctamente** con el siguiente flujo:

### 1. Tablas y Columnas

**`CatalogItems`**:
- `cost_exw` (numeric): Precio/costo **en la unidad original**
- `unit_of_measure` (text): Unidad en la que se ingresó el precio (ej: 'yd', 'm', 'ft', 'ea')
- `roll_width` (numeric): Ancho del rollo en metros (para conversiones a m²)
- `roll_pricing_mode` (text): Cómo se cotiza (per_linear_meter | per_square_meter | per_unit)

**`CatalogItemConversions`** (tabla calculada automáticamente):
- `catalog_item_id` (uuid): FK a CatalogItems
- `cost_exw_input` (numeric): Copia del precio original
- `unit_of_measure_input` (text): Copia de la unidad original
- `roll_width_input` (numeric): Copia del ancho
- `cost_exw_per_m` (numeric): **Conversión calculada a $/m**
- `cost_exw_per_m2` (numeric): **Conversión calculada a $/m²**
- `computed_at` (timestamp): Cuándo se calculó

### 2. Funciones Backend

**`cost_to_per_m(p_cost, p_uom)`**:
```sql
-- Convierte de cualquier unidad lineal a $/m
when lower(p_uom) in ('yd','yard','yards') then (p_cost / 0.9144)
when lower(p_uom) in ('m','meter','meters','mt') then p_cost
```

**`compute_roll_conversions(p_cost_exw, p_uom, p_roll_width)`**:
```sql
-- 1. Convierte a $/m usando cost_to_per_m
-- 2. Calcula $/m² dividiendo: cost_per_m / roll_width
-- Retorna: (cost_exw_per_m, cost_exw_per_m2)
```

**`trg_catalogitems_write_conversions()`** (trigger):
```sql
-- Se ejecuta AFTER INSERT OR UPDATE OF cost_exw, unit_of_measure, roll_width, is_roll
-- EN CatalogItems
-- 1. Lee: cost_exw, unit_of_measure, roll_width
-- 2. Llama a: compute_roll_conversions()
-- 3. Escribe en: CatalogItemConversions
```

### 3. Flujo Completo

```
Usuario ingresa:
  cost_exw = 8.50
  unit_of_measure = 'yd' (yardas)
  roll_width = 1.5 (metros)

↓ Guardar en BD

Trigger automático calcula:
  cost_exw_per_m = 8.50 / 0.9144 = 9.2976 $/m
  cost_exw_per_m2 = 9.2976 / 1.5 = 6.1984 $/m²

↓ Guarda en CatalogItemConversions

Usuario ve en UI:
  [Precio Base]           [Conversiones]
  $8.50/yd (editable)  →  $9.30/m (calc)
                          $6.20/m² (calc)
```

---

## Nueva Especificación de UI

### Tab "Rates" - Estructura

```
┌─────────────────────────────────────────────────────────────┐
│ RATES                                                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ ┌─────────────────────────┐  ┌──────────────────────────┐ │
│ │ BASE PRICE (Editable)   │  │ CONVERSIONS (Read-only)  │ │
│ ├─────────────────────────┤  ├──────────────────────────┤ │
│ │                         │  │                          │ │
│ │ Cost EXW:               │  │ Per Linear Meter:        │ │
│ │ $ [8.50] / [yd ▼]       │  │ $9.30/m                  │ │
│ │                         │  │                          │ │
│ │ [Save Button]           │  │ Per Square Meter:        │ │
│ │                         │  │ $6.20/m²                 │ │
│ │ Saved: $8.50/yd         │  │                          │ │
│ │                         │  │ (Calculated using        │ │
│ │                         │  │  roll width: 1.5m)       │ │
│ └─────────────────────────┘  └──────────────────────────┘ │
│                                                             │
│ ℹ️ Note: Base price is stored in unit_of_measure           │
│    Conversions are calculated automatically when saved     │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐│
│ │ MSRP (from CatalogItemsMSRP)                            ││
│ │ ... (sin cambios) ...                                   ││
│ └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### Campos

#### Cuadrante IZQUIERDO: Base Price (Editable)

1. **Cost EXW Input** (number):
   - Placeholder: "0.00"
   - Bind a: `watch('cost_exw')`
   - onChange: `setValue('cost_exw', value)`

2. **Unit of Measure Select** (dropdown):
   - Opciones: 'yd', 'm', 'ft', 'ea', 'set', 'pack'
   - Bind a: `watch('unit_of_measure')`
   - onChange: `setValue('unit_of_measure', value)`
   - **Solo visible cuando `is_roll = true`**

3. **Current Value Display**:
   - Mostrar: `${watch('cost_exw')}/${watch('unit_of_measure')}`
   - Estilo: secundario, informativo

#### Cuadrante DERECHO: Conversions (Read-only)

1. **Per Linear Meter** (display only):
   - Valor: `conversions.cost_exw_per_m` (desde CatalogItemConversions)
   - Formato: `$X.XX/m`
   - Mensaje si null: "Save to calculate"

2. **Per Square Meter** (display only):
   - Valor: `conversions.cost_exw_per_m2`
   - Formato: `$X.XX/m²`
   - Mensaje si null: "Save to calculate (requires roll_width > 0)"

3. **Info Text**:
   - "Calculated using roll width: {roll_width}m"
   - Solo visible si `is_roll = true` y `roll_width > 0`

---

## Lógica de Carga de Conversions

### useEffect para cargar CatalogItemConversions

```typescript
useEffect(() => {
  if (!itemId || !activeOrganizationId) {
    setConversions(null);
    return;
  }
  
  const loadConversions = async () => {
    setConversionsLoading(true);
    try {
      const { data, error } = await supabase
        .from('CatalogItemConversions')
        .select('cost_exw_per_m, cost_exw_per_m2, computed_at')
        .eq('catalog_item_id', itemId)
        .single();
      
      if (error) {
        if (error.code === 'PGRST116') {
          // No conversions yet (item not saved or not a roll)
          setConversions(null);
        } else {
          console.error('Error loading conversions:', error);
        }
      } else {
        setConversions(data);
      }
    } catch (err) {
      console.error('Error loading conversions:', err);
    } finally {
      setConversionsLoading(false);
    }
  };
  
  loadConversions();
}, [itemId, activeOrganizationId]);
```

---

## Cambios en Profile Tab

### Roll Width
- **Debe estar visible SIEMPRE** que `is_roll = true`
- Actualmente: solo visible cuando `roll_pricing_mode = 'per_square_meter'`
- **Razón**: El ancho se usa para calcular conversiones a m², independientemente del pricing mode

---

## Validaciones

### En el Schema

- ✅ `cost_exw`: Debe ser > 0 si se ingresa
- ✅ `unit_of_measure`: Requerido
- ⚠️ Remover validación que requiere `roll_pricing_mode` para todos los rolls
  - **Razón**: `roll_pricing_mode` es para COTIZAR, no para el precio base

### En la UI

- Si `is_roll = true` y no hay `cost_exw`:
  - Warning: "Ingrese costo base para ver conversiones"
  
- Si `is_roll = true` y `cost_exw` existe pero no hay `roll_width`:
  - Warning: "Ingrese ancho de rollo (roll_width) para calcular $/m²"

---

## Diferencia: roll_pricing_mode vs unit_of_measure

### `unit_of_measure`
- **Para qué**: Indica la unidad EN LA QUE SE COMPRA/INGRESA el material
- **Ejemplo**: Si compras tela por yardas → `unit_of_measure = 'yd'`
- **Dónde se usa**: Para conversiones en `CatalogItemConversions`

### `roll_pricing_mode`
- **Para qué**: Indica cómo se COTIZA/VENDE el material al cliente
- **Ejemplo**: Puedes comprar en yardas pero vender por metro lineal
- **Dónde se usa**: En el motor de pricing de quotes (para determinar cómo calcular el precio de venta)

### Relación
```
Compras: $8.50/yd (unit_of_measure = 'yd')
          ↓
Conversiones automáticas:
  - $9.30/m (cost_exw_per_m)
  - $6.20/m² (cost_exw_per_m2)
          ↓
Vendes: según roll_pricing_mode
  - per_linear_meter → usas cost_exw_per_m
  - per_square_meter → usas cost_exw_per_m2
  - per_unit → usas cost_exw directo
```

---

## Implementación

### Archivos a Modificar

1. **`src/pages/catalog/CatalogItemNew.tsx`**:
   - Remover: `systemUOM`, `rateSystemValue`, `rateUserValue`, `rateUserUOM`
   - Agregar: `conversions`, `conversionsLoading`
   - Simplificar: Tab "Rates" para mostrar base + conversions
   - Modificar: Remover `useEffect` que determina `systemUOM`

2. **`src/lib/uom-conversions.ts`**:
   - MANTENER: Las funciones existen y son útiles
   - NO USAR: En el tab Rates (el backend ya hace las conversiones)

3. **`src/types/rates.ts`**:
   - SIMPLIFICAR: Tipos para reflejar nueva estructura

### Archivos a ELIMINAR/DEPRECAR

- Ninguno (las funciones de conversión siguen siendo útiles para otros casos)

---

## Testing

### Caso 1: Crear Roll Fabric con precio en Yardas

1. Profile tab:
   - `is_roll = true`
   - `roll_type = 'fabric'`
   - `roll_width = 1.5` (metros)
   - `unit_of_measure = 'yd'`
   - `roll_pricing_mode = 'per_linear_meter'`

2. Rates tab:
   - Base Price: `$8.50` / `yd`
   - Conversions (pre-save): "Save to calculate"
   
3. Guardar

4. Rates tab (post-save):
   - Base Price: `$8.50/yd`
   - Conversions:
     - Per Linear Meter: `$9.30/m`
     - Per Square Meter: `$6.20/m²`

5. Verificar en BD:
   ```sql
   SELECT ci.cost_exw, ci.unit_of_measure, ci.roll_width,
          conv.cost_exw_per_m, conv.cost_exw_per_m2
   FROM "CatalogItems" ci
   LEFT JOIN "CatalogItemConversions" conv ON conv.catalog_item_id = ci.id
   WHERE ci.sku = 'TEST_FABRIC_1';
   
   -- Esperado:
   -- cost_exw = 8.50
   -- unit_of_measure = 'yd'
   -- roll_width = 1.5
   -- cost_exw_per_m = 9.2976
   -- cost_exw_per_m2 = 6.1984
   ```

### Caso 2: Editar precio existente

1. Cargar item con `cost_exw = 8.50`, `unit_of_measure = 'yd'`
2. Conversions se cargan automáticamente
3. Cambiar precio a `$9.00/yd`
4. Guardar
5. Conversions se recalculan automáticamente (trigger)
6. UI muestra nuevas conversions después de recargar

---

## Notas Técnicas

### Comportamiento del Trigger

```sql
CREATE TRIGGER catalogitems_write_conversions
AFTER INSERT OR UPDATE OF cost_exw, unit_of_measure, roll_width, is_roll
ON "CatalogItems"
FOR EACH ROW
EXECUTE FUNCTION trg_catalogitems_write_conversions();
```

- Se ejecuta **automáticamente** al guardar
- **No necesita** acción del frontend
- La UI solo necesita **leer** las conversions después de guardar

### Unidades Soportadas

Según `cost_to_per_m`:
- ✅ 'yd', 'yard', 'yards' → metros × 0.9144
- ✅ 'm', 'meter', 'meters', 'mt' → sin conversión
- ❌ 'ft', 'in', etc. → **NO soportado actualmente**

**Acción requerida**: Si necesitas soportar más unidades, modificar `cost_to_per_m` en el backend.

---

## Resumen de Cambios

| Concepto | Antes (❌) | Ahora (✅) |
|----------|-----------|-----------|
| **cost_exw** | Normalizado a m/m²/ea | En unidad original |
| **unit_of_measure** | Ignorado | Usado para conversiones |
| **UI Rates** | System Rate (editable) + User Input (opcional) | Base Price (editable) + Conversions (read-only) |
| **Conversiones** | Calculadas en frontend | Calculadas en backend (trigger) |
| **CatalogItemConversions** | No usado | Fuente de verdad para conversiones |

---

**Próximo paso**: Implementar nueva UI según esta especificación
