-- ====================================================
-- QUERY 9: Detailed Fixed Component Check
-- ====================================================
-- This shows ALL fixed components with detailed status
-- ====================================================

SELECT 
    pt.name as product_type,
    bc.id as component_id,
    bc.component_item_id,
    bc.component_role,
    ci.id as catalog_item_id,
    ci.sku,
    ci.item_name,
    ci.organization_id as catalog_item_org_id,
    pt.organization_id as product_type_org_id,
    ci.deleted as catalog_item_deleted,
    ci.active as catalog_item_active,
    ci.uom,
    ci.item_category_id,
    ic.code as category_code,
    -- Check each condition separately
    CASE 
        WHEN ci.id IS NULL THEN 'CATALOG_ITEM_MISSING'
        WHEN ci.deleted = true THEN 'CATALOG_ITEM_DELETED'
        WHEN ci.active = false THEN 'CATALOG_ITEM_INACTIVE'
        WHEN ci.uom IS NULL OR TRIM(ci.uom) = '' THEN 'UOM_NULL_OR_EMPTY'
        WHEN ci.item_category_id IS NULL THEN 'ITEM_CATEGORY_ID_MISSING'
        WHEN ic.code IS NULL THEN 'CATEGORY_CODE_MISSING'
        WHEN ci.organization_id != pt.organization_id THEN 'ORG_ID_MISMATCH'
        ELSE 'OK'
    END as issue_type
FROM "ProductTypes" pt
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
LEFT JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND pt.deleted = false
    AND bt.deleted = false
    AND bt.active = true
    AND bc.deleted = false
    AND bc.component_item_id IS NOT NULL
ORDER BY pt.name, bc.sequence_order;

