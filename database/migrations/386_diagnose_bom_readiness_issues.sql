-- ====================================================
-- Migration 386: Diagnostic Queries for BOM Readiness Issues
-- ====================================================
-- These queries help diagnose the specific issues reported by bom_readiness_report:
-- 1. INVALID_FIXED_COMPONENTS: Components with missing CatalogItems, NULL UOM, or missing item_category_id
-- 2. UNRESOLVABLE_AUTO_SELECT: Auto-select components that cannot be resolved
-- ====================================================
-- Run these queries manually to diagnose issues
-- ====================================================

-- ====================================================
-- Query 1: Find Fixed Components with Issues
-- ====================================================
-- This query identifies fixed components that have problems:
-- - Missing CatalogItems (component_item_id doesn't exist)
-- - CatalogItems with NULL or empty UOM
-- - CatalogItems with missing item_category_id
-- ====================================================
SELECT 
    bc.id as component_id,
    bc.component_role,
    bc.component_item_id,
    bt.name as template_name,
    pt.name as product_type_name,
    ci.id as catalog_item_exists,
    ci.sku,
    ci.item_name,
    ci.uom as catalog_uom,
    ci.item_category_id,
    ic.code as category_code,
    CASE 
        WHEN bc.component_item_id IS NULL THEN 'NO_COMPONENT_ITEM_ID'
        WHEN ci.id IS NULL THEN 'CATALOG_ITEM_MISSING'
        WHEN ci.uom IS NULL OR TRIM(ci.uom) = '' THEN 'UOM_NULL_OR_EMPTY'
        WHEN ci.item_category_id IS NULL THEN 'ITEM_CATEGORY_ID_MISSING'
        WHEN ic.code IS NULL THEN 'CATEGORY_CODE_MISSING'
        ELSE 'OK'
    END as issue_type
FROM "BOMComponents" bc
INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
INNER JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
LEFT JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
WHERE bc.component_item_id IS NOT NULL  -- Fixed components only
    AND bc.deleted = false
    AND bt.deleted = false
    AND bt.active = true
    AND (
        ci.id IS NULL  -- CatalogItem doesn't exist
        OR ci.uom IS NULL 
        OR TRIM(ci.uom) = ''
        OR ci.item_category_id IS NULL
    )
ORDER BY pt.name, bt.name, bc.sequence_order;

-- ====================================================
-- Query 2: Find Auto-Select Components That Cannot Be Resolved
-- ====================================================
-- This query identifies auto-select components that cannot be resolved because:
-- - No CatalogItems exist in the mapped categories
-- - CatalogItems exist but don't have UOM
-- ====================================================
SELECT 
    bc.id as component_id,
    bc.component_role,
    bc.component_sub_role,
    bc.sku_resolution_rule,
    bc.qty_type,
    bt.name as template_name,
    pt.name as product_type_name,
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
    ) as available_catalog_items_count
FROM "BOMComponents" bc
INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
INNER JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
WHERE (bc.auto_select = true OR bc.component_item_id IS NULL)  -- Auto-select components
    AND bc.component_role IS NOT NULL
    AND bc.sku_resolution_rule IS NOT NULL
    AND bc.qty_type IS NOT NULL
    AND bc.deleted = false
    AND bt.deleted = false
    AND bt.active = true
    AND (
        -- Check if there are any CatalogItems in the mapped categories
        NOT EXISTS (
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
    )
ORDER BY pt.name, bt.name, bc.sequence_order;

-- ====================================================
-- Query 3: Summary of Issues by ProductType
-- ====================================================
-- This query provides a summary of issues per ProductType
-- ====================================================
SELECT 
    pt.id as product_type_id,
    pt.name as product_type_name,
    COUNT(DISTINCT bt.id) as template_count,
    COUNT(DISTINCT bc.id) as total_components,
    COUNT(DISTINCT bc.id) FILTER (WHERE bc.component_item_id IS NOT NULL) as fixed_components,
    COUNT(DISTINCT bc.id) FILTER (WHERE bc.auto_select = true OR bc.component_item_id IS NULL) as auto_select_components,
    COUNT(DISTINCT bc.id) FILTER (
        WHERE bc.component_item_id IS NOT NULL
        AND (
            NOT EXISTS (SELECT 1 FROM "CatalogItems" ci WHERE ci.id = bc.component_item_id AND ci.deleted = false)
            OR EXISTS (
                SELECT 1 FROM "CatalogItems" ci 
                WHERE ci.id = bc.component_item_id 
                AND (ci.uom IS NULL OR TRIM(ci.uom) = '' OR ci.item_category_id IS NULL)
            )
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

-- ====================================================
-- Query 4: Find CatalogItems That Should Be Available for Auto-Select
-- ====================================================
-- This query shows what CatalogItems are available for each role/category
-- ====================================================
SELECT 
    ic.code as category_code,
    ic.name as category_name,
    COUNT(DISTINCT ci.id) as catalog_item_count,
    COUNT(DISTINCT ci.id) FILTER (WHERE ci.uom IS NOT NULL AND TRIM(ci.uom) <> '') as with_uom_count,
    COUNT(DISTINCT ci.id) FILTER (WHERE ci.uom IS NULL OR TRIM(ci.uom) = '') as without_uom_count,
    ARRAY_AGG(DISTINCT ci.uom) FILTER (WHERE ci.uom IS NOT NULL) as available_uoms
FROM "ItemCategories" ic
LEFT JOIN "CatalogItems" ci ON ci.item_category_id = ic.id AND ci.deleted = false AND ci.active = true
WHERE ic.deleted = false
GROUP BY ic.id, ic.code, ic.name
HAVING COUNT(DISTINCT ci.id) > 0
ORDER BY ic.code;

