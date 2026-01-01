-- ====================================================
-- Find Motor Parts for MotorTubeCompatibility
-- ====================================================
-- Use this to find SKU IDs for motor crowns and drives
-- ====================================================

-- 1) Find Motor Crowns (RC3100 patterns or crown-related)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'Use for required_crown_item_id' as usage
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%RC3100%' OR
  sku ILIKE '%crown%' OR
  item_name ILIKE '%crown%' OR
  item_name ILIKE '%motor%crown%' OR
  item_name ILIKE '%corona%motor%'
)
ORDER BY sku;

-- 2) Find Motor Drives/Adapters (RC3164, RC3044, etc.)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'Use for required_drive_item_id' as usage
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%RC3164%' OR
  sku ILIKE '%RC3044%' OR
  sku ILIKE '%RC4032%' OR
  sku ILIKE '%RC4023%' OR
  sku ILIKE '%RC4024%' OR
  sku ILIKE '%drive%' OR
  item_name ILIKE '%drive%' OR
  item_name ILIKE '%motor%adapter%' OR
  item_name ILIKE '%motor%drive%' OR
  item_name ILIKE '%adaptador%motor%'
)
ORDER BY sku;

-- 3) Find Motor Accessories (RCU-13, RCU-14, RC3005, etc.)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'Use for required_accessory_item_id (optional)' as usage
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%RCU-13%' OR
  sku ILIKE '%RCU-14%' OR
  sku ILIKE '%RC3005%' OR
  sku ILIKE '%motor%accessory%' OR
  item_name ILIKE '%motor%accessory%'
)
ORDER BY sku;

-- 4) Find Tube-related parts (to understand tube types)
SELECT 
  id,
  sku,
  item_name,
  item_type,
  'Tube parts - check if related to RTU-42, RTU-50, RTU-65, RTU-80' as usage
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%RTU%' OR
  sku ILIKE '%tube%' OR
  item_name ILIKE '%tube%' OR
  item_name ILIKE '%tubo%'
)
ORDER BY sku
LIMIT 30;









