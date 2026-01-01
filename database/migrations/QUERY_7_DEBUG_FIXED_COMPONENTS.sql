-- ====================================================
-- QUERY 7: Debug Fixed Components (EXACT bom_readiness_report logic)
-- ====================================================
-- This replicates EXACTLY the logic used by bom_readiness_report
-- ====================================================

SELECT 
    pt.name as product_type,
    -- Count all fixed components
    COUNT(*) FILTER (WHERE bc.component_item_id IS NOT NULL) as fixed_component_count,
    -- Count valid fixed components (EXACT logic from bom_readiness_report)
    COUNT(*) FILTER (
        WHERE bc.component_item_id IS NOT NULL
        AND EXISTS (
            SELECT 1 
            FROM "CatalogItems" ci 
            WHERE ci.id = bc.component_item_id 
            AND ci.deleted = false 
            AND ci.active = true
            AND ci.uom IS NOT NULL 
            AND TRIM(ci.uom) <> ''
            AND ci.item_category_id IS NOT NULL
        )
    ) as valid_fixed_count,
    -- Calculate invalid count
    COUNT(*) FILTER (WHERE bc.component_item_id IS NOT NULL) - 
    COUNT(*) FILTER (
        WHERE bc.component_item_id IS NOT NULL
        AND EXISTS (
            SELECT 1 
            FROM "CatalogItems" ci 
            WHERE ci.id = bc.component_item_id 
            AND ci.deleted = false 
            AND ci.active = true
            AND ci.uom IS NOT NULL 
            AND TRIM(ci.uom) <> ''
            AND ci.item_category_id IS NOT NULL
        )
    ) as invalid_fixed_count,
    -- Show each component and why it's invalid
    ARRAY_AGG(
        jsonb_build_object(
            'component_id', bc.id,
            'component_item_id', bc.component_item_id,
            'catalog_item_exists', EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false),
            'catalog_item_active', EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false AND ci.active = true),
            'has_uom', EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false AND ci.active = true AND ci.uom IS NOT NULL AND TRIM(ci.uom) <> ''),
            'has_item_category_id', EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false AND ci.active = true AND ci.item_category_id IS NOT NULL)
        )
    ) FILTER (
        WHERE bc.component_item_id IS NOT NULL
        AND NOT EXISTS (
            SELECT 1 
            FROM "CatalogItems" ci 
            WHERE ci.id = bc.component_item_id 
            AND ci.deleted = false 
            AND ci.active = true
            AND ci.uom IS NOT NULL 
            AND TRIM(ci.uom) <> ''
            AND ci.item_category_id IS NOT NULL
        )
    ) as invalid_components
FROM "ProductTypes" pt
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND pt.deleted = false
    AND bt.deleted = false
    AND bt.active = true
    AND bc.deleted = false
GROUP BY pt.id, pt.name
HAVING COUNT(*) FILTER (WHERE bc.component_item_id IS NOT NULL) - 
    COUNT(*) FILTER (
        WHERE bc.component_item_id IS NOT NULL
        AND EXISTS (
            SELECT 1 
            FROM "CatalogItems" ci 
            WHERE ci.id = bc.component_item_id 
            AND ci.deleted = false 
            AND ci.active = true
            AND ci.uom IS NOT NULL 
            AND TRIM(ci.uom) <> ''
            AND ci.item_category_id IS NOT NULL
        )
    ) > 0
ORDER BY pt.name;

