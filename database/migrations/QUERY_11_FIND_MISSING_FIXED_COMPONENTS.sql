-- ====================================================
-- QUERY 11: Find Missing Fixed Components
-- ====================================================
-- This finds fixed components that might not be in Query 9 results
-- ====================================================

SELECT 
    pt.name as product_type,
    bc.id as component_id,
    bc.component_item_id,
    bc.component_role,
    -- Check if CatalogItem exists
    EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id) as catalog_item_exists,
    -- Check if CatalogItem is deleted
    EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = true) as catalog_item_deleted,
    -- Check if CatalogItem is inactive
    EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false AND ci.active = false) as catalog_item_inactive,
    -- Check if CatalogItem has UOM
    EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false AND ci.active = true AND ci.uom IS NOT NULL AND TRIM(ci.uom) <> '') as has_uom,
    -- Check if CatalogItem has item_category_id
    EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false AND ci.active = true AND ci.item_category_id IS NOT NULL) as has_item_category_id,
    -- Get CatalogItem details if exists
    ci.sku,
    ci.item_name,
    ci.organization_id as catalog_item_org_id,
    pt.organization_id as product_type_org_id,
    ci.uom,
    ci.item_category_id
FROM "ProductTypes" pt
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND pt.deleted = false
    AND bt.deleted = false
    AND bt.active = true
    AND bc.deleted = false
    AND bc.component_item_id IS NOT NULL
    -- Find components that DON'T pass the validation
    AND NOT EXISTS (
        SELECT 1 
        FROM "CatalogItems" ci2 
        WHERE ci2.id = bc.component_item_id 
        AND ci2.deleted = false 
        AND ci2.active = true
        AND ci2.uom IS NOT NULL 
        AND TRIM(ci2.uom) <> ''
        AND ci2.item_category_id IS NOT NULL
    )
ORDER BY pt.name, bc.sequence_order;

