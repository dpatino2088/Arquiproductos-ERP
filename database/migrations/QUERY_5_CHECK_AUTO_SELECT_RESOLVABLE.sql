-- ====================================================
-- QUERY 5: Check Auto-Select Resolvability
-- ====================================================
-- This query checks if auto-select components can be resolved
-- ====================================================

SELECT 
    pt.name as product_type,
    bc.id as component_id,
    bc.component_role,
    bc.component_sub_role,
    bc.sku_resolution_rule,
    bc.qty_type,
    public.get_item_category_codes_from_role(bc.component_role, bc.component_sub_role) as mapped_categories,
    (
        SELECT COUNT(*)
        FROM "CatalogItems" ci
        INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
        WHERE ic.code = ANY(public.get_item_category_codes_from_role(bc.component_role, bc.component_sub_role))
        AND ci.organization_id = pt.organization_id
        AND ci.deleted = false
        AND ci.active = true
        AND ci.uom IS NOT NULL
        AND TRIM(ci.uom) <> ''
    ) as available_catalog_items,
    CASE 
        WHEN (
            SELECT COUNT(*)
            FROM "CatalogItems" ci
            INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
            WHERE ic.code = ANY(public.get_item_category_codes_from_role(bc.component_role, bc.component_sub_role))
            AND ci.organization_id = pt.organization_id
            AND ci.deleted = false
            AND ci.active = true
            AND ci.uom IS NOT NULL
            AND TRIM(ci.uom) <> ''
        ) > 0 THEN 'RESOLVABLE'
        ELSE 'UNRESOLVABLE'
    END as resolvability_status
FROM "ProductTypes" pt
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND pt.deleted = false
    AND bt.deleted = false
    AND bt.active = true
    AND bc.deleted = false
    AND (bc.auto_select = true OR bc.component_item_id IS NULL)
    AND bc.component_role IS NOT NULL
    AND bc.sku_resolution_rule IS NOT NULL
    AND bc.qty_type IS NOT NULL
ORDER BY pt.name, bc.sequence_order;

