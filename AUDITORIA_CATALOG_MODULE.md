# Auditoría Módulo Catalog - Adaptio ERP

**Fecha**: 2026-01-13  
**Objetivo**: Identificar qué está roto y planificar fixes sin romper nada

---

## PASO 1: AUDITORÍA RÁPIDA DEL CÓDIGO

### Archivos encontrados:

**Páginas:**
- `src/pages/catalog/Items.tsx` - Lista principal de SKUs
- `src/pages/catalog/CatalogItemNew.tsx` - Crear/editar item
- `src/pages/catalog/Categories.tsx` - Árbol de categorías
- `src/pages/catalog/Collections.tsx` - Vista de colecciones
- `src/pages/catalog/Manufacturers.tsx` - Gestión de fabricantes
- `src/pages/catalog/ImportCatalog.tsx` - Importación masiva
- Otros: BOM.tsx, BOMTab.tsx, BOMTemplates.tsx, BOMReadiness.tsx, ApprovedBOMList.tsx, Variants.tsx, Catalog.tsx

**Hooks:**
- `src/hooks/useCatalog.ts` - Contiene todos los hooks de Catalog

### Estado actual de consultas DB:

#### 1. CATEGORIES
**Hook**: `useItemCategoriesCRUD()` (línea 1316)
**Tabla consultada**: `public."CatalogCategories"` ✅ CORRECTO
**Columnas esperadas**: id, organization_id, name, code, parent_id, sort_order, is_group, deleted, archived
**Estado**: ✅ ACTUALIZADO - consulta tabla correcta con retry para columnas opcionales

#### 2. ITEMS
**Hook**: `useCatalogItems()` (línea 6)
**Tabla consultada**: `public."CatalogItems"` ✅ CORRECTO
**Filtros**: organization_id, is_active=true (antes usaba deleted=false)
**Estado**: ✅ ACTUALIZADO - elimina filtro `.eq('deleted', false)`, usa `.eq('is_active', true)`
**Problema resuelto**: Columna `deleted` no existe en `CatalogItems`

#### 3. COLLECTIONS
**Hook**: `useCatalogCollections()` (línea 564)
**Tabla consultada**: NINGUNA (derivado desde CatalogItems) ✅ CORRECTO
**Lógica**: 
- Consulta `CatalogItems.collection_name` (no null)
- Agrupa por `collection_name` único
- Genera colecciones virtuales (id generado, no real)
**Estado**: ✅ FUNCIONAL - no consulta tablas inexistentes, deriva desde CatalogItems
**Problema identificado**: El error "Error loading collections" viene de otro lugar (probablemente console logs con objetos [circular])

#### 4. MANUFACTURERS
**Hook**: `useManufacturersCRUD()` (línea 1603)
**Tabla consultada**: `public."Manufacturers"` ✅ CORRECTO
**Columnas esperadas**: id, organization_id, name, code, website, notes, deleted, archived
**Estado**: ✅ FUNCIONAL

---

## PROBLEMAS IDENTIFICADOS

### ❌ CRÍTICO: Columna `item_type` eliminada de DB pero aún referenciada
**Archivos afectados:**
- `src/pages/catalog/ApprovedBOMList.tsx` (línea 284, 398)
- `src/pages/catalog/ImportCatalog.tsx` (múltiples líneas)

**Impacto**: BOM y Import pueden fallar al intentar SELECT item_type
**Solución**: Eliminar referencias a item_type o usar is_fabric + measure_basis

### ⚠️ ADVERTENCIA: Console logs con objetos complejos
**Archivos afectados:**
- `src/hooks/useCatalog.ts` (múltiples console.log/error con objetos)
- `src/pages/catalog/Collections.tsx` (líneas 28-41)

**Impacto**: Logs muestran "[circular]", dificulta debugging
**Solución**: Ya parcialmente corregido en useCatalog.ts, falta Collections.tsx

### ℹ️ INFO: variant_name todavía se usa correctamente
**Estado**: ✅ PRESERVADO
**Uso**: `is_fabric=true` → usa `variant_name`, `is_fabric=false` → usa `color`
**Lógica toggle**: Implementada en CatalogItemNew.tsx

---

## ESTADO DE TABLAS DB (según código)

### CatalogItems ✅
**Columnas usadas en código:**
- id, organization_id, sku, name, description
- unit_of_measure, measure_basis (unit|linear|area)
- is_fabric, roll_kind, collection_name, variant_name, roll_width, fabric_pricing_mode
- color (cuando is_fabric=false)
- category_id (FK a CatalogCategories.id)
- manufacturer, manufacturer_id (FK a Manufacturers.id)
- cost_exw, default_margin_pct, msrp
- is_active, archived
- created_at, updated_at
- metadata (jsonb)

**Columnas eliminadas del código:**
- ❌ item_type (columna eliminada del DB)
- ❌ deleted (no existe, se usa is_active)

### CatalogCategories ✅
**Columnas según user spec:**
- id, organization_id, name, code
- parent_id (nullable, self-FK)
- sort_order (int4, default 0)
- is_group (boolean, default false) - true = group, false = leaf selectable
- deleted, archived (boolean, default false)
- created_at, updated_at

**Estado hook**: Actualizado con retry para deleted/archived

### Manufacturers ✅
**Columnas según código:**
- id, organization_id, name, code, website, notes
- deleted, archived
- created_at, updated_at

**Relación con CatalogItems:**
- CatalogItems.manufacturer_id → Manufacturers.id
- CatalogItems.manufacturer (text) - usado en imports, debe sincronizar con manufacturer_id

### Collections ⚠️ NO EXISTE TABLA FÍSICA
**Estado**: Derivada desde CatalogItems.collection_name (correcto según user)
**No requiere tabla física**, solo agrupación de CatalogItems

---

## TAREAS PENDIENTES (ORDEN DE PRIORIDAD)

### ✅ COMPLETADO
1. Items: Eliminar `.eq('deleted', false)`, usar `.eq('is_active', true)`
2. Items: Mapear category_id → category name en tabla
3. Items: Cambiar header "Type" → "Category"
4. Items: Paginación default 10 → 25
5. CatalogItemNew: Eliminar item_type, usar is_fabric + variant_name/color
6. Categories: Usar CatalogCategories con parent_id
7. Categories: Añadir contadores de items por categoría
8. Categories: Añadir botón "View items" con filtro

### 🔧 EN PROGRESO
- Collections: Verificar por qué muestra error (aunque el hook parece correcto)

### ⏭️ PENDIENTE
1. ApprovedBOMList.tsx: Eliminar referencias a item_type (línea 284, 398)
2. ImportCatalog.tsx: Eliminar/actualizar referencias a item_type
3. Manufacturers: Verificar UI y funcionalidad CRUD
4. Migración: Trigger sync manufacturer (text) → manufacturer_id
5. Seed data: Categorías starter (Drives, Controls, etc.)

---

## RUTAS VERIFICADAS

- ✅ `/catalog/items` - Lista SKUs (funcional)
- ✅ `/catalog/items/new` - Crear item (funcional, sin item_type)
- ✅ `/catalog/items/edit/:id` - Editar item
- ✅ `/catalog/categories` - Árbol de categorías (funcional con CatalogCategories)
- ⚠️ `/catalog/collection` - Muestra error (investigar)
- ❓ `/catalog/manufacturer` - No verificado aún

---

## COLUMNAS CRÍTICAS NO TOCAR

- ✅ `variant_name` - PRESERVADA, usada cuando is_fabric=true
- ✅ `collection_name` - PRESERVADA, crítica para Collections derivadas
- ✅ `manufacturer` - PRESERVADA, usada en imports
- ✅ `color` - PRESERVADA, usada cuando is_fabric=false

---

## PRÓXIMOS PASOS

1. **Verificar Collections error en consola** (expandir mensaje de error)
2. **Limpiar referencias a item_type** en BOM y Import
3. **Verificar Manufacturers UI** funciona correctamente
4. **Implementar trigger manufacturer sync** (si no existe)
5. **Seed data categorías** (opcional, utility function)

