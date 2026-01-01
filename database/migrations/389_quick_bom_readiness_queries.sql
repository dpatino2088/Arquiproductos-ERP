-- ====================================================
-- Migration 389: Quick BOM Readiness Diagnostic Queries
-- ====================================================
-- Simplified queries to quickly identify BOM readiness issues
-- These are easier to run and understand than the full diagnostic queries
-- ====================================================

-- ====================================================
-- Query 1: Quick Check - Invalid Fixed Components
-- ====================================================
-- Shows which fixed components have problems and why
-- ====================================================
SELECT 
    pt.name as product_type,
    bt.name as template_name,
    bc.id as component_id,
    bc.component_role,
    bc.component_item_id,
    CASE 
        WHEN NOT EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false) 
            THEN 'CATALOG_ITEM_MISSING'
        WHEN NOT EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false AND ci.active = true) 
            THEN 'CATALOG_ITEM_INACTIVE'
        WHEN EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND (ci.uom IS NULL OR TRIM(ci.uom) = '')) 
            THEN 'UOM_NULL_OR_EMPTY'
        WHEN EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.item_category_id IS NULL) 
            THEN 'ITEM_CATEGORY_ID_MISSING'
        ELSE 'OK'
    END as issue_type,
    ci.sku,
    ci.item_name,
    ci.uom,
    ci.active as catalog_item_active,
    ic.code as category_code
FROM "ProductTypes" pt
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
LEFT JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
WHERE pt.deleted = false
    AND bt.deleted = false
    AND bt.active = true
    AND bc.deleted = false
    AND bc.component_item_id IS NOT NULL
    AND (
        NOT EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false)
        OR NOT EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false AND ci.active = true)
        OR EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND (ci.uom IS NULL OR TRIM(ci.uom) = ''))
        OR EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.item_category_id IS NULL)
    )
ORDER BY pt.name, bt.name, bc.sequence_order;

-- ====================================================
-- Query 2: Quick Check - Unresolvable Auto-Select Components
-- ====================================================
-- Shows which auto-select components cannot be resolved
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

-- ====================================================
-- Query 3: Summary by ProductType (Simplified)
-- ====================================================
SELECT 
    pt.name as product_type,
    COUNT(DISTINCT bt.id) as template_count,
    COUNT(DISTINCT bc.id) as total_components,
    COUNT(DISTINCT bc.id) FILTER (WHERE bc.component_item_id IS NOT NULL) as fixed_components,
    COUNT(DISTINCT bc.id) FILTER (WHERE bc.auto_select = true OR bc.component_item_id IS NULL) as auto_select_components,
    COUNT(DISTINCT bc.id) FILTER (
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
    ) as invalid_fixed_count,
    COUNT(DISTINCT bc.id) FILTER (
        WHERE (bc.auto_select = true OR bc.component_item_id IS NULL)
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
    ) as unresolvable_auto_select_count
FROM "ProductTypes" pt
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id AND bt.deleted = false AND bt.active = true
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE pt.deleted = false
GROUP BY pt.id, pt.name
ORDER BY pt.name;

