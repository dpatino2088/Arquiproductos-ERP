-- ====================================================
-- Migration 266: Check Operating System Drive for Roller Shade
-- ====================================================
-- Diagnostic query to check what operating_system_drive CatalogItems
-- are linked to Roller Shade product_type_id
-- ====================================================

-- Get Roller Shade product_type_id
WITH roller_shade_type AS (
    SELECT id as product_type_id
    FROM "ProductTypes"
    WHERE code = 'ROLLER' OR name ILIKE '%roller%shade%'
    AND deleted = false
    LIMIT 1
)
-- Check operating_system_drive CatalogItems for Roller Shade
SELECT 
    'Operating System Drive for Roller Shade' as check_name,
    ci.id,
    ci.sku,
    ci.item_name,
    cipt.product_type_id,
    pt.name as product_type_name,
    cipt.is_primary
FROM "CatalogItems" ci
LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
LEFT JOIN "ProductTypes" pt ON pt.id = cipt.product_type_id
CROSS JOIN roller_shade_type rst
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND ci.deleted = false
    AND (ci.sku ILIKE '%DRIVE%' OR ci.sku ILIKE '%OPERATING%SYSTEM%' OR ci.sku ILIKE '%BELT%' 
         OR ci.item_name ILIKE '%DRIVE%' OR ci.item_name ILIKE '%BELT%')
    AND cipt.product_type_id = rst.product_type_id
ORDER BY 
    CASE WHEN ci.sku ILIKE '%DRIVE%' THEN 0 WHEN ci.sku ILIKE '%BELT%' THEN 1 ELSE 2 END,
    ci.created_at DESC;


