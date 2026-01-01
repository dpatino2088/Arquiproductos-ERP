-- ====================================================
-- QUERY 2: Find Unresolvable Auto-Select Components
-- ====================================================
-- Copy and paste this entire query into Supabase SQL Editor
-- ====================================================

SELECT 
    pt.name as product_type,
    bt.name as template_name,
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
    ) as available_catalog_items
FROM "ProductTypes" pt
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE pt.deleted = false
    AND bt.deleted = false
    AND bt.active = true
    AND bc.deleted = false
    AND (bc.auto_select = true OR bc.component_item_id IS NULL)
    AND bc.component_role IS NOT NULL
    AND bc.sku_resolution_rule IS NOT NULL
    AND bc.qty_type IS NOT NULL
    AND NOT EXISTS (
        SELECT 1
        FROM "CatalogItems" ci
        INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
        WHERE ic.code = ANY(public.get_item_category_codes_from_role(bc.component_role, bc.component_sub_role))
        AND ci.organization_id = pt.organization_id
        AND ci.deleted = false
        AND ci.active = true
        AND ci.uom IS NOT NULL
        AND TRIM(ci.uom) <> ''
    )
ORDER BY pt.name, bt.name, bc.sequence_order;

