-- ====================================================
-- Script: Verify BOM Categories
-- ====================================================
-- This script verifies that category_code has been correctly
-- assigned to all BomInstanceLines based on part_role
-- ====================================================

-- Summary by category_code
SELECT 
    'Summary by Category' as check_type,
    category_code,
    COUNT(*) as line_count,
    COUNT(DISTINCT bom_instance_id) as bom_instance_count,
    COUNT(DISTINCT resolved_part_id) as unique_parts_count
FROM "BomInstanceLines"
WHERE deleted = false
GROUP BY category_code
ORDER BY line_count DESC;

-- Detailed breakdown by part_role and category_code
SELECT 
    'Detailed Breakdown' as check_type,
    part_role,
    category_code,
    COUNT(*) as count,
    STRING_AGG(DISTINCT resolved_sku, ', ' ORDER BY resolved_sku) FILTER (WHERE resolved_sku IS NOT NULL) as sample_skus
FROM "BomInstanceLines"
WHERE deleted = false
GROUP BY part_role, category_code
ORDER BY category_code, count DESC;

-- Check for any NULL or unexpected category_code
SELECT 
    'Potential Issues' as check_type,
    CASE 
        WHEN category_code IS NULL THEN 'NULL category_code'
        WHEN category_code NOT IN ('fabric', 'tube', 'motor', 'bracket', 'cassette', 'side_channel', 'bottom_channel', 'accessory') THEN 'Unexpected category_code: ' || category_code
        ELSE 'OK'
    END as status,
    COUNT(*) as count,
    STRING_AGG(DISTINCT part_role, ', ' ORDER BY part_role) FILTER (WHERE part_role IS NOT NULL) as sample_roles
FROM "BomInstanceLines"
WHERE deleted = false
GROUP BY 
    CASE 
        WHEN category_code IS NULL THEN 'NULL category_code'
        WHEN category_code NOT IN ('fabric', 'tube', 'motor', 'bracket', 'cassette', 'side_channel', 'bottom_channel', 'accessory') THEN 'Unexpected category_code: ' || category_code
        ELSE 'OK'
    END
HAVING 
    CASE 
        WHEN category_code IS NULL THEN 'NULL category_code'
        WHEN category_code NOT IN ('fabric', 'tube', 'motor', 'bracket', 'cassette', 'side_channel', 'bottom_channel', 'accessory') THEN 'Unexpected category_code: ' || category_code
        ELSE 'OK'
    END != 'OK'
ORDER BY count DESC;

-- Show sample of each category
SELECT 
    'Sample by Category' as check_type,
    bil.category_code,
    bil.part_role,
    ci.sku,
    ci.item_name,
    bil.qty,
    bil.uom
FROM "BomInstanceLines" bil
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE bil.deleted = false
ORDER BY bil.category_code, bil.part_role, ci.sku
LIMIT 50;








