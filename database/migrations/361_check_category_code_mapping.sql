-- ====================================================
-- Migration 361: Check Category Code Mapping
-- ====================================================
-- Query to understand the relationship between component_role, 
-- BomInstanceLines.category_code, and ItemCategories.code
-- ====================================================

-- Query 1: Check what category_code values are currently in BomInstanceLines
SELECT 
    category_code,
    COUNT(*) as line_count
FROM "BomInstanceLines"
WHERE deleted = false
AND category_code IS NOT NULL
GROUP BY category_code
ORDER BY category_code;

-- Query 2: Check what ItemCategories.code values exist for each component_role type
-- This shows which category codes are actually used for different component roles
SELECT DISTINCT
    ic.code as item_category_code,
    ic.name as item_category_name,
    ci.item_category_id,
    COUNT(ci.id) as catalog_item_count
FROM "CatalogItems" ci
INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
WHERE ci.deleted = false
AND ic.deleted = false
GROUP BY ic.code, ic.name, ci.item_category_id
ORDER BY ic.code;

-- Query 3: Try to find a pattern - check if we can match component_role patterns to ItemCategories.code
-- Example: bracket -> COMP-BRACKET, tube -> COMP-TUBE, etc.
SELECT 
    'bracket' as expected_role,
    ic.code as category_code,
    COUNT(ci.id) as item_count
FROM "ItemCategories" ic
LEFT JOIN "CatalogItems" ci ON ci.item_category_id = ic.id AND ci.deleted = false
WHERE ic.code ILIKE '%bracket%'
OR ic.code ILIKE '%BRACKET%'
GROUP BY ic.code
UNION ALL
SELECT 
    'tube' as expected_role,
    ic.code as category_code,
    COUNT(ci.id) as item_count
FROM "ItemCategories" ic
LEFT JOIN "CatalogItems" ci ON ci.item_category_id = ic.id AND ci.deleted = false
WHERE ic.code ILIKE '%tube%'
OR ic.code ILIKE '%TUBE%'
GROUP BY ic.code
UNION ALL
SELECT 
    'fabric' as expected_role,
    ic.code as category_code,
    COUNT(ci.id) as item_count
FROM "ItemCategories" ic
LEFT JOIN "CatalogItems" ci ON ci.item_category_id = ic.id AND ci.deleted = false
WHERE ic.code ILIKE '%fabric%'
OR ic.code ILIKE '%FABRIC%'
GROUP BY ic.code
UNION ALL
SELECT 
    'motor' as expected_role,
    ic.code as category_code,
    COUNT(ci.id) as item_count
FROM "ItemCategories" ic
LEFT JOIN "CatalogItems" ci ON ci.item_category_id = ic.id AND ci.deleted = false
WHERE ic.code ILIKE '%motor%'
OR ic.code ILIKE '%MOTOR%'
OR ic.code ILIKE '%drive%'
OR ic.code ILIKE '%DRIVE%'
GROUP BY ic.code
UNION ALL
SELECT 
    'cassette' as expected_role,
    ic.code as category_code,
    COUNT(ci.id) as item_count
FROM "ItemCategories" ic
LEFT JOIN "CatalogItems" ci ON ci.item_category_id = ic.id AND ci.deleted = false
WHERE ic.code ILIKE '%cassette%'
OR ic.code ILIKE '%CASSETTE%'
GROUP BY ic.code
UNION ALL
SELECT 
    'side_channel' as expected_role,
    ic.code as category_code,
    COUNT(ci.id) as item_count
FROM "ItemCategories" ic
LEFT JOIN "CatalogItems" ci ON ci.item_category_id = ic.id AND ci.deleted = false
WHERE ic.code ILIKE '%side%'
OR ic.code ILIKE '%SIDE%'
GROUP BY ic.code
UNION ALL
SELECT 
    'bottom_channel' as expected_role,
    ic.code as category_code,
    COUNT(ci.id) as item_count
FROM "ItemCategories" ic
LEFT JOIN "CatalogItems" ci ON ci.item_category_id = ic.id AND ci.deleted = false
WHERE ic.code ILIKE '%bottom%'
OR ic.code ILIKE '%BOTTOM%'
GROUP BY ic.code
ORDER BY expected_role, category_code;

-- Query 4: Sample data - show actual CatalogItems with their ItemCategories.code for bracket role
SELECT 
    ci.id,
    ci.sku,
    ci.item_name,
    ic.code as category_code,
    ic.name as category_name
FROM "CatalogItems" ci
INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
WHERE ci.deleted = false
AND ic.deleted = false
AND (
    ic.code ILIKE '%bracket%' 
    OR ic.code = 'COMP-BRACKET'
)
LIMIT 10;

