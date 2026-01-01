-- ====================================================
-- Verificación de Resultados de Migración
-- ====================================================
-- Este script verifica que los datos se migraron correctamente
-- desde _stg_catalog_update a CatalogItems
-- ====================================================

-- 1. Comparar conteos
SELECT 
  'Comparación de Registros' as seccion,
  (SELECT COUNT(*) FROM public."_stg_catalog_update" WHERE sku IS NOT NULL AND trim(sku) <> '') as registros_en_staging,
  (SELECT COUNT(*) FROM public."CatalogItems" 
   WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6' 
   AND deleted = false) as registros_en_catalogitems;

-- 2. Verificar que los SKUs del staging están en CatalogItems
SELECT 
  'SKUs Migrados' as seccion,
  COUNT(DISTINCT s.sku) as skus_en_staging,
  COUNT(DISTINCT c.sku) as skus_en_catalogitems,
  COUNT(DISTINCT s.sku) - COUNT(DISTINCT c.sku) as skus_faltantes
FROM public."_stg_catalog_update" s
LEFT JOIN public."CatalogItems" c
  ON c.sku = s.sku
  AND c.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND c.deleted = false
WHERE s.sku IS NOT NULL AND trim(s.sku) <> '';

-- 3. Verificar columnas importantes
SELECT 
  'Verificación de Columnas' as seccion,
  COUNT(*) FILTER (WHERE collection_name IS NOT NULL) as con_collection_name,
  COUNT(*) FILTER (WHERE variant_name IS NOT NULL) as con_variant_name,
  COUNT(*) FILTER (WHERE roll_width_m IS NOT NULL) as con_roll_width_m,
  COUNT(*) FILTER (WHERE cost_exw IS NOT NULL AND cost_exw > 0) as con_cost_exw,
  COUNT(*) FILTER (WHERE family IS NOT NULL) as con_family
FROM public."CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false;

-- 4. Ejemplos de registros migrados
SELECT 
  'Ejemplos de Registros Migrados' as seccion,
  sku,
  item_name,
  collection_name,
  variant_name,
  is_fabric,
  roll_width_m,
  cost_exw,
  active,
  manufacturer_id,
  item_category_id
FROM public."CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false
ORDER BY created_at DESC
LIMIT 10;

-- 5. Verificar registros de fabric con collection_name
SELECT 
  'Fabric Items con Collection' as seccion,
  COUNT(*) as total,
  COUNT(DISTINCT collection_name) as colecciones_unicas
FROM public."CatalogItems"
WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND deleted = false
  AND is_fabric = true
  AND collection_name IS NOT NULL;








