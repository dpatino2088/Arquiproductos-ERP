# 📋 Guía de Migración: Estructura Simplificada de Catálogo

## 🎯 Objetivo

Migrar la estructura del catálogo a una versión simplificada donde:
- **CollectionsCatalog** es una tabla de entidades (id, name, manufacturer_id)
- **variant_name** es un campo de texto en `CatalogItems` (no FK)
- **item_name** almacena el nombre del item desde el CSV
- **CollectionVariants** ya no se usa (se mantiene para compatibilidad)

## 📊 Estructura Final

### Para Telas (is_fabric = TRUE):
- **Nombre mostrado**: `Collection + Variant` (ej: "Block White", "Fiji White/White")
- **collection_id**: FK a `CollectionsCatalog`
- **variant_name**: Texto (ej: "White", "Cream", "White/White")

### Para Otros Items (is_fabric = FALSE):
- **Nombre mostrado**: `item_name` (ej: "Panel blind motor", "Curtain headrail 580cm")
- **collection_id**: NULL
- **variant_name**: NULL o texto (no se usa para el nombre)

## 🔧 Pasos de Migración

### Paso 1: Preparar la Base de Datos

Ejecuta en Supabase SQL Editor (en orden):

1. **Crear staging table**:
   ```sql
   -- Ejecutar: database/migrations/00_create_staging_table.sql
   ```

2. **Actualizar estructura de tablas**:
   ```sql
   -- Ejecutar: database/migrations/01_update_catalog_structure.sql
   ```
   Esto agregará:
   - `item_name` a `CatalogItems`
   - `variant_name` (texto) a `CatalogItems`
   - Columnas necesarias a `CollectionsCatalog`

### Paso 2: Importar CSV a Staging Table

**Opción A: Usando Supabase Table Editor**
1. Ve a Supabase Dashboard → Table Editor
2. Selecciona la tabla `_stg_catalog_items`
3. Click en "Insert" → "Import data from CSV"
4. Sube el archivo: `catalog_items_import_DP_COLLECTIONS_FINAL.csv`
5. Asegúrate de que el header esté marcado

**Opción B: Usando SQL COPY (si tienes acceso)**
```sql
COPY public."_stg_catalog_items" 
FROM '/path/to/catalog_items_import_DP_COLLECTIONS_FINAL.csv' 
WITH (FORMAT csv, HEADER true, DELIMITER ',');
```

### Paso 3: Importar Datos desde Staging

Ejecuta en Supabase SQL Editor:

```sql
-- Ejecutar: database/migrations/03_import_catalog_from_staging.sql
```

Este script:
1. Importa Manufacturers
2. Importa CollectionsCatalog (solo para fabrics)
3. **Actualiza** CatalogItems existentes con nuevos datos
4. **Inserta** nuevos CatalogItems que no existen
5. Crea relaciones ProductTypes

### Paso 4: Verificar Datos

Ejecuta estas queries para verificar:

```sql
-- Ejecutar: database/migrations/04_verify_import.sql
```

O manualmente:

```sql
-- Verificar Collections
SELECT COUNT(*) FROM "CollectionsCatalog" 
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6';

-- Verificar CatalogItems
SELECT 
  COUNT(*) as total,
  COUNT(*) FILTER (WHERE is_fabric = TRUE) as fabrics,
  COUNT(*) FILTER (WHERE is_fabric = FALSE) as non_fabrics,
  COUNT(*) FILTER (WHERE item_name IS NOT NULL) as with_item_name,
  COUNT(*) FILTER (WHERE variant_name IS NOT NULL) as with_variant_name
FROM "CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6';

-- Verificar algunos ejemplos
SELECT 
  sku,
  item_name,
  is_fabric,
  collection_id,
  variant_name,
  CASE 
    WHEN is_fabric AND collection_id IS NOT NULL AND variant_name IS NOT NULL
    THEN (SELECT name FROM "CollectionsCatalog" WHERE id = collection_id) || ' ' || variant_name
    ELSE item_name
  END as display_name
FROM "CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
LIMIT 20;
```

### Paso 5: Limpiar (Opcional)

Si todo está correcto, puedes eliminar la staging table:

```sql
DROP TABLE IF EXISTS public."_stg_catalog_items";
```

## 🔄 Cambios en el Código

Los siguientes archivos han sido actualizados:

1. **`src/hooks/useCatalogPicker.ts`**:
   - `variant_name` ahora es texto, no FK
   - `item_name` agregado
   - Lógica de nombres: Collection + Variant para telas, item_name para otros

2. **`src/components/catalog/CatalogPicker.tsx`**:
   - Usa `variant_name` como texto
   - Maneja items no-fabric sin collection/variant

3. **`src/hooks/useCatalog.ts`**:
   - `useCatalogCollections()` simplificado para usar `CollectionsCatalog` directamente

4. **`src/pages/sales/QuoteNew.tsx`**:
   - Lógica de nombres actualizada para mostrar Collection + Variant para telas

## ⚠️ Notas Importantes

1. **CollectionVariants**: La tabla se mantiene pero ya no se usa. Puedes eliminarla más adelante si no la necesitas.

2. **Backward Compatibility**: El campo `name` en `CatalogItems` se mantiene y se llena con `item_name` como fallback.

3. **RLS**: Asegúrate de que las políticas RLS permitan leer/escribir en estas tablas.

4. **Índices**: Considera agregar índices si el rendimiento es lento:
   ```sql
   CREATE INDEX IF NOT EXISTS idx_catalog_items_collection_id 
     ON "CatalogItems"(collection_id) 
     WHERE collection_id IS NOT NULL;
   
   CREATE INDEX IF NOT EXISTS idx_catalog_items_variant_name 
     ON "CatalogItems"(variant_name) 
     WHERE variant_name IS NOT NULL;
   ```

## 🐛 Troubleshooting

### Problema: No se ven las Collections
- Verifica que `CollectionsCatalog` tenga datos
- Verifica que `collection_id` en `CatalogItems` esté correctamente asignado
- Revisa la consola del navegador para errores

### Problema: Los nombres no se muestran correctamente
- Verifica que `item_name` esté lleno en `CatalogItems`
- Para telas, verifica que `collection_id` y `variant_name` estén llenos
- Revisa la lógica en `QuoteNew.tsx`

### Problema: Errores de FK constraint
- Asegúrate de que Manufacturers existan antes de importar Collections
- Asegúrate de que Collections existan antes de importar CatalogItems

## ✅ Checklist Final

- [ ] Staging table creada
- [ ] Estructura de tablas actualizada
- [ ] CSV importado a staging
- [ ] Datos importados desde staging
- [ ] Verificación de datos exitosa
- [ ] Código actualizado y funcionando
- [ ] UI muestra nombres correctamente
- [ ] Catalog Picker funciona para telas y no-telas

## 📞 Soporte

Si encuentras problemas, revisa:
1. Los logs de Supabase
2. La consola del navegador
3. Los errores de SQL en el editor

---

**Última actualización**: 2025-12-17
