-- ====================================================
-- Script: Update Existing QuoteLines with Operating System Drives
-- ====================================================
-- This script helps update existing QuoteLines that don't have
-- operating_system_drive_id set. You'll need to manually map
-- the drives to each line based on your business logic.
-- ====================================================

-- STEP 1: Check current status
-- See which QuoteLines need to be updated
SELECT 
    ql.id,
    ql.quote_id,
    ql.area,
    ql.position,
    ql.product_type,
    ql.operating_system_drive_id,
    ql.created_at
FROM "QuoteLines" ql
WHERE ql.operating_system_drive_id IS NULL
  AND ql.deleted = false
ORDER BY ql.created_at DESC;

-- STEP 2: Example updates (MODIFY THESE WITH YOUR ACTUAL DATA)
-- Replace the UUIDs and IDs with your actual values

-- Example 1: Update a specific line with a specific drive
-- UPDATE "QuoteLines"
-- SET operating_system_drive_id = 'a4838b29-1411-49e0-8904-6afba3e66728' -- Replace with actual drive UUID
-- WHERE id = 'YOUR_LINE_ID_HERE' -- Replace with actual line ID
--   AND deleted = false;

-- Example 2: Update all lines in a quote with the same drive
-- UPDATE "QuoteLines"
-- SET operating_system_drive_id = 'a4838b29-1411-49e0-8904-6afba3e66728' -- Replace with actual drive UUID
-- WHERE quote_id = 'YOUR_QUOTE_ID_HERE' -- Replace with actual quote ID
--   AND operating_system_drive_id IS NULL
--   AND deleted = false;

-- Example 3: Update lines by product type (if all roller shades use the same drive)
-- UPDATE "QuoteLines"
-- SET operating_system_drive_id = 'a4838b29-1411-49e0-8904-6afba3e66728' -- Replace with actual drive UUID
-- WHERE product_type = 'roller-shade'
--   AND operating_system_drive_id IS NULL
--   AND deleted = false;

-- ====================================================
-- STEP 3: Get available drives to choose from
-- ====================================================
-- Run this query to see all available operating system drives
SELECT 
    ci.id,
    ci.name,
    ci.sku,
    ci.metadata->>'manufacturer' as manufacturer,
    ci.metadata->>'system' as system,
    ci.metadata->>'category' as category
FROM "CatalogItems" ci
WHERE ci.deleted = false
  AND (
    ci.item_type = 'component' OR
    ci.item_type = 'accessory' OR
    ci.metadata->>'operatingDrive' = 'true' OR
    ci.metadata->>'category' IN ('Motors', 'Controls')
  )
ORDER BY ci.name;

-- ====================================================
-- STEP 4: Bulk update script template
-- ====================================================
-- Use this template to update multiple lines at once
-- Replace the CASE statement with your actual mappings

-- UPDATE "QuoteLines"
-- SET operating_system_drive_id = CASE
--   WHEN id = 'LINE_ID_1' THEN 'DRIVE_UUID_1'
--   WHEN id = 'LINE_ID_2' THEN 'DRIVE_UUID_2'
--   WHEN id = 'LINE_ID_3' THEN 'DRIVE_UUID_3'
--   -- Add more mappings as needed
--   ELSE operating_system_drive_id -- Keep existing if no match
-- END
-- WHERE id IN ('LINE_ID_1', 'LINE_ID_2', 'LINE_ID_3')
--   AND deleted = false;

-- ====================================================
-- STEP 5: Verification
-- ====================================================
-- After updating, verify the results
SELECT 
    COUNT(*) as total_lines,
    COUNT(operating_system_drive_id) as lines_with_drive,
    COUNT(*) - COUNT(operating_system_drive_id) as lines_without_drive
FROM "QuoteLines"
WHERE deleted = false;

-- Show lines that still need updating
SELECT 
    ql.id,
    ql.quote_id,
    ql.area,
    ql.position,
    ql.product_type,
    ql.created_at
FROM "QuoteLines" ql
WHERE ql.operating_system_drive_id IS NULL
  AND ql.deleted = false;

