-- ====================================================
-- Update Specific QuoteLine with Operating System Drive
-- ====================================================
-- Updates the QuoteLine with ID: 5bba077c-cc21-43b8-91fd-e48cf2599de5
-- to have operating_system_drive_id set to a valid drive
-- ====================================================

-- First, let's see what drives are available
SELECT 
    id,
    name,
    sku
FROM "CatalogItems"
WHERE deleted = false
  AND (
    item_type = 'component' OR
    item_type = 'accessory' OR
    metadata->>'operatingDrive' = 'true' OR
    metadata->>'category' IN ('Motors', 'Controls')
  )
ORDER BY name
LIMIT 10;

-- Update the specific line with a drive
-- Using the drive "Prueba" (a4838b29-1411-49e0-8904-6afba3e66728) based on previous screenshots
UPDATE "QuoteLines"
SET operating_system_drive_id = 'a4838b29-1411-49e0-8904-6afba3e66728'
WHERE id = '5bba077c-cc21-43b8-91fd-e48cf2599de5'
  AND deleted = false;

-- Verify the update
SELECT 
    ql.id,
    ql.area,
    ql.position,
    ql.operating_system_drive_id,
    ci.name as drive_name
FROM "QuoteLines" ql
LEFT JOIN "CatalogItems" ci ON ci.id = ql.operating_system_drive_id
WHERE ql.id = '5bba077c-cc21-43b8-91fd-e48cf2599de5';


