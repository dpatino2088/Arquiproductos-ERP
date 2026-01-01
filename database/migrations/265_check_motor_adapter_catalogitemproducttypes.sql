-- ====================================================
-- Migration 265: Check Motor Adapter in CatalogItemProductTypes
-- ====================================================
-- Diagnostic query to check if motor_adapter CatalogItems exist
-- and are linked to Roller Shade product_type_id
-- ====================================================

-- Get Roller Shade product_type_id
WITH roller_shade_type AS (
    SELECT id as product_type_id
    FROM "ProductTypes"
    WHERE code = 'ROLLER' OR name ILIKE '%roller%shade%'
    AND deleted = false
    LIMIT 1
)
-- Check motor_adapter CatalogItems
SELECT 
    'Motor Adapter CatalogItems for Roller Shade' as check_name,
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
    AND (ci.sku ILIKE '%MOTOR%ADAPTER%' OR ci.item_name ILIKE '%MOTOR%ADAPTER%' OR ci.sku ILIKE '%ADAPTER%' OR ci.item_name ILIKE '%ADAPTER%')
ORDER BY 
    CASE WHEN ci.sku ILIKE '%ADAPTER%' THEN 0 ELSE 1 END,
    ci.created_at DESC;

-- Also check what product types are linked to motor adapter items
SELECT 
    'Product Types for Motor Adapter Items' as check_name,
    ci.id,
    ci.sku,
    ci.item_name,
    cipt.product_type_id,
    pt.name as product_type_name,
    pt.code as product_type_code,
    cipt.is_primary
FROM "CatalogItems" ci
LEFT JOIN "CatalogItemProductTypes" cipt ON cipt.catalog_item_id = ci.id
LEFT JOIN "ProductTypes" pt ON pt.id = cipt.product_type_id
WHERE ci.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND ci.deleted = false
    AND (ci.sku ILIKE '%MOTOR%ADAPTER%' OR ci.item_name ILIKE '%MOTOR%ADAPTER%' OR ci.sku ILIKE '%ADAPTER%' OR ci.item_name ILIKE '%ADAPTER%')
ORDER BY ci.sku, cipt.product_type_id;


