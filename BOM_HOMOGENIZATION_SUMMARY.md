# 📋 RESUMEN: Homogenización del Módulo BOM

**Fecha:** 2026-01-25  
**Objetivo:** Dejar el módulo BOM 100% homogéneo y consistente con el MODELO A

---

## ✅ CAMBIOS COMPLETADOS

### 1. **Servicios y Hooks Creados**

#### `src/lib/bom/bomInstance.ts`
- ✅ `getOrCreateBomInstanceForQuoteLine()` - Get or Create BOMInstance para QuoteLine
- ✅ `getBomInstanceByQuoteLine()` - Obtener BOMInstance por QuoteLine ID
- ✅ `getBomInstanceLines()` - Obtener líneas de un BOMInstance
- ✅ `upsertBomLine()` - Insertar/actualizar una línea
- ✅ `upsertBomLines()` - Insertar/actualizar múltiples líneas
- ✅ `deleteBomInstance()` - Soft delete de BOMInstance
- ✅ `deleteBomInstanceLine()` - Soft delete de línea

#### `src/hooks/useBOMInstance.ts`
- ✅ Hook React para usar los servicios de BOMInstance
- ✅ Manejo de loading y error states
- ✅ Integración con OrganizationContext

#### `src/types/bom.ts`
- ✅ Tipos TypeScript para `BOMInstance` y `BOMInstanceLine`
- ✅ Tipos para parámetros de funciones
- ✅ Documentación de columnas que NO existen en el schema

### 2. **Referencias Actualizadas**

#### Tablas (BomInstances → BOMInstances, BomInstanceLines → BOMInstanceLines)
- ✅ `src/hooks/useManufacturing.ts` - Actualizado para usar BOMInstances/BOMInstanceLines
- ✅ `src/hooks/useBOMMonitoring.ts` - Comentarios actualizados
- ✅ `src/pages/manufacturing/OrderList.tsx` - Todas las referencias actualizadas
- ✅ `src/pages/catalog/ApprovedBOMList.tsx` - Todas las referencias actualizadas
- ✅ `src/components/manufacturing/tabs/MaterialsTab.tsx` - Referencias y mensajes actualizados
- ✅ `src/components/manufacturing/tabs/SummaryTab.tsx` - Referencias actualizadas
- ✅ `src/components/manufacturing/tabs/ProductionStepsTab.tsx` - Referencias y lógica actualizada

### 3. **Correcciones de Lógica**

#### `useManufacturing.ts`
- ✅ Corregida búsqueda de BOMInstances: ahora busca a través de SaleOrderLines → QuoteLines → BOMInstances
- ✅ Eliminadas referencias a `manufacturing_order_id` en BOMInstances (no existe)
- ✅ Actualizado SELECT para usar solo columnas que existen en BOMInstanceLines
- ✅ Agregado JOIN con CatalogItems para obtener sku, item_name, etc.

#### `ProductionStepsTab.tsx`
- ✅ Corregida búsqueda de BOMInstances para validaciones de estado
- ✅ Ahora busca a través de SaleOrderLines → QuoteLines → BOMInstances

### 4. **Schema Verificado**

#### BOMInstances (del dump `2026-01-20_v6_full.sql`)
```sql
- id (uuid, PK)
- organization_id (uuid, NOT NULL)
- quote_line_id (uuid, NOT NULL) ✅ SIEMPRE requerido
- bom_template_id (uuid, NOT NULL)
- configured_product_id (uuid, nullable) ✅ Opcional, nunca requerido
- deleted (boolean, default false)
- created_at (timestamptz)
- updated_at (timestamptz)
```

#### BOMInstanceLines (del dump)
```sql
- id (uuid, PK)
- organization_id (uuid, NOT NULL)
- bom_instance_id (uuid, NOT NULL, FK a BOMInstances)
- bom_component_id (uuid, nullable)
- resolved_part_id (uuid, nullable)
- part_role (text, NOT NULL)
- qty (numeric(12,4), NOT NULL)
- uom (text, NOT NULL)
- cut_length_mm (numeric(12,4), nullable)
- cut_width_mm (numeric(12,4), nullable)
- cut_height_mm (numeric(12,4), nullable)
- unit_cost_exw (numeric(12,4), nullable)
- total_cost_exw (numeric(12,4), nullable)
- deleted (boolean, default false)
- created_at (timestamptz)
```

**Columnas que NO existen** (se obtienen de otras tablas):
- ❌ `category_code` - Se obtiene de CatalogItems
- ❌ `resolved_sku` - Se obtiene de CatalogItems
- ❌ `unit_msrp_sale_out` - Se obtiene de CatalogItems
- ❌ `total_msrp_sale_out` - Se calcula
- ❌ `description` - Se obtiene de CatalogItems
- ❌ `calc_notes` - No existe

---

## ⚠️ PENDIENTES / VERIFICACIONES

### 1. **RPC `generate_bom_from_slots`**
- ⚠️ Verificar que la RPC en la base de datos use `BOMInstances` (no `BomInstances`)
- ⚠️ Verificar que la RPC cree BOMInstances con `quote_line_id` NOT NULL
- ⚠️ La RPC se usa en:
  - `src/pages/sales/QuoteNew.tsx` (línea 1583)
  - `src/lib/bom/createQuoteLineFromRollerConfig.ts` (línea 364)

### 2. **Vista `vw_bom_instances_safe`**
- ⚠️ Verificar que la vista use `BOMInstances` (no `BomInstances`)
- ⚠️ Se usa en:
  - `src/pages/catalog/ApprovedBOMList.tsx` (línea 217)
  - `src/hooks/useBOMMonitoring.ts` (línea 105)

### 3. **Funciones SQL en Base de Datos**
- ⚠️ Verificar que todas las funciones SQL usen `BOMInstances` y `BOMInstanceLines`
- ⚠️ Buscar en migraciones SQL:
  - `generate_bom_from_slots`
  - `generate_bom_from_slots_for_configured_product`
  - Cualquier otra función que cree o consulte BOMInstances

### 4. **UI/Flujo del Configurador**
- ⚠️ Verificar que el configurador use `getOrCreateBomInstanceForQuoteLine` antes de insertar líneas
- ⚠️ Verificar que QuoteLine editor llame a `getOrCreateBomInstanceForQuoteLine` al guardar
- ⚠️ Verificar que "Add child / add line" use `upsertBomLines` con el `bom_instance_id` correcto

### 5. **Realtime / Invalidación**
- ⚠️ Si usas react-query / tanstack, agregar invalidación:
  - `['bomInstance', quoteLineId]`
  - `['bomLines', bomInstanceId]`

### 6. **UNIQUE INDEX**
- ⚠️ Verificar que existe UNIQUE INDEX en BOMInstances para `(quote_line_id) WHERE deleted=false`
- ⚠️ Esto garantiza 1 BOM por QuoteLine (cuando no está deleted)

---

## 📝 ARCHIVOS MODIFICADOS

### Nuevos Archivos
1. `src/lib/bom/bomInstance.ts` - Servicio centralizado
2. `src/hooks/useBOMInstance.ts` - Hook React
3. `src/types/bom.ts` - Tipos TypeScript

### Archivos Actualizados
1. `src/hooks/useManufacturing.ts` - Referencias y lógica corregida
2. `src/hooks/useBOMMonitoring.ts` - Comentarios actualizados
3. `src/pages/manufacturing/OrderList.tsx` - Referencias actualizadas
4. `src/pages/catalog/ApprovedBOMList.tsx` - Referencias y comentarios actualizados
5. `src/components/manufacturing/tabs/MaterialsTab.tsx` - Referencias y mensajes actualizados
6. `src/components/manufacturing/tabs/SummaryTab.tsx` - Referencias actualizadas
7. `src/components/manufacturing/tabs/ProductionStepsTab.tsx` - Referencias y lógica corregida

---

## 🔍 VERIFICACIONES FINALES REQUERIDAS

### En Base de Datos
```sql
-- 1. Verificar que no existen tablas viejas
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('BomInstances', 'BomInstanceLines');

-- 2. Verificar que existen tablas nuevas
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('BOMInstances', 'BOMInstanceLines');

-- 3. Verificar UNIQUE INDEX en BOMInstances
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'BOMInstances' 
  AND indexdef LIKE '%quote_line_id%';

-- 4. Verificar FK constraints
SELECT conname, conrelid::regclass, confrelid::regclass
FROM pg_constraint
WHERE conrelid = 'BOMInstances'::regclass
  AND contype = 'f';
```

### En Código
```bash
# Buscar referencias restantes a tablas viejas
grep -r "BomInstances\|BomInstanceLines" src/ --exclude-dir=node_modules

# Buscar referencias a cp.quote_line_id o ql.configured_product_id
grep -r "cp\.quote_line_id\|ql\.configured_product_id" src/
```

---

## 🎯 PRÓXIMOS PASOS

1. **Verificar RPC `generate_bom_from_slots`** en base de datos
2. **Verificar vista `vw_bom_instances_safe`** en base de datos
3. **Actualizar UI del configurador** para usar `useBOMInstance` hook
4. **Agregar invalidación de queries** si usas react-query
5. **Probar flujo completo**: QuoteLine → BOMInstance → BOMInstanceLines
6. **Verificar que no hay errores de FK** al crear BOMInstances

---

## 📚 NOTAS IMPORTANTES

- ✅ **BOMInstances SIEMPRE se crea desde QuoteLine** - `quote_line_id` es NOT NULL
- ✅ **No usar ConfiguredProducts como fuente** - El flujo base es QuoteLine → BOMInstance
- ✅ **Usar alias SIEMPRE en SQL** - `bi.id`, `bil.id` para evitar ambigüedad
- ✅ **Todas las referencias actualizadas** - De `BomInstances` a `BOMInstances`
- ⚠️ **Verificar funciones SQL** - Asegurar que usan las tablas correctas

---

**Estado:** ✅ Código frontend actualizado. ⚠️ Pendiente verificar funciones SQL en base de datos.
