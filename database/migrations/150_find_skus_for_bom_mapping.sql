-- ====================================================
-- Helper Script: Find SKUs for BOM Mapping
-- ====================================================
-- This script helps you find SKU IDs in CatalogItems
-- so you can populate HardwareColorMapping, MotorTubeCompatibility, etc.
-- ====================================================

-- 1) Find Brackets (RC4004 and variants)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'Use for HardwareColorMapping (brackets)' as usage
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%RC4004%' OR
  sku ILIKE '%bracket%' OR
  item_name ILIKE '%bracket%'
)
ORDER BY sku;

-- 2) Find Bottom Rail (RCA-04 and variants)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'Use for HardwareColorMapping (bottom rail)' as usage
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%RCA-04%' OR
  sku ILIKE '%RC3126%' OR
  sku ILIKE '%bottom%rail%' OR
  item_name ILIKE '%bottom%rail%'
)
ORDER BY sku;

-- 3) Find Cassette Parts
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'Use for CassettePartsMapping' as usage
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%cassette%' OR
  sku ILIKE '%cass%' OR
  item_name ILIKE '%cassette%'
)
ORDER BY sku;

-- 4) Find Motor Parts (crowns, drives, adapters)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'Use for MotorTubeCompatibility' as usage
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%RC3100%' OR
  sku ILIKE '%RC3164%' OR
  sku ILIKE '%RC3044%' OR
  sku ILIKE '%RC4032%' OR
  sku ILIKE '%RC4023%' OR
  sku ILIKE '%RC4024%' OR
  sku ILIKE '%RCU-13%' OR
  sku ILIKE '%RCU-14%' OR
  sku ILIKE '%RC3005%' OR
  sku ILIKE '%motor%crown%' OR
  sku ILIKE '%motor%adapter%' OR
  item_name ILIKE '%motor%crown%' OR
  item_name ILIKE '%motor%adapter%'
)
ORDER BY sku;

-- 5) Find Manual Clutch Parts (RC4001, RC4002, RC4003)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'Use for BOMComponents (manual drive)' as usage
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%RC4001%' OR
  sku ILIKE '%RC4002%' OR
  sku ILIKE '%RC4003%' OR
  sku ILIKE '%clutch%' OR
  item_name ILIKE '%clutch%'
)
ORDER BY sku;

-- 6) Find Chain Parts (V15DP, V15M)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'Use for BOMComponents (manual chain)' as usage
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%V15DP%' OR
  sku ILIKE '%V15M%' OR
  sku ILIKE '%chain%' OR
  item_name ILIKE '%chain%'
)
ORDER BY sku;

-- 7) Find Safety/Tensioner Parts (RC4005, RC4007)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'Use for BOMComponents (safety devices)' as usage
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%RC4005%' OR
  sku ILIKE '%RC4007%' OR
  sku ILIKE '%safety%' OR
  sku ILIKE '%tensioner%' OR
  item_name ILIKE '%safety%' OR
  item_name ILIKE '%tensioner%'
)
ORDER BY sku;

-- 8) Find End Caps (RCA-21, bracket end caps, etc.)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'Use for BOMComponents or CassettePartsMapping (endcaps)' as usage
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%RCA-21%' OR
  sku ILIKE '%end%cap%' OR
  sku ILIKE '%endcap%' OR
  item_name ILIKE '%end%cap%'
)
ORDER BY sku;

-- 9) Summary: Count by item_type
SELECT 
  item_type,
  COUNT(*) as count,
  STRING_AGG(DISTINCT sku, ', ' ORDER BY sku) FILTER (WHERE sku IS NOT NULL) as sample_skus
FROM "CatalogItems"
WHERE deleted = false
GROUP BY item_type
ORDER BY item_type;









