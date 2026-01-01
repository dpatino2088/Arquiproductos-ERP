# 📋 Procedimiento Estándar para Deshabilitar Productos/Modelos de Cortinas

## Objetivo
Este documento establece el procedimiento estándar para deshabilitar productos o modelos de cortinas en el sistema sin romper funcionalidades existentes ni perder datos históricos.

## ⚠️ Principios Importantes

1. **NUNCA eliminar datos físicamente** - Usar soft-delete (`deleted = true` o `archived = true`)
2. **Mantener integridad referencial** - Los productos deshabilitados seguirán existiendo en cotizaciones históricas
3. **Filtrar en todas las consultas** - Asegurar que las queries excluyan productos deshabilitados

---

## 🎯 Opción 1: Deshabilitar ProductType (Modelo de Cortina)

### Método: Usar campo `deleted` en tabla `ProductTypes`

**SQL:**
```sql
-- Deshabilitar un ProductType específico
UPDATE "ProductTypes"
SET 
  deleted = true,
  updated_at = NOW()
WHERE 
  organization_id = '<ORGANIZATION_ID>'  -- Reemplazar con UUID de tu organización
  AND (name ILIKE '%nombre_producto%' OR code = 'codigo-producto')
  AND deleted = false;

-- Verificar que se deshabilitó correctamente
SELECT id, name, code, deleted, archived
FROM "ProductTypes"
WHERE organization_id = '<ORGANIZATION_ID>'
  AND (name ILIKE '%nombre_producto%' OR code = 'codigo-producto');
```

### Efectos:
- ✅ El producto **NO aparecerá** en los selectores de nuevo producto
- ✅ Las cotizaciones históricas **SIGUEN FUNCIONANDO** (mantienen referencia)
- ✅ Los BOM Templates asociados **PERMANECEN** (no se eliminan)
- ✅ Se puede reactivar cambiando `deleted = false`

---

## 🎯 Opción 2: Archivar ProductType (Alternativa)

### Método: Usar campo `archived` en tabla `ProductTypes`

**SQL:**
```sql
-- Archivar un ProductType
UPDATE "ProductTypes"
SET 
  archived = true,
  updated_at = NOW()
WHERE 
  organization_id = '<ORGANIZATION_ID>'
  AND (name ILIKE '%nombre_producto%' OR code = 'codigo-producto')
  AND archived = false;

-- Verificar
SELECT id, name, code, deleted, archived
FROM "ProductTypes"
WHERE organization_id = '<ORGANIZATION_ID>'
  AND (name ILIKE '%nombre_producto%' OR code = 'codigo-producto');
```

### Efectos:
- Similar a `deleted`, pero permite diferenciación semántica
- Útil si quieres mantener separación entre "deshabilitado" (`deleted`) y "archivado" (`archived`)

---

## 🔍 Verificación: Identificar ProductType a Deshabilitar

### Paso 1: Buscar el ProductType por nombre o código

```sql
-- Buscar ProductTypes activos
SELECT 
  id,
  name,
  code,
  organization_id,
  deleted,
  archived,
  created_at
FROM "ProductTypes"
WHERE organization_id = '<ORGANIZATION_ID>'
  AND deleted = false
  AND archived = false
ORDER BY name;
```

### Paso 2: Verificar dependencias (cotizaciones existentes)

```sql
-- Ver cuántas cotizaciones usan este ProductType
SELECT 
  COUNT(*) as total_quote_lines,
  COUNT(DISTINCT quote_id) as total_quotes
FROM "QuoteLines"
WHERE product_type_id = '<PRODUCT_TYPE_ID>'  -- Reemplazar con UUID del ProductType
  AND deleted = false;
```

### Paso 3: Verificar BOM Templates asociados

```sql
-- Ver BOM Templates del ProductType
SELECT 
  bt.id,
  bt.name,
  bt.product_type_id,
  bt.deleted
FROM "BOMTemplates" bt
WHERE bt.product_type_id = '<PRODUCT_TYPE_ID>'
  AND bt.deleted = false;
```

**⚠️ IMPORTANTE:** Los BOM Templates NO se eliminan automáticamente. Si deseas deshabilitarlos también, ver sección "Deshabilitar BOM Templates".

---

## 🛠️ Reactivar un Producto Deshabilitado

```sql
-- Reactivar ProductType
UPDATE "ProductTypes"
SET 
  deleted = false,
  archived = false,  -- Opcional: también desarchivar
  updated_at = NOW()
WHERE 
  id = '<PRODUCT_TYPE_ID>'
  AND organization_id = '<ORGANIZATION_ID>';
```

---

## 📦 Deshabilitar BOM Templates (Opcional)

Si también deseas deshabilitar los BOM Templates asociados:

```sql
-- Deshabilitar BOM Templates de un ProductType
UPDATE "BOMTemplates"
SET 
  deleted = true,
  updated_at = NOW()
WHERE 
  product_type_id = '<PRODUCT_TYPE_ID>'
  AND organization_id = '<ORGANIZATION_ID>'
  AND deleted = false;
```

---

## 🔄 Deshabilitar CatalogItems (Componentes/Fabricos)

Si necesitas deshabilitar items específicos del catálogo (componentes, telas, etc.):

```sql
-- Deshabilitar CatalogItem por SKU o nombre
UPDATE "CatalogItems"
SET 
  deleted = true,
  updated_at = NOW()
WHERE 
  organization_id = '<ORGANIZATION_ID>'
  AND (sku = 'SKU_AQUI' OR item_name ILIKE '%nombre_item%')
  AND deleted = false;

-- Verificar
SELECT id, sku, item_name, deleted, archived
FROM "CatalogItems"
WHERE organization_id = '<ORGANIZATION_ID>'
  AND (sku = 'SKU_AQUI' OR item_name ILIKE '%nombre_item%');
```

---

## ✅ Checklist de Verificación Post-Deshabilitación

Después de deshabilitar un producto, verifica:

- [ ] El producto **NO aparece** en el selector de productos al crear nueva cotización
- [ ] Las cotizaciones existentes con ese producto **SIGUEN VISIBLES** y funcionando
- [ ] Los reportes históricos **NO se rompen**
- [ ] La búsqueda de productos **NO incluye** el producto deshabilitado
- [ ] Los usuarios **NO pueden** seleccionar el producto deshabilitado en nuevos flujos

---

## 🎯 Ejemplo Completo: Deshabilitar "Triple Shade"

```sql
-- 1. Identificar el ProductType
SELECT id, name, code
FROM "ProductTypes"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND (name ILIKE '%triple%shade%' OR code ILIKE '%triple-shade%')
  AND deleted = false;
-- Resultado ejemplo: id = 'abc123-def456-...'

-- 2. Verificar dependencias
SELECT COUNT(*) as quote_lines_count
FROM "QuoteLines"
WHERE product_type_id = 'abc123-def456-...'
  AND deleted = false;

-- 3. Deshabilitar
UPDATE "ProductTypes"
SET deleted = true, updated_at = NOW()
WHERE id = 'abc123-def456-...'
  AND organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6';

-- 4. Verificar
SELECT id, name, code, deleted
FROM "ProductTypes"
WHERE id = 'abc123-def456-...';
```

---

## 🔐 Notas de Seguridad

1. **Siempre usar `organization_id`** en las queries para evitar deshabilitar productos de otras organizaciones
2. **Hacer backup** antes de cambios masivos
3. **Probar en desarrollo** antes de aplicar en producción
4. **Documentar cambios** en un log de cambios

---

## 📝 Campos Disponibles en `ProductTypes`

Según el esquema actual, `ProductTypes` tiene:
- `id` (uuid, PK)
- `organization_id` (uuid, FK)
- `name` (text)
- `code` (text, opcional)
- `deleted` (boolean, default false) ✅ **Usar para deshabilitar**
- `archived` (boolean, default false) ✅ **Alternativa para archivar**
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

---

## 🚨 Qué NO Hacer

❌ **NO usar `DELETE FROM`** - Esto elimina físicamente y rompe referencias
❌ **NO deshabilitar si hay cotizaciones activas pendientes** - Revisar primero
❌ **NO deshabilitar BOM Templates sin revisar dependencias** - Puede afectar cotizaciones existentes
❌ **NO cambiar `organization_id`** - Esto movería el producto a otra organización

---

## 📞 Soporte

Si tienes dudas o necesitas ayuda, consulta:
1. Este documento
2. Las migraciones en `database/migrations/` para ver ejemplos de queries
3. El código fuente en `src/` para ver cómo se filtran productos en la UI

---

**Última actualización:** 2025-01-XX
**Versión:** 1.0









