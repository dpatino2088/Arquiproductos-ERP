# FIX: Template Resolution - State Overwrite y Keys Inconsistentes

## Problema Original

**Síntoma:**
- Al seleccionar Bottom Bar (o cualquier SKU), los templates se perdían (Template Found: 0)
- Antes de la selección: 3 templates found ✅
- Después de seleccionar Bottom Bar: 0 templates found ❌

**Root Cause:**
1. **Inconsistencia de llaves camelCase vs snake_case**: El config tenía `hardware_color` Y `hardwareColor`, `product_type_id` Y `productTypeId`, etc.
2. **String vacío `""` tratado como selección**: `headbox_sku: ""` se trataba como SELECTED en vez de UNSET
3. **Falta de normalización**: Los filtros leían una llave pero los updates escribían otra

## Cambios Aplicados

### 1. Nuevo archivo: `src/lib/bom/normalize.ts`

Helper canónico para normalizar SKUs:

```typescript
export function normalizeSku(value: any): string | undefined {
  if (value === null || value === undefined) return undefined;
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed || undefined; // string vacío → undefined
}

export function isSelectedSku(value: any): boolean {
  return normalizeSku(value) !== undefined;
}
```

**Resultado:**
- `headbox_sku: ""` → `undefined` → **NO filtra** ✅
- `headbox_sku: "RC-2053-W"` → `"RC-2053-W"` → **filtra** ✅
- `headbox_sku: null` → `undefined` → **NO filtra** ✅

### 2. Nuevo archivo: `src/lib/config-normalizers.ts`

Getters canónicos para evitar inconsistencias:

```typescript
export function getHardwareColor(cfg: AnyConfig): string | null
export function getProductTypeId(cfg: AnyConfig): string | null
export function getOperationType(cfg: AnyConfig): 'motor' | 'manual' | null
export function getBottomBarSku(cfg: AnyConfig): string | null
export function getTubeSku(cfg: AnyConfig): string | null
export function getMotorSku(cfg: AnyConfig): string | null
export function getDriveSku(cfg: AnyConfig): string | null
// ... etc
```

**Uso:**
```typescript
// ❌ ANTES: Inconsistente
const hardwareColor = config.hardware_color || config.hardwareColor;

// ✅ AHORA: Normalizado
const hardwareColor = getHardwareColor(config);
```

### 3. Hook: `src/hooks/useBOMTemplates.ts`

**Cambios:**

#### A) Normalización de filtros en el hook
```typescript
const normalizedFilters = {
  operation_type: filters.operation_type,
  headbox_sku: normalizeSku(filters.headbox_sku),
  motor_sku: normalizeSku(filters.motor_sku),
  drive_sku: normalizeSku(filters.drive_sku),
  bottom_bar_sku: normalizeSku(filters.bottom_bar_sku),
  tube_sku: normalizeSku(filters.tube_sku),
};
```

#### B) Filtrado solo cuando hay selección real
```typescript
// ❌ ANTES: String vacío se trataba como selección
if (filters.headbox_sku) { ... }

// ✅ AHORA: Solo filtra si hay SKU real
if (normalizedFilters.headbox_sku) { ... } // undefined si es ""
```

#### C) Logs mejorados
```typescript
console.debug('[useBOMTemplates] sets', {
  baseCount: baseTemplatesResult.length,
  filteredCount: filteredTemplatesResult.length,
  baseIds: baseTemplatesResult.slice(0, 5).map(t => t.id),
  filteredIds: filteredTemplatesResult.slice(0, 5).map(t => t.id),
});
```

### 4. Componente: `src/pages/sales/ProductConfigurator.tsx`

**Cambios:**

#### A) Import de getters normalizados
```typescript
import { 
  getProductTypeId, 
  getHardwareColor, 
  getOperationType,
  logConfigDiff 
} from '../../lib/config-normalizers';
```

#### B) Uso de getters en lugar de lecturas directas
```typescript
// ❌ ANTES
const productTypeIdForTemplates = (config as any).product_type_id || (config as any).productTypeId;
const hardwareColor = (config as any).hardware_color || (config as any).hardwareColor || (config as any).operatingSystemColor || null;
const operationType = (config as any).operation_type || (config as any).drive_type || null;

// ✅ AHORA
const productTypeIdForTemplates = getProductTypeId(config as any);
const hardwareColor = getHardwareColor(config as any);
const operationType = getOperationType(config as any);
```

#### C) Logs de validación antes/después de merge
```typescript
const handleUpdate = useCallback((updates: Partial<ProductConfig>) => {
  setConfig(prev => {
    // ✅ Log ANTES de merge
    if (import.meta.env.DEV) {
      logConfigDiff(prev as any, updates as any, 'handleUpdate');
      console.debug('[ProductConfigurator] handleUpdate BEFORE merge - critical fields', {
        prev: {
          product_type_id: getProductTypeId(prev as any),
          hardware_color: getHardwareColor(prev as any),
          operation_type: getOperationType(prev as any),
        },
        updates: {
          product_type_id: getProductTypeId(updates as any),
          hardware_color: getHardwareColor(updates as any),
          operation_type: getOperationType(updates as any),
        },
      });
    }
    
    const merged = { ...prev, ...updates };
    
    // ✅ Log DESPUÉS de merge
    if (import.meta.env.DEV) {
      const lostKeys = Object.keys(prev).filter(k => (prev as any)[k] !== undefined && (merged as any)[k] === undefined);
      console.debug('[ProductConfigurator] handleUpdate AFTER merge - critical fields', {
        merged: {
          product_type_id: getProductTypeId(merged as any),
          hardware_color: getHardwareColor(merged as any),
          operation_type: getOperationType(merged as any),
          bottom_bar_sku: (merged as any).bottom_bar_sku,
          tube_sku: (merged as any).tube_sku,
          motor_sku: (merged as any).motor_sku,
          drive_sku: (merged as any).drive_sku,
        },
        lostKeys: lostKeys.length > 0 ? lostKeys : 'none',
      });
      
      if (lostKeys.length > 0) {
        console.warn('[ProductConfigurator] ⚠️ KEYS LOST DURING MERGE', {
          lostKeys,
          prevValues: Object.fromEntries(lostKeys.map(k => [k, (prev as any)[k]])),
        });
      }
    }
    
    return merged;
  });
}, []);
```

## Resultado Esperado

### Antes del fix
```
1. Usuario selecciona Hardware Color: White
   → templates = 3

2. Usuario selecciona Bottom Bar: RCA-04-W
   → hardware_color se pierde (undefined)
   → templates = 0 ❌
```

### Después del fix
```
1. Usuario selecciona Hardware Color: White
   → templates = 3

2. Usuario selecciona Bottom Bar: RCA-04-W
   → hardware_color se preserva (White)
   → templates se filtran correctamente
   → templates = 1-3 (según matches) ✅
```

## Validación

### Caso de prueba 1: String vacío no filtra
```typescript
config = {
  hardware_color: "White",
  operation_type: "manual",
  bottom_bar_sku: "RCA-04-W",
  headbox_sku: "", // ✅ UNSET
}

// Resultado:
normalizedFilters.headbox_sku = undefined
→ NO filtra por headbox
→ templates >= 1 ✅
```

### Caso de prueba 2: Merge preserva campos críticos
```typescript
prev = {
  product_type_id: "abc123",
  hardware_color: "White",
  operation_type: "manual",
}

updates = {
  bottom_bar_sku: "RCA-04-W",
}

merged = { ...prev, ...updates }

// ✅ VALIDACIÓN:
getProductTypeId(merged) === "abc123" ✅
getHardwareColor(merged) === "White" ✅
getOperationType(merged) === "manual" ✅
merged.bottom_bar_sku === "RCA-04-W" ✅
```

### Caso de prueba 3: Keys inconsistentes se resuelven
```typescript
config = {
  hardwareColor: "White", // camelCase
  hardware_color: undefined,
}

// ✅ ANTES: undefined (leía solo snake_case)
// ✅ AHORA: "White" (fallback a camelCase)
getHardwareColor(config) === "White" ✅
```

## Logs de Debug

Ahora en consola verás:

```
[ProductConfigurator] handleUpdate BEFORE merge - critical fields
  prev: { product_type_id, hardware_color, operation_type, bom_template_id }
  updates: { ... }

[ProductConfigurator] handleUpdate AFTER merge - critical fields
  merged: { ... }
  lostKeys: [] o ["key1", "key2"] si se perdió algo

[ConfigDiff] State change detected
  lost: [{ key: "hardware_color", prevVal: "White" }]
  
[ProductConfigurator] ⚠️ KEYS LOST DURING MERGE
  lostKeys: ["hardware_color"]
  prevValues: { hardware_color: "White" }
```

Si aparece **"KEYS LOST"**, ahí está el problema.

## Archivos Modificados

1. ✅ `src/lib/bom/normalize.ts` - Helper `normalizeSku()`
2. ✅ `src/lib/config-normalizers.ts` - Getters canónicos
3. ✅ `src/hooks/useBOMTemplates.ts` - Normalización de filtros
4. ✅ `src/pages/sales/ProductConfigurator.tsx` - Uso de getters + logs de validación

## Próximos Pasos

1. Recarga el configurator
2. Abre DevTools Console
3. Selecciona Bottom Bar
4. Busca el log `[ProductConfigurator] handleUpdate AFTER merge`
5. Verifica que `lostKeys` esté vacío (`"none"`)
6. Busca el log `[useBOMTemplates] sets`
7. Verifica que `baseCount` > 0 y `filteredCount` > 0

Si `lostKeys` no está vacío → identifica qué key se perdió y por qué
Si `filteredCount` = 0 → busca logs de `❌ Template XXX filtered out` y comparte el motivo
