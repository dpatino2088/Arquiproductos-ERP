-- ====================================================
-- Diagnostic Query: Check Collection Mismatch between SO and MO
-- ====================================================
-- This query helps diagnose why BOM components don't match the collection in Sales Order
-- ====================================================

-- Query 1: Compare QuoteLine collection/variant with resolved fabric SKU
SELECT 
    ql.id as quote_line_id,
    ql.collection_name as ql_collection_name,
    ql.variant_name as ql_variant_name,
    ql.collection_id as ql_collection_id,
    ql.variant_id as ql_variant_id,
    bil.resolved_sku as bom_fabric_sku,
    ci.collection_name as catalog_collection_name,
    ci.variant_name as catalog_variant_name,
    CASE 
        WHEN ql.collection_name IS NOT NULL AND ci.collection_name IS NOT NULL 
             AND ql.collection_name != ci.collection_name THEN 'MISMATCH'
        WHEN ql.variant_name IS NOT NULL AND ci.variant_name IS NOT NULL 
             AND ql.variant_name != ci.variant_name THEN 'MISMATCH'
        WHEN ql.collection_name IS NOT NULL AND ci.collection_name IS NULL THEN 'MISSING_IN_CATALOG'
        WHEN ql.variant_name IS NOT NULL AND ci.variant_name IS NULL THEN 'MISSING_IN_CATALOG'
        ELSE 'OK'
    END as match_status
FROM "QuoteLines" ql
INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id 
    AND bil.part_role = 'fabric' 
    AND bil.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE ql.deleted = false
ORDER BY bi.created_at DESC
LIMIT 10;

-- Query 2: Check what fabric SKUs are available for a specific collection
-- Replace 'Screen 3001' with the actual collection_name from your QuoteLine
SELECT 
    ci.sku,
    ci.item_name,
    ci.collection_name,
    ci.variant_name,
    ic.code as category_code,
    ci.active,
    ci.deleted
FROM "CatalogItems" ci
INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
WHERE ic.code = 'FABRIC'
AND ci.deleted = false
AND ci.active = true
AND ci.collection_name = 'Screen 3001'  -- Replace with actual collection_name
ORDER BY ci.variant_name, ci.sku;

-- Query 3: Check all fabric SKUs and their collections (to see what's available)
SELECT 
    ci.collection_name,
    ci.variant_name,
    COUNT(*) as sku_count,
    STRING_AGG(ci.sku, ', ' ORDER BY ci.sku) as sample_skus
FROM "CatalogItems" ci
INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
WHERE ic.code = 'FABRIC'
AND ci.deleted = false
AND ci.active = true
GROUP BY ci.collection_name, ci.variant_name
ORDER BY ci.collection_name, ci.variant_name;


