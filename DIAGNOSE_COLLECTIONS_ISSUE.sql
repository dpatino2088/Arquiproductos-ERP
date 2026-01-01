-- ====================================================
-- Diagnóstico: Problema con Colecciones después de Migración
-- ====================================================
-- Este script verifica qué pasó con las colecciones
-- después de la migración
-- ====================================================

-- 1. Verificar cuántos items tienen collection_name
SELECT 
  'Items con collection_name' as seccion,
  COUNT(*) FILTER (WHERE collection_name IS NOT NULL AND trim(collection_name) <> '') as con_collection_name,
  COUNT(*) FILTER (WHERE collection_name IS NULL OR trim(collection_name) = '') as sin_collection_name,
  COUNT(*) as total_items
FROM public."CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false;

-- 2. Verificar cuántos items de fabric tienen collection_name
SELECT 
  'Fabric Items con collection_name' as seccion,
  COUNT(*) FILTER (WHERE is_fabric = true AND collection_name IS NOT NULL AND trim(collection_name) <> '') as fabric_con_collection,
  COUNT(*) FILTER (WHERE is_fabric = true AND (collection_name IS NULL OR trim(collection_name) = '')) as fabric_sin_collection,
  COUNT(*) FILTER (WHERE is_fabric = true) as total_fabric
FROM public."CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false;

-- 3. Listar colecciones únicas disponibles
SELECT 
  'Colecciones Únicas' as seccion,
  collection_name,
  COUNT(*) as cantidad_items,
  COUNT(*) FILTER (WHERE is_fabric = true) as fabric_items
FROM public."CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false
  AND collection_name IS NOT NULL
  AND trim(collection_name) <> ''
GROUP BY collection_name
ORDER BY collection_name
LIMIT 20;

-- 4. Verificar si hay items que perdieron collection_name (comparar con staging)
SELECT 
  'Items que podrían haber perdido collection_name' as seccion,
  s.sku,
  s.collection_name as collection_en_staging,
  c.collection_name as collection_en_catalog,
  c.item_name
FROM public."_stg_catalog_update" s
LEFT JOIN public."CatalogItems" c
  ON c.sku = s.sku
  AND c.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND c.deleted = false
WHERE s.collection_name IS NOT NULL 
  AND trim(s.collection_name) <> ''
  AND (c.collection_name IS NULL OR trim(c.collection_name) = '')
LIMIT 10;

-- 5. Verificar items que fueron actualizados recientemente (después de la migración)
SELECT 
  'Items actualizados recientemente' as seccion,
  COUNT(*) as total,
  COUNT(*) FILTER (WHERE collection_name IS NOT NULL AND trim(collection_name) <> '') as con_collection,
  COUNT(*) FILTER (WHERE collection_name IS NULL OR trim(collection_name) = '') as sin_collection
FROM public."CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false
  AND updated_at >= NOW() - INTERVAL '1 hour';








