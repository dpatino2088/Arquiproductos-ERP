-- ============================================================
-- Verificar CatalogItems por item_role
-- Para debug del configurador
-- ============================================================

-- Org ID
SET search_path TO public;
DO $$ 
DECLARE v_org uuid := '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid;
BEGIN
  RAISE NOTICE 'Organization: %', v_org;
END $$;

-- 1. Contar items por item_role
SELECT 
  item_role,
  COUNT(*) AS total_items,
  COUNT(DISTINCT color) AS distinct_colors,
  STRING_AGG(DISTINCT color, ', ') AS colors_available
FROM public."CatalogItems"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND is_active = true
GROUP BY item_role
ORDER BY item_role;

-- 2. Ver items específicos para bottom_bar
SELECT 
  id,
  sku,
  name,
  color,
  item_role,
  cost_exw
FROM public."CatalogItems"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND item_role = 'bottom_bar'
  AND is_active = true
ORDER BY color, name;

-- 3. Ver items específicos para motor
SELECT 
  id,
  sku,
  name,
  color,
  item_role,
  cost_exw
FROM public."CatalogItems"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND item_role = 'motor'
  AND is_active = true
ORDER BY color, name;

-- 4. Ver items específicos para drive (manual)
SELECT 
  id,
  sku,
  name,
  color,
  item_role,
  cost_exw
FROM public."CatalogItems"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND item_role = 'drive'
  AND is_active = true
ORDER BY color, name;

-- 5. Ver items específicos para headbox (cassette)
SELECT 
  id,
  sku,
  name,
  color,
  item_role,
  cost_exw
FROM public."CatalogItems"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND item_role = 'headbox'
  AND is_active = true
ORDER BY color, name;

-- 6. Ver items específicos para tube
SELECT 
  id,
  sku,
  name,
  color,
  item_role,
  cost_exw
FROM public."CatalogItems"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND item_role = 'tube'
  AND is_active = true
ORDER BY name;

-- 7. Verificar CatalogItemProductTypes para Roller Shade
SELECT 
  pt.code AS product_type_code,
  pt.name AS product_type_name,
  COUNT(cipt.catalog_item_id) AS linked_items_count,
  STRING_AGG(DISTINCT ci.item_role, ', ') AS roles_linked
FROM public."ProductTypes" pt
LEFT JOIN public."CatalogItemProductTypes" cipt ON pt.id = cipt.product_type_id
LEFT JOIN public."CatalogItems" ci ON cipt.catalog_item_id = ci.id
WHERE pt.organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND pt.code IN ('roller_shade', 'ROLLER', 'roller-shade')
  AND pt.deleted = false
GROUP BY pt.id, pt.code, pt.name;

-- 8. Ver todos los roles únicos en CatalogItems
SELECT DISTINCT item_role
FROM public."CatalogItems"
WHERE organization_id = '3acbb54c-c71f-4cb2-9fe3-d3ac513babe2'::uuid
  AND is_active = true
ORDER BY item_role;
