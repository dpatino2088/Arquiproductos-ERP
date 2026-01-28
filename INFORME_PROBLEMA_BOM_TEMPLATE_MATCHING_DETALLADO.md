# INFORME TÉCNICO DETALLADO: Problema BOM Template Matching y Carga de Opciones

**Fecha:** 2026-01-23  
**Módulo Afectado:** Product Configurator (QuoteNew) - Operating System Step / Hardware Step  
**Dump Analizado:** `backups/2026-01-23_v4_full.sql`  
**Estado:** 🔴 CRÍTICO - Módulo no funcional

---

## 1. RESUMEN EJECUTIVO

El módulo de configuración de productos (`ProductConfigurator`) no está mostrando opciones de componentes (Motor, Drive/Manual, Tube) que **SÍ existen en los templates** (`BOMTemplateSlots`). El error principal es: **"No Template Found"** al finalizar la configuración, y **"No motors available for ProductType"** durante la selección.

### Síntomas Observados:
- ✅ SKUs se ven correctamente en algunos pasos (Variants, Hardware Color)
- ❌ **Motor/Drive/Manual no aparecen** aunque existen en templates
- ❌ **Tube aparece** (funciona parcialmente)
- ❌ Al finalizar: **"No matching BOM template found"**
- ❌ Console: `[useBOMTemplateOptionsSimple] No slots with items found`

---

## 2. ANÁLISIS DEL SCHEMA (DUMP: `2026-01-23_v4_full.sql`)

### 2.1 Tablas Principales Involucradas

#### `BOMTemplates` (Líneas 4807-4829)
```sql
CREATE TABLE IF NOT EXISTS "public"."BOMTemplates" (
    "id" uuid PRIMARY KEY,
    "organization_id" uuid NOT NULL,
    "product_type_id" uuid NOT NULL,
    "code" text NOT NULL,
    "name" text NOT NULL,
    "hardware_color" text,  -- ⚠️ PUEDE SER NULL (aplica a todos los colores)
    "deleted" boolean DEFAULT false,
    "archived" boolean DEFAULT false,
    "active" boolean DEFAULT true,
    "is_active" boolean DEFAULT true,
    "sort_order" integer DEFAULT 0
);
```

**Observaciones Críticas:**
- `hardware_color` puede ser `NULL` → significa "aplica a todos los colores"
- Hay DOS campos de estado: `active` e `is_active` (ambos existen)
- `deleted` y `archived` son booleanos separados

#### `BOMTemplateSlots` (Líneas 4785-4801)
```sql
CREATE TABLE IF NOT EXISTS "public"."BOMTemplateSlots" (
    "id" uuid PRIMARY KEY,
    "organization_id" uuid NOT NULL,
    "bom_template_id" uuid NOT NULL,
    "item_role" text NOT NULL,  -- Valores exactos: 'motor', 'drive', 'tube', etc.
    "catalog_item_id" uuid,  -- ⚠️ PUEDE SER NULL
    "fixed_catalog_item_id" uuid,  -- ⚠️ PUEDE SER NULL
    "slot_sku" text,  -- ⚠️ PUEDE SER NULL (pero puede tener SKU sin item_id)
    "selection_mode" text DEFAULT 'user_select',
    "required" boolean DEFAULT true,
    "qty" numeric(12,4) DEFAULT 1
);
```

**Observaciones Críticas:**
- `item_role` tiene valores EXACTOS según CHECK constraint:
  - `'motor'`, `'drive'`, `'tube'`, `'bottom_bar'`, `'headbox'`, etc.
- **Un slot puede tener:**
  - Solo `slot_sku` (sin `catalog_item_id`)
  - Solo `catalog_item_id` (sin `slot_sku`)
  - Ambos
  - Ninguno (solo rol, sin item asignado)

#### `CatalogItems` (Líneas 4947-4975)
```sql
CREATE TABLE IF NOT EXISTS "public"."CatalogItems" (
    "id" uuid PRIMARY KEY,
    "organization_id" uuid NOT NULL,
    "sku" text NOT NULL,
    "name" text NOT NULL,
    "item_role" text,  -- ⚠️ PUEDE SER NULL
    "is_active" boolean DEFAULT true NOT NULL,
    -- ⚠️ NO tiene columnas: deleted, archived
    "image_url" text,
    "color" text,
    "cost_exw" numeric(12,4)
);
```

**Observaciones Críticas:**
- **NO tiene** `deleted` ni `archived` (solo `is_active`)
- `item_role` puede ser `NULL` o uno de los valores del CHECK constraint
- CHECK constraint incluye: `'motor'`, `'drive'`, `'drive_manual'`, `'drive_motorized'`, `'tube'`, etc.

---

## 3. PROBLEMAS IDENTIFICADOS EN EL CÓDIGO ACTUAL

### 3.1 Problema #1: Filtrado Incorrecto de Templates por Color

**Ubicación:** `src/hooks/useBOMTemplateOptionsSimple.ts` (líneas 108-118)

**Código Actual:**
```typescript
let templatesQuery = supabase
  .from('BOMTemplates')
  .select('id')
  .eq('organization_id', activeOrganizationId)
  .eq('product_type_id', productTypeId)
  .eq('deleted', false)
  .eq('archived', false);

if (requiresColor && normalizedColor) {
  templatesQuery = templatesQuery.or(`hardware_color.eq.${normalizedColor},hardware_color.is.null`);
}
```

**Problema:**
- Para roles sin color (motor/tube/drive), **NO debería filtrar por `hardware_color`**
- Pero el código actual **solo excluye el filtro si `requiresColor && normalizedColor`**
- Si `hardwareColor` es `null` o `undefined`, el filtro no se aplica, pero **tampoco se cargan templates con `hardware_color IS NULL`**

**Impacto:**
- Si un template tiene `hardware_color = NULL` (aplica a todos), y el usuario aún no seleccionó color, **ese template NO se incluye** en la búsqueda de slots.

### 3.2 Problema #2: Query de CatalogItems por SKU Incorrecta

**Ubicación:** `src/hooks/useBOMTemplateOptionsSimple.ts` (líneas 251-258)

**Código Actual:**
```typescript
slotSkus.length > 0
  ? supabase
      .from('CatalogItems')
      .select('id, sku, name, image_url, color, cost_exw, category_id')
      .in('sku', slotSkus)  // ⚠️ PROBLEMA: .in() con SKUs puede fallar si hay NULLs o formatos diferentes
      .eq('organization_id', activeOrganizationId)
      .eq('is_active', true)
  : Promise.resolve({ data: [], error: null } as any),
```

**Problema:**
- `.in('sku', slotSkus)` requiere que los SKUs en `slotSkus` coincidan **exactamente** con los SKUs en `CatalogItems.sku`
- Si hay diferencias de formato (espacios, mayúsculas, normalización), **no encuentra matches**
- Si `slot_sku` tiene un valor que no existe en `CatalogItems`, **no retorna nada** (aunque debería crear opción virtual)

**Impacto:**
- SKUs que existen en `BOMTemplateSlots.slot_sku` pero no en `CatalogItems.sku` **no se muestran**.

### 3.3 Problema #3: Falta de Validación de Templates Encontrados

**Ubicación:** `src/hooks/useBOMTemplateOptionsSimple.ts` (líneas 126-138)

**Código Actual:**
```typescript
if (!templates || templates.length === 0) {
  // ... warning y return []
}
```

**Problema:**
- Si no encuentra templates, **retorna array vacío sin más diagnóstico**
- No verifica si:
  - El `product_type_id` es válido
  - Hay templates pero están `deleted=true` o `archived=true`
  - Hay templates pero con `hardware_color` diferente al seleccionado

**Impacto:**
- Dificulta debugging: no sabemos **por qué** no hay templates.

### 3.4 Problema #4: Matching Final No Considera Templates con `hardware_color IS NULL`

**Ubicación:** `src/lib/bom/matchBOMTemplate.ts` (líneas 137-144)

**Código Actual:**
```typescript
const { data: templatesRaw, error: templatesError } = await supabase
  .from('BOMTemplates')
  .select('id, name, code, product_type_id, hardware_color')
  .eq('organization_id', organization_id)
  .eq('product_type_id', product_type_id)
  .or(`hardware_color.eq.${normalizedColor},hardware_color.is.null`)
  .eq('deleted', false)
  .eq('archived', false);
```

**Problema:**
- El matching busca templates con `hardware_color = color OR NULL`
- Pero luego **prefiere exactos** (línea 172): `const exact = templatesRaw.filter((t: any) => (t as any).hardware_color === normalizedColor);`
- Si hay templates con `hardware_color = NULL` y también con `hardware_color = 'White'`, **solo usa los exactos**
- Esto puede excluir templates válidos que aplican a todos los colores

**Impacto:**
- Si un template tiene `hardware_color = NULL` y es el único que tiene los SKUs correctos, **no se selecciona**.

### 3.5 Problema #5: Normalización de SKU Inconsistente

**Ubicación:** Múltiples archivos usan `normalizeSku()`

**Problema:**
- `normalizeSku()` puede normalizar SKUs de manera diferente a como están almacenados en DB
- Si `BOMTemplateSlots.slot_sku = "MOT-123"` pero `CatalogItems.sku = "mot-123"`, **no coinciden**
- El matching por SKU falla silenciosamente

**Impacto:**
- SKUs que existen pero con formato diferente **no se encuentran**.

---

## 4. DIAGNÓSTICO DE QUERIES (SQL para Verificar)

### 4.1 Query 1: Verificar Templates Existentes para ProductType

```sql
-- Verificar cuántos templates hay para un product_type_id específico
SELECT 
  id,
  code,
  name,
  product_type_id,
  hardware_color,  -- ⚠️ Puede ser NULL
  deleted,
  archived,
  active,
  is_active
FROM "BOMTemplates"
WHERE organization_id = '<ORG_ID>'
  AND product_type_id = '<PRODUCT_TYPE_ID>'
  AND deleted = false
  AND archived = false
ORDER BY hardware_color NULLS LAST, sort_order;
```

**Qué Verificar:**
- ¿Hay templates con `hardware_color IS NULL`?
- ¿Hay templates con `hardware_color = 'White'`?
- ¿Todos tienen `deleted = false` y `archived = false`?

### 4.2 Query 2: Verificar Slots con Rol 'motor'/'drive'/'tube'

```sql
-- Verificar slots de motor/drive/tube en templates del product_type
SELECT 
  bts.id,
  bts.bom_template_id,
  bts.item_role,
  bts.catalog_item_id,
  bts.fixed_catalog_item_id,
  bts.slot_sku,  -- ⚠️ Puede tener SKU sin catalog_item_id
  bts.selection_mode,
  bt.code as template_code,
  bt.name as template_name,
  bt.hardware_color
FROM "BOMTemplateSlots" bts
JOIN "BOMTemplates" bt ON bt.id = bts.bom_template_id
WHERE bts.organization_id = '<ORG_ID>'
  AND bt.product_type_id = '<PRODUCT_TYPE_ID>'
  AND bt.deleted = false
  AND bt.archived = false
  AND bts.item_role IN ('motor', 'drive', 'tube')
ORDER BY bts.item_role, bt.hardware_color NULLS LAST;
```

**Qué Verificar:**
- ¿Hay slots con `item_role = 'motor'`?
- ¿Esos slots tienen `catalog_item_id`, `fixed_catalog_item_id`, o `slot_sku`?
- ¿Los templates asociados tienen `hardware_color` correcto o NULL?

### 4.3 Query 3: Verificar CatalogItems por SKU de Slots

```sql
-- Verificar si los slot_sku existen en CatalogItems
WITH slot_skus AS (
  SELECT DISTINCT 
    bts.slot_sku,
    bts.item_role
  FROM "BOMTemplateSlots" bts
  JOIN "BOMTemplates" bt ON bt.id = bts.bom_template_id
  WHERE bts.organization_id = '<ORG_ID>'
    AND bt.product_type_id = '<PRODUCT_TYPE_ID>'
    AND bt.deleted = false
    AND bt.archived = false
    AND bts.item_role = 'motor'  -- Cambiar a 'drive' o 'tube' según necesidad
    AND bts.slot_sku IS NOT NULL
    AND TRIM(bts.slot_sku) != ''
)
SELECT 
  ss.slot_sku as slot_sku_from_template,
  ci.sku as catalog_item_sku,
  ci.id as catalog_item_id,
  ci.name,
  ci.is_active,
  ci.item_role,
  CASE 
    WHEN ci.id IS NULL THEN 'SKU NO ENCONTRADO EN CatalogItems'
    WHEN ci.is_active = false THEN 'SKU ENCONTRADO PERO INACTIVO'
    ELSE 'SKU VÁLIDO'
  END as status
FROM slot_skus ss
LEFT JOIN "CatalogItems" ci ON 
  TRIM(LOWER(ci.sku)) = TRIM(LOWER(ss.slot_sku))
  AND ci.organization_id = '<ORG_ID>'
  AND ci.is_active = true
ORDER BY ss.slot_sku;
```

**Qué Verificar:**
- ¿Los `slot_sku` de los templates **existen** en `CatalogItems`?
- ¿Están `is_active = true`?
- ¿Hay diferencias de formato (mayúsculas, espacios)?

### 4.4 Query 4: Verificar CatalogItems por IDs de Slots

```sql
-- Verificar si los catalog_item_id de slots existen y están activos
SELECT 
  bts.id as slot_id,
  bts.item_role,
  bts.catalog_item_id,
  bts.fixed_catalog_item_id,
  bts.slot_sku,
  ci.id as catalog_item_found,
  ci.sku,
  ci.name,
  ci.is_active,
  CASE 
    WHEN ci.id IS NULL THEN 'CatalogItem NO ENCONTRADO'
    WHEN ci.is_active = false THEN 'CatalogItem INACTIVO'
    ELSE 'CatalogItem VÁLIDO'
  END as status
FROM "BOMTemplateSlots" bts
JOIN "BOMTemplates" bt ON bt.id = bts.bom_template_id
LEFT JOIN "CatalogItems" ci ON 
  (ci.id = bts.catalog_item_id OR ci.id = bts.fixed_catalog_item_id)
  AND ci.organization_id = '<ORG_ID>'
WHERE bts.organization_id = '<ORG_ID>'
  AND bt.product_type_id = '<PRODUCT_TYPE_ID>'
  AND bt.deleted = false
  AND bt.archived = false
  AND bts.item_role = 'motor'  -- Cambiar según necesidad
  AND (bts.catalog_item_id IS NOT NULL OR bts.fixed_catalog_item_id IS NOT NULL)
ORDER BY bts.item_role;
```

**Qué Verificar:**
- ¿Los `catalog_item_id` / `fixed_catalog_item_id` de los slots **existen** en `CatalogItems`?
- ¿Están `is_active = true`?

---

## 5. POSIBLES CAUSAS RAÍZ

### Causa #1: Templates con `hardware_color = NULL` No Se Incluyen Correctamente
**Probabilidad:** 🔴 ALTA  
**Evidencia:**
- El código filtra por color solo si `requiresColor && normalizedColor`
- Para motor/tube/drive, `requiresColor = false`, entonces **NO filtra por color**
- Pero si el usuario seleccionó color "White", y hay templates con `hardware_color = NULL`, **ambos deberían incluirse**
- **Problema:** La query actual para roles sin color **NO incluye templates con NULL**

**Solución Propuesta:**
```typescript
// Para roles sin color (motor/tube/drive): traer TODOS los templates del product_type
// Para roles con color: traer (hardware_color = color) OR (hardware_color IS NULL)
let templatesQuery = supabase
  .from('BOMTemplates')
  .select('id')
  .eq('organization_id', activeOrganizationId)
  .eq('product_type_id', productTypeId)
  .eq('deleted', false)
  .eq('archived', false);

if (requiresColor && normalizedColor) {
  // Roles con color: incluir exactos Y NULLs
  templatesQuery = templatesQuery.or(`hardware_color.eq.${normalizedColor},hardware_color.is.null`);
}
// Si NO requiere color: NO filtrar por hardware_color (traer todos)
```

### Causa #2: Slots Tienen `slot_sku` Pero No `catalog_item_id`
**Probabilidad:** 🔴 ALTA  
**Evidencia:**
- Console muestra: `[useBOMTemplateOptionsSimple] No slots with items found`
- Esto significa que los slots **existen** pero no tienen `catalog_item_id`, `fixed_catalog_item_id`, ni `slot_sku` (o el filtro los excluye)

**Solución Propuesta:**
- Ya implementada parcialmente: el código ahora busca por `slot_sku` también
- **Pero falta:** Si `slot_sku` existe pero NO está en `CatalogItems`, crear opción virtual
- **Verificar:** Que el filtro `slotsWithItems` incluya slots con solo `slot_sku`

### Causa #3: Normalización de SKU Inconsistente
**Probabilidad:** 🟡 MEDIA  
**Evidencia:**
- `normalizeSku()` puede cambiar formato
- Si `slot_sku = "MOT-123"` y `CatalogItems.sku = "mot-123"`, no coinciden

**Solución Propuesta:**
```typescript
// En la query por SKU, usar comparación case-insensitive
slotSkus.length > 0
  ? supabase
      .from('CatalogItems')
      .select('id, sku, name, image_url, color, cost_exw, category_id')
      .eq('organization_id', activeOrganizationId)
      .eq('is_active', true)
      // Usar .ilike() o función SQL para comparación case-insensitive
      // O normalizar ambos lados antes de comparar
```

### Causa #4: Matching Final Excluye Templates con `hardware_color = NULL`
**Probabilidad:** 🟡 MEDIA  
**Evidencia:**
- El matching prefiere templates exactos (línea 172 de `matchBOMTemplate.ts`)
- Si hay templates con `hardware_color = NULL` que tienen los SKUs correctos, **no se seleccionan**

**Solución Propuesta:**
```typescript
// En matchBOMTemplate.ts, NO preferir solo exactos
// Evaluar TODOS los templates (exactos + NULLs) y elegir el mejor match por score
const templates = templatesRaw; // No filtrar, evaluar todos
```

---

## 6. SOLUCIONES PROPUESTAS

### Solución #1: Corregir Query de Templates para Roles Sin Color

**Archivo:** `src/hooks/useBOMTemplateOptionsSimple.ts`

**Cambio:**
```typescript
// ANTES (INCORRECTO):
if (requiresColor && normalizedColor) {
  templatesQuery = templatesQuery.or(`hardware_color.eq.${normalizedColor},hardware_color.is.null`);
}

// DESPUÉS (CORRECTO):
// Para roles sin color: NO filtrar por hardware_color (traer TODOS)
// Para roles con color: incluir exactos Y NULLs
if (requiresColor && normalizedColor) {
  templatesQuery = templatesQuery.or(`hardware_color.eq.${normalizedColor},hardware_color.is.null`);
}
// Si NO requiere color: la query ya NO filtra por hardware_color (correcto)
```

**Estado:** ✅ Ya implementado parcialmente, pero verificar que funcione.

### Solución #2: Mejorar Búsqueda de CatalogItems por SKU

**Archivo:** `src/hooks/useBOMTemplateOptionsSimple.ts`

**Cambio:**
```typescript
// ANTES:
.in('sku', slotSkus)

// DESPUÉS: Usar comparación case-insensitive o normalizar
// Opción A: Normalizar SKUs antes de la query
const normalizedSlotSkus = slotSkus.map(sku => normalizeSku(sku) || sku.trim().toLowerCase());
// Luego buscar en CatalogItems con .in() pero normalizando también

// Opción B: Usar función SQL para comparación case-insensitive
// (Requiere función en DB o usar .ilike() con múltiples condiciones)
```

**Estado:** ⚠️ PENDIENTE - Requiere implementación.

### Solución #3: Crear Opciones Virtuales para `slot_sku` Sin CatalogItem

**Archivo:** `src/hooks/useBOMTemplateOptionsSimple.ts`

**Cambio:**
```typescript
// Ya implementado parcialmente (líneas 300-315)
// Pero verificar que:
// 1. slotSkus se extrae correctamente de slots
// 2. Se crean opciones virtuales para SKUs no encontrados
// 3. El ID virtual es único y manejable
```

**Estado:** ✅ Implementado, pero verificar funcionamiento.

### Solución #4: Corregir Matching Final para Incluir Templates con `hardware_color = NULL`

**Archivo:** `src/lib/bom/matchBOMTemplate.ts`

**Cambio:**
```typescript
// ANTES:
const exact = templatesRaw.filter((t: any) => (t as any).hardware_color === normalizedColor);
const templates = exact.length > 0 ? exact : templatesRaw;

// DESPUÉS: Evaluar TODOS los templates, no solo exactos
const templates = templatesRaw; // Evaluar todos (exactos + NULLs)
// El score de matching determinará cuál es mejor
```

**Estado:** ⚠️ PENDIENTE - Requiere cambio.

### Solución #5: Agregar Logging Detallado para Debugging

**Archivos:** Todos los hooks y funciones de matching

**Cambio:**
```typescript
// Agregar logs en cada paso crítico:
// 1. Templates encontrados (con hardware_color)
// 2. Slots encontrados (con item_role, catalog_item_id, slot_sku)
// 3. CatalogItems encontrados (por ID y por SKU)
// 4. Opciones finales generadas
```

**Estado:** ✅ Parcialmente implementado, pero puede mejorarse.

---

## 7. TABLAS INVOLUCRADAS Y RELACIONES

### 7.1 Diagrama de Relaciones

```
BOMTemplates (1) ──< (N) BOMTemplateSlots
    │                        │
    │                        ├──> catalog_item_id ──> CatalogItems.id
    │                        ├──> fixed_catalog_item_id ──> CatalogItems.id
    │                        └──> slot_sku ──> CatalogItems.sku (match por texto)
    │
    └──> product_type_id ──> ProductTypes.id

CatalogItems (N) ──< (N) CatalogItemProductTypes ──> (N) ProductTypes
```

### 7.2 Campos Críticos por Tabla

| Tabla | Campo | Tipo | Nullable | Descripción |
|-------|-------|------|----------|-------------|
| `BOMTemplates` | `hardware_color` | `text` | ✅ SÍ | NULL = aplica a todos los colores |
| `BOMTemplates` | `deleted` | `boolean` | ❌ NO | Soft delete |
| `BOMTemplates` | `archived` | `boolean` | ❌ NO | Archivado |
| `BOMTemplates` | `active` | `boolean` | ❌ NO | Estado activo (legacy) |
| `BOMTemplates` | `is_active` | `boolean` | ✅ SÍ | Estado activo (nuevo) |
| `BOMTemplateSlots` | `item_role` | `text` | ❌ NO | Valores exactos: 'motor', 'drive', 'tube', etc. |
| `BOMTemplateSlots` | `catalog_item_id` | `uuid` | ✅ SÍ | FK a CatalogItems (puede ser NULL) |
| `BOMTemplateSlots` | `fixed_catalog_item_id` | `uuid` | ✅ SÍ | FK a CatalogItems (puede ser NULL) |
| `BOMTemplateSlots` | `slot_sku` | `text` | ✅ SÍ | SKU directo (puede ser NULL) |
| `CatalogItems` | `sku` | `text` | ❌ NO | SKU único (debe coincidir con slot_sku) |
| `CatalogItems` | `is_active` | `boolean` | ❌ NO | Solo activos se muestran |
| `CatalogItems` | `item_role` | `text` | ✅ SÍ | Rol del item (puede ser NULL) |
| `CatalogItems` | `deleted` | - | ❌ NO EXISTE | No tiene columna deleted |
| `CatalogItems` | `archived` | - | ❌ NO EXISTE | No tiene columna archived |

---

## 8. QUERIES DE DIAGNÓSTICO (Para Ejecutar en DB)

### Query 8.1: Verificar Estado Actual de Templates y Slots

```sql
-- Reemplazar <ORG_ID> y <PRODUCT_TYPE_ID> con valores reales
WITH template_summary AS (
  SELECT 
    bt.id,
    bt.code,
    bt.name,
    bt.hardware_color,
    bt.deleted,
    bt.archived,
    COUNT(DISTINCT bts.id) as total_slots,
    COUNT(DISTINCT CASE WHEN bts.item_role = 'motor' THEN bts.id END) as motor_slots,
    COUNT(DISTINCT CASE WHEN bts.item_role = 'drive' THEN bts.id END) as drive_slots,
    COUNT(DISTINCT CASE WHEN bts.item_role = 'tube' THEN bts.id END) as tube_slots
  FROM "BOMTemplates" bt
  LEFT JOIN "BOMTemplateSlots" bts ON bts.bom_template_id = bt.id
  WHERE bt.organization_id = '<ORG_ID>'
    AND bt.product_type_id = '<PRODUCT_TYPE_ID>'
    AND bt.deleted = false
    AND bt.archived = false
  GROUP BY bt.id, bt.code, bt.name, bt.hardware_color, bt.deleted, bt.archived
)
SELECT * FROM template_summary
ORDER BY hardware_color NULLS LAST;
```

### Query 8.2: Verificar Slots de Motor con Detalle

```sql
SELECT 
  bts.id as slot_id,
  bts.item_role,
  bts.catalog_item_id,
  bts.fixed_catalog_item_id,
  bts.slot_sku,
  bts.selection_mode,
  bt.code as template_code,
  bt.name as template_name,
  bt.hardware_color,
  ci_by_id.id as catalog_item_by_id,
  ci_by_id.sku as catalog_item_sku_by_id,
  ci_by_id.is_active as catalog_item_active_by_id,
  ci_by_sku.id as catalog_item_by_sku,
  ci_by_sku.sku as catalog_item_sku_by_sku,
  ci_by_sku.is_active as catalog_item_active_by_sku,
  CASE 
    WHEN bts.catalog_item_id IS NOT NULL AND ci_by_id.id IS NULL THEN 'ERROR: catalog_item_id no existe'
    WHEN bts.fixed_catalog_item_id IS NOT NULL AND ci_by_id.id IS NULL THEN 'ERROR: fixed_catalog_item_id no existe'
    WHEN bts.slot_sku IS NOT NULL AND ci_by_sku.id IS NULL THEN 'WARNING: slot_sku no existe en CatalogItems (debe crear opción virtual)'
    WHEN bts.catalog_item_id IS NOT NULL AND ci_by_id.is_active = false THEN 'WARNING: catalog_item_id existe pero está inactivo'
    WHEN bts.slot_sku IS NOT NULL AND ci_by_sku.is_active = false THEN 'WARNING: slot_sku existe pero está inactivo'
    WHEN bts.catalog_item_id IS NULL AND bts.fixed_catalog_item_id IS NULL AND bts.slot_sku IS NULL THEN 'ERROR: Slot sin ningún identificador'
    ELSE 'OK'
  END as status
FROM "BOMTemplateSlots" bts
JOIN "BOMTemplates" bt ON bt.id = bts.bom_template_id
LEFT JOIN "CatalogItems" ci_by_id ON 
  (ci_by_id.id = bts.catalog_item_id OR ci_by_id.id = bts.fixed_catalog_item_id)
  AND ci_by_id.organization_id = '<ORG_ID>'
LEFT JOIN "CatalogItems" ci_by_sku ON 
  TRIM(LOWER(ci_by_sku.sku)) = TRIM(LOWER(bts.slot_sku))
  AND ci_by_sku.organization_id = '<ORG_ID>'
WHERE bts.organization_id = '<ORG_ID>'
  AND bt.product_type_id = '<PRODUCT_TYPE_ID>'
  AND bt.deleted = false
  AND bt.archived = false
  AND bts.item_role = 'motor'
ORDER BY bt.hardware_color NULLS LAST, bt.code;
```

### Query 8.3: Verificar Consistencia de SKUs

```sql
-- Encontrar discrepancias entre slot_sku y CatalogItems.sku
SELECT 
  bts.slot_sku as slot_sku_from_template,
  ci.sku as catalog_item_sku,
  CASE 
    WHEN TRIM(LOWER(bts.slot_sku)) = TRIM(LOWER(ci.sku)) THEN 'MATCH EXACTO'
    WHEN TRIM(LOWER(bts.slot_sku)) LIKE TRIM(LOWER(ci.sku)) || '%' THEN 'MATCH PARCIAL (slot_sku más largo)'
    WHEN TRIM(LOWER(ci.sku)) LIKE TRIM(LOWER(bts.slot_sku)) || '%' THEN 'MATCH PARCIAL (catalog_item_sku más largo)'
    ELSE 'NO MATCH'
  END as match_type,
  bts.item_role,
  bt.code as template_code
FROM "BOMTemplateSlots" bts
JOIN "BOMTemplates" bt ON bt.id = bts.bom_template_id
LEFT JOIN "CatalogItems" ci ON 
  TRIM(LOWER(ci.sku)) = TRIM(LOWER(bts.slot_sku))
  AND ci.organization_id = '<ORG_ID>'
WHERE bts.organization_id = '<ORG_ID>'
  AND bt.product_type_id = '<PRODUCT_TYPE_ID>'
  AND bt.deleted = false
  AND bt.archived = false
  AND bts.item_role IN ('motor', 'drive', 'tube')
  AND bts.slot_sku IS NOT NULL
  AND TRIM(bts.slot_sku) != ''
ORDER BY match_type, bts.item_role;
```

---

## 9. PLAN DE ACCIÓN RECOMENDADO

### Fase 1: Diagnóstico (Inmediato)
1. ✅ Ejecutar Query 8.1 para verificar templates existentes
2. ✅ Ejecutar Query 8.2 para verificar slots de motor/drive/tube
3. ✅ Ejecutar Query 8.3 para verificar consistencia de SKUs
4. ✅ Revisar logs de consola del navegador para ver qué queries se están ejecutando

### Fase 2: Correcciones Críticas (Prioridad Alta)
1. **Corregir query de templates para roles sin color:**
   - Asegurar que para motor/tube/drive se traigan **TODOS** los templates del `product_type_id`
   - No filtrar por `hardware_color` para estos roles

2. **Mejorar búsqueda de CatalogItems por SKU:**
   - Implementar comparación case-insensitive
   - O normalizar ambos lados antes de comparar

3. **Corregir matching final:**
   - Evaluar TODOS los templates (exactos + NULLs)
   - No preferir solo exactos si hay NULLs con mejor score

### Fase 3: Mejoras (Prioridad Media)
1. Agregar logging detallado en cada paso
2. Crear opciones virtuales para `slot_sku` sin CatalogItem
3. Validar normalización de SKUs

### Fase 4: Validación (Prioridad Alta)
1. Probar con datos reales del dump
2. Verificar que Motor/Drive/Tube aparezcan correctamente
3. Verificar que el matching final encuentre templates

---

## 10. ARCHIVOS A MODIFICAR

| Archivo | Cambios Necesarios | Prioridad |
|---------|-------------------|-----------|
| `src/hooks/useBOMTemplateOptionsSimple.ts` | Corregir query de templates para roles sin color | 🔴 ALTA |
| `src/hooks/useBOMTemplateOptionsSimple.ts` | Mejorar búsqueda de CatalogItems por SKU (case-insensitive) | 🔴 ALTA |
| `src/lib/bom/matchBOMTemplate.ts` | Evaluar todos los templates (no solo exactos) | 🟡 MEDIA |
| `src/pages/sales/curtain-config/OperatingSystemStep.tsx` | Verificar que no requiera hardwareColor para motor/tube/drive | 🟡 MEDIA |
| `src/pages/sales/curtain-config/HardwareStep.tsx` | Verificar manejo de opciones virtuales | 🟢 BAJA |

---

## 11. CONCLUSIÓN

El problema principal es que **el código actual no está consultando correctamente los templates y slots según el schema real del dump**. Específicamente:

1. **Para roles sin color (motor/tube/drive):** Debe traer TODOS los templates del `product_type_id`, sin filtrar por `hardware_color`.
2. **Para búsqueda de CatalogItems por SKU:** Debe usar comparación case-insensitive o normalización consistente.
3. **Para matching final:** Debe evaluar templates con `hardware_color = NULL` también, no solo exactos.

**Recomendación:** Ejecutar las queries de diagnóstico primero para confirmar el estado de los datos, luego aplicar las correcciones en el orden de prioridad indicado.

---

**Fin del Informe**
