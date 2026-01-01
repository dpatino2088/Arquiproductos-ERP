-- ====================================================
-- Find Specific BOM SKUs
-- ====================================================
-- This script searches for specific BOM components
-- Adjust the search patterns based on your actual SKU naming
-- ====================================================

-- 1) Search for Brackets (adjust pattern as needed)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'BRACKET' as component_type
FROM "CatalogItems"
WHERE deleted = false
AND (
  -- Common bracket patterns
  sku ILIKE '%bracket%' OR
  sku ILIKE '%BRACKET%' OR
  item_name ILIKE '%bracket%' OR
  item_name ILIKE '%soporte%' OR
  -- Your specific patterns (adjust these)
  sku ILIKE '%CC1003%' OR  -- Example from your data
  sku ILIKE '%CC1004%' OR  -- Example from your data
  sku ILIKE '%ABC-04%'     -- Example from your data
)
ORDER BY sku
LIMIT 50;

-- 2) Search for Bottom Rail / Bottom Bar
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'BOTTOM_RAIL' as component_type
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%bottom%rail%' OR
  sku ILIKE '%bottom%bar%' OR
  sku ILIKE '%barra%inferior%' OR
  item_name ILIKE '%bottom%rail%' OR
  item_name ILIKE '%bottom%bar%' OR
  item_name ILIKE '%barra%inferior%' OR
  -- Your specific patterns
  sku ILIKE '%ABC-27%' OR  -- Example from your data
  sku ILIKE '%CC1014%' OR  -- Example from your data
  sku ILIKE '%CC1015%'     -- Example from your data
)
ORDER BY sku
LIMIT 50;

-- 3) Search for Motor Parts
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'MOTOR' as component_type
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%motor%' OR
  sku ILIKE '%MOTOR%' OR
  item_name ILIKE '%motor%' OR
  -- Motor family patterns
  sku ILIKE '%CM-05%' OR
  sku ILIKE '%CM-06%' OR
  sku ILIKE '%CM-09%' OR
  sku ILIKE '%CM-10%' OR
  sku ILIKE '%CM-11%' OR  -- From your data
  sku ILIKE '%CM-12%' OR  -- From your data
  sku ILIKE '%CM-13%' OR  -- From your data
  sku ILIKE '%CM-15%' OR  -- From your data
  sku ILIKE '%CM-16%' OR  -- From your data
  sku ILIKE '%CM-17%'     -- From your data
)
ORDER BY sku
LIMIT 50;

-- 4) Search for Cassette Parts
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'CASSETTE' as component_type
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%cassette%' OR
  sku ILIKE '%CASSETTE%' OR
  sku ILIKE '%cass%' OR
  item_name ILIKE '%cassette%' OR
  item_name ILIKE '%cass%'
)
ORDER BY sku
LIMIT 50;

-- 5) Search for Tube Parts
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'TUBE' as component_type
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%tube%' OR
  sku ILIKE '%TUBE%' OR
  sku ILIKE '%RTU%' OR
  sku ILIKE '%tubo%' OR
  item_name ILIKE '%tube%' OR
  item_name ILIKE '%tubo%'
)
ORDER BY sku
LIMIT 50;

-- 6) Search for End Caps
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'END_CAP' as component_type
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%end%cap%' OR
  sku ILIKE '%endcap%' OR
  sku ILIKE '%tapa%' OR
  item_name ILIKE '%end%cap%' OR
  item_name ILIKE '%tapa%'
)
ORDER BY sku
LIMIT 50;

-- 7) Search for Clutch / Manual Drive Parts
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'CLUTCH' as component_type
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%clutch%' OR
  sku ILIKE '%CLUTCH%' OR
  sku ILIKE '%manual%' OR
  item_name ILIKE '%clutch%' OR
  item_name ILIKE '%manual%'
)
ORDER BY sku
LIMIT 50;

-- 8) Search for Chain Parts
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'CHAIN' as component_type
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%chain%' OR
  sku ILIKE '%CHAIN%' OR
  sku ILIKE '%cadena%' OR
  sku ILIKE '%V15%' OR
  item_name ILIKE '%chain%' OR
  item_name ILIKE '%cadena%'
)
ORDER BY sku
LIMIT 50;

-- 9) Search by Color Suffix (to find color variants)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  CASE 
    WHEN sku ILIKE '%W' OR sku ILIKE '%WH%' OR sku ILIKE '%WHITE%' THEN 'WHITE'
    WHEN sku ILIKE '%B' OR sku ILIKE '%BK%' OR sku ILIKE '%BLACK%' THEN 'BLACK'
    WHEN sku ILIKE '%S' OR sku ILIKE '%SILVER%' THEN 'SILVER'
    WHEN sku ILIKE '%BR%' OR sku ILIKE '%BRONZE%' THEN 'BRONZE'
    ELSE 'NO_COLOR'
  END as color_variant
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%W' OR sku ILIKE '%WH%' OR sku ILIKE '%WHITE%' OR
  sku ILIKE '%B' OR sku ILIKE '%BK%' OR sku ILIKE '%BLACK%' OR
  sku ILIKE '%S' OR sku ILIKE '%SILVER%' OR
  sku ILIKE '%BR%' OR sku ILIKE '%BRONZE%'
)
AND item_type IN ('component', 'hardware', 'accessory')
ORDER BY item_name, sku
LIMIT 100;









