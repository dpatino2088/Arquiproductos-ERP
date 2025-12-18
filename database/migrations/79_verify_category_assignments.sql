-- ====================================================
-- Migration 79: Verificar asignación de categorías
-- ====================================================
-- Este script verifica que los CatalogItems tengan
-- las categorías correctas asignadas
-- ====================================================

-- Verificar distribución de items por categoría
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

-- Verificar específicamente Manual Drives
SELECT 
  COUNT(*) as items_en_manual_drives
FROM public."CatalogItems" ci
INNER JOIN public."ItemCategories" ic ON ci.item_category_id = ic.id
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND ci.deleted = false
  AND ic.deleted = false
  AND ic.code = 'MOTOR-MANUAL';

-- Ver algunos items de ejemplo con su categoría
SELECT 
  ci.sku,
  ci.name,
  ci.item_name,
  ic.name as categoria_nombre,
  ic.code as categoria_codigo,
  ci.is_fabric
FROM public."CatalogItems" ci
LEFT JOIN public."ItemCategories" ic ON ci.item_category_id = ic.id AND ic.deleted = false
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND ci.deleted = false
LIMIT 20;

-- Verificar si hay items sin categoría
SELECT 
  COUNT(*) as items_sin_categoria
FROM public."CatalogItems" ci
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND ci.deleted = false
  AND ci.item_category_id IS NULL;

-- Verificar items con item_category_id inválido
SELECT 
  COUNT(*) as items_con_categoria_invalida
FROM public."CatalogItems" ci
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
  AND ci.deleted = false
  AND ci.item_category_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public."ItemCategories" ic
    WHERE ic.id = ci.item_category_id
      AND ic.deleted = false
  );

