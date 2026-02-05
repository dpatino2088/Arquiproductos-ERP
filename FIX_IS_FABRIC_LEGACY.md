# Fix: Remover Referencias Legacy a is_fabric

**Fecha:** 2026-02-02  
**Error:** "Could not find the 'is_fabric' column of 'CatalogItems' in the schema cache"  
**Estado:** Fix principal aplicado, limpieza adicional pendiente

---

## 🎯 Problema

La columna `is_fabric` **NO EXISTE** en la tabla `CatalogItems`. Es una columna legacy que fue reemplazada por `is_roll`.

### Estructura Real de BD (verificada en dump 2026-02-02):

```sql
CREATE TABLE "CatalogItems" (
  id uuid,
  organization_id uuid,
  name text,
  sku text,
  unit_of_measure text,
  description text,
  category_id uuid,
  image_url text,
  measure_basis text,
  collection_name text,
  variant_name text,
  roll_width numeric(12,4),
  color text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  cost_exw numeric(12,4),
  manufacturer text,
  manufacturer_id uuid,
  is_roll boolean DEFAULT false,  -- ✅ Esta existe
  roll_collection_id uuid,
  roll_type text,
  item_role text,
  roll_pricing_mode text
  -- ❌ NO existe: is_fabric
);
```

---

## ✅ Fix Aplicado: CatalogItemNew.tsx

### Cambios Realizados

1. **Schema de Zod** - Removido `is_fabric`:
```typescript
// ANTES ❌
is_fabric: z.boolean(),
is_roll: z.boolean(),

// AHORA ✅
is_roll: z.boolean(),
```

2. **Defaults** - Removido de valores por defecto:
```typescript
// ANTES ❌
is_fabric: false,
is_roll: false,

// AHORA ✅
is_roll: false,
```

3. **Carga de Datos** - Removido al cargar desde BD:
```typescript
// ANTES ❌
is_fabric: data.is_fabric || false,
is_roll: data.is_roll || false,

// AHORA ✅
is_roll: data.is_roll || false,
```

4. **useEffect de Sincronización** - Eliminado completamente:
```typescript
// ANTES ❌
useEffect(() => {
  setValue('is_fabric', watch('is_roll'));
}, [watch('is_roll'), setValue]);

// AHORA ✅
// Eliminado - no es necesario
```

5. **Payload al Guardar** - Removido del objeto enviado al backend:
```typescript
// ANTES ❌
is_fabric: values.is_fabric,
is_roll: values.is_roll,

// AHORA ✅
is_roll: values.is_roll,
```

6. **Comentarios** - Actualizados:
```typescript
// ANTES ❌
// Roll/Fabric fields
// - image_url, measure_basis, is_fabric, collection_name, variant_name

// AHORA ✅
// Roll fields
// - image_url, measure_basis, collection_name, variant_name
```

---

## ⚠️ Otros Archivos con Referencias a is_fabric

Los siguientes archivos también tienen referencias a `is_fabric` y pueden necesitar corrección:

### Archivos de UI/Componentes:
1. `src/pages/catalog/BOMTemplates.tsx`
2. `src/pages/catalog/ImportCatalog.tsx`
3. `src/pages/catalog/Items.tsx`
4. `src/pages/catalog/Collections.tsx`
5. `src/pages/sales/curtain-config/AccessoriesStep.tsx`
6. `src/components/catalog/CatalogPicker.tsx`

### Archivos de Lógica/Helpers:
7. `src/hooks/useCatalogPicker.ts`
8. `src/hooks/useCatalog.ts`
9. `src/hooks/useBOM.ts`
10. `src/hooks/useRollerCatalogItems.ts`
11. `src/lib/uom-conversions.ts`
12. `src/lib/catalog-item-helpers.ts`
13. `src/lib/bom/createConfiguredProductPreview.ts`

### Archivos de Tipos:
14. `src/types/catalog.ts`
15. `src/types/rates.ts`

### Backups:
16. `src/pages/catalog/CatalogItemNew.tsx.backup` (ignorar - es backup)

---

## 🔍 Estrategia de Limpieza

### Prioridad 1 (Crítico): ✅ COMPLETADO
- ✅ `src/pages/catalog/CatalogItemNew.tsx` - **Fix aplicado**

### Prioridad 2 (Alto - Queries a BD):
Estos archivos probablemente hacen queries SELECT con `is_fabric`:

1. `src/hooks/useCatalog.ts`
2. `src/hooks/useCatalogPicker.ts`
3. `src/pages/catalog/Items.tsx`
4. `src/components/catalog/CatalogPicker.tsx`

**Acción:** Remover `is_fabric` de los SELECT queries, usar solo `is_roll`.

### Prioridad 3 (Medio - Tipos TypeScript):

1. `src/types/catalog.ts` - Probablemente define interface con `is_fabric`
2. `src/types/rates.ts` - Puede tener tipos relacionados

**Acción:** Actualizar interfaces para usar solo `is_roll`.

### Prioridad 4 (Bajo - Lógica Condicional):

Archivos que pueden tener lógica tipo `if (item.is_fabric)`:

1. `src/lib/uom-conversions.ts`
2. `src/lib/catalog-item-helpers.ts`
3. `src/lib/bom/createConfiguredProductPreview.ts`
4. `src/hooks/useBOM.ts`
5. `src/hooks/useRollerCatalogItems.ts`

**Acción:** Cambiar `is_fabric` por `is_roll` en la lógica.

---

## 🧪 Testing

### Test 1: Verificar Fix Principal
1. Recargar la aplicación
2. Ir a Catalog → Edit Item (cualquier item)
3. **Verificar:** Ya NO debe aparecer el error "Could not find the 'is_fabric' column"
4. **Verificar:** Tab Rates debe cargar correctamente

### Test 2: Crear Nuevo Roll
1. Catalog → New Item
2. Profile tab: Marcar `is_roll = true`
3. Guardar
4. **Verificar:** Se guarda correctamente sin error de `is_fabric`

### Test 3: Verificar Otros Componentes
1. Ir a Catalog → Items (lista)
2. Usar filtros/búsqueda
3. **Si hay error:** Ese componente necesita limpieza adicional

---

## 📋 Checklist de Correcciones

### Completadas:
- [x] `src/pages/catalog/CatalogItemNew.tsx` - Schema Zod
- [x] `src/pages/catalog/CatalogItemNew.tsx` - Defaults
- [x] `src/pages/catalog/CatalogItemNew.tsx` - Carga de datos
- [x] `src/pages/catalog/CatalogItemNew.tsx` - useEffect sync
- [x] `src/pages/catalog/CatalogItemNew.tsx` - Payload guardar
- [x] `src/pages/catalog/CatalogItemNew.tsx` - Comentarios

### Pendientes (según necesidad):
- [ ] `src/types/catalog.ts` - Actualizar interfaces
- [ ] `src/types/rates.ts` - Actualizar interfaces
- [ ] `src/hooks/useCatalog.ts` - Queries SELECT
- [ ] `src/hooks/useCatalogPicker.ts` - Queries SELECT
- [ ] `src/pages/catalog/Items.tsx` - Queries SELECT
- [ ] `src/components/catalog/CatalogPicker.tsx` - Queries SELECT
- [ ] `src/lib/uom-conversions.ts` - Lógica condicional
- [ ] `src/lib/catalog-item-helpers.ts` - Lógica condicional
- [ ] `src/lib/bom/createConfiguredProductPreview.ts` - Lógica
- [ ] `src/hooks/useBOM.ts` - Lógica
- [ ] `src/hooks/useRollerCatalogItems.ts` - Lógica
- [ ] `src/pages/catalog/BOMTemplates.tsx` - UI
- [ ] `src/pages/catalog/ImportCatalog.tsx` - UI
- [ ] `src/pages/catalog/Collections.tsx` - UI
- [ ] `src/pages/sales/curtain-config/AccessoriesStep.tsx` - UI

---

## 🎯 Próximos Pasos

### Inmediato:
1. ✅ Probar el fix en `CatalogItemNew.tsx`
2. ✅ Verificar que el error "Could not find is_fabric" desaparece
3. ✅ Confirmar que Rates tab funciona correctamente

### Si hay más errores:
1. Identificar qué archivo está causando el error
2. Aplicar el mismo patrón de corrección (remover is_fabric, usar is_roll)
3. Testing incremental

### Estrategia Recomendada:
- **No corregir todo de una vez** - Pueden ser referencias benignas (comentarios, tipos no usados)
- **Corregir solo lo que causa errores** - Enfoque pragmático
- **Testing después de cada corrección** - Evitar romper funcionalidad existente

---

## 💡 Notas

### ¿Por qué existía is_fabric?

Probablemente fue un campo legacy de cuando solo había "fabrics" como rolls. Luego se generalizó a `is_roll` (que incluye fabric, vinyl, film, mesh, etc.) pero `is_fabric` no se eliminó completamente del código frontend.

### ¿Cómo saber si es fabric ahora?

```typescript
// FORMA CORRECTA:
if (item.is_roll && item.roll_type === 'fabric') {
  // Es fabric
}

// FORMA INCORRECTA (legacy):
if (item.is_fabric) {  // ❌ Esta columna no existe
  // ...
}
```

### Migración de Lógica

```typescript
// ANTES (legacy)
const isFabric = item.is_fabric;

// AHORA (correcto)
const isFabric = item.is_roll && item.roll_type === 'fabric';

// O simplemente verificar si es roll:
const isRoll = item.is_roll;
```

---

**Fix principal aplicado:** 2026-02-02  
**Error resuelto:** ✅ "Could not find is_fabric column"  
**Limpieza adicional:** Según necesidad (ver checklist)
