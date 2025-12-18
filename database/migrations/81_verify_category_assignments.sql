-- ====================================================
-- Migration 81: Verificar asignación de categorías después del script 80
-- ====================================================

-- Ver distribución completa de items por categoría
SELECT 
  ic.name as categoria_nombre,
  ic.code as categoria_codigo,
  COUNT(*) as cantidad_items
FROM public."CatalogItems" ci
INNER JOIN public."ItemCategories" ic ON ci.item_category_id = ic.id
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND ci.deleted = false
  AND ic.deleted = false
GROUP BY ic.name, ic.code
ORDER BY cantidad_items DESC;

-- Verificar específicamente Batteries
SELECT 
  COUNT(*) as items_en_batteries,
  COUNT(CASE WHEN ci.item_category_id IS NOT NULL THEN 1 END) as items_con_categoria
FROM public."CatalogItems" ci
LEFT JOIN public."ItemCategories" ic ON ci.item_category_id = ic.id AND ic.deleted = false
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND ci.deleted = false
  AND ic.code = 'ACC-BATTERY';

-- Ver algunos items de ejemplo que deberían estar en Batteries
SELECT 
  ci.sku,
  ci.name,
  ci.item_name,
  ci.item_category_id,
  ic.name as categoria_actual,
  ic.code as categoria_codigo
FROM public."CatalogItems" ci
LEFT JOIN public."ItemCategories" ic ON ci.item_category_id = ic.id AND ic.deleted = false
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND ci.deleted = false
  AND (
    LOWER(COALESCE(ci.sku, '')) LIKE '%battery%'
    OR LOWER(COALESCE(ci.sku, '')) LIKE '%batt%'
    OR LOWER(COALESCE(ci.name, '')) LIKE '%battery%'
    OR LOWER(COALESCE(ci.item_name, '')) LIKE '%battery%'
  )
LIMIT 10;

-- Verificar si hay items sin categoría
SELECT 
  COUNT(*) as items_sin_categoria
FROM public."CatalogItems" ci
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND ci.deleted = false
  AND ci.item_category_id IS NULL;

