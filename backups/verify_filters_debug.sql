-- ============================================================
-- Debug: Verificar por qué no aparecen motors/drives en el configurador
-- ============================================================

-- 1. Ver motors con sus colores
SELECT sku, name, color, item_role
FROM public."CatalogItems"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND item_role = 'motor'
  AND is_active = true
ORDER BY color, name
LIMIT 20;

-- 2. Ver drives con sus colores
SELECT sku, name, color, item_role
FROM public."CatalogItems"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND item_role = 'drive'
  AND is_active = true
ORDER BY color, name
LIMIT 20;

-- 3. Ver cuántos motors están linkados a Roller Shade en CatalogItemProductTypes
SELECT COUNT(*) as motors_linked_to_roller
FROM public."CatalogItemProductTypes" cipt
INNER JOIN public."CatalogItems" ci ON ci.id = cipt.catalog_item_id
WHERE cipt.product_type_id IN (
  SELECT id FROM public."ProductTypes"
  WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
    AND code IN ('roller_shade', 'ROLLER', 'roller-shade')
)
AND ci.item_role = 'motor'
AND ci.is_active = true;

-- 4. Ver cuántos drives están linkados a Roller Shade
SELECT COUNT(*) as drives_linked_to_roller
FROM public."CatalogItemProductTypes" cipt
INNER JOIN public."CatalogItems" ci ON ci.id = cipt.catalog_item_id
WHERE cipt.product_type_id IN (
  SELECT id FROM public."ProductTypes"
  WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
    AND code IN ('roller_shade', 'ROLLER', 'roller-shade')
)
AND ci.item_role = 'drive'
AND ci.is_active = true;

-- 5. Ver motors con color='white' (sin filtro de ProductType)
SELECT sku, name, color, item_role
FROM public."CatalogItems"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND item_role = 'motor'
  AND color = 'white'
  AND is_active = true
LIMIT 10;

-- 6. Ver drives con color='white' (sin filtro de ProductType)
SELECT sku, name, color, item_role
FROM public."CatalogItems"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND item_role = 'drive'
  AND color = 'white'
  AND is_active = true
LIMIT 10;

-- 7. Ver el ProductType ID de Roller Shade
SELECT id, code, name
FROM public."ProductTypes"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND code IN ('roller_shade', 'ROLLER', 'roller-shade');
