-- ====================================================
-- Migration 388: Exact BOM Readiness Diagnosis
-- ====================================================
-- These queries replicate EXACTLY the logic used by bom_readiness_report
-- to identify why issues are being reported
-- ====================================================

-- ====================================================
-- Query 1: Replicate INVALID_FIXED_COMPONENTS logic
-- ====================================================
-- This query uses the EXACT same logic as bom_readiness_report
-- ====================================================
SELECT 
    pt.id as product_type_id,
    pt.name as product_type_name,
    bt.id as template_id,
    bt.name as template_name,
    -- Count all fixed components
    COUNT(*) FILTER (WHERE bc.component_item_id IS NOT NULL) as fixed_component_count,
    -- Count valid fixed components (exact logic from bom_readiness_report)
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
    -- Show the actual invalid components
    ARRAY_AGG(
        jsonb_build_object(
            'component_id', bc.id,
            'component_role', bc.component_role,
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
WHERE pt.deleted = false
    AND bt.deleted = false
    AND bt.active = true
    AND bc.deleted = false
GROUP BY pt.id, pt.name, bt.id, bt.name
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
ORDER BY pt.name, bt.name;

-- ====================================================
-- Query 2: Replicate UNRESOLVABLE_AUTO_SELECT logic
-- ====================================================
-- This query uses the EXACT same logic as bom_readiness_report
-- ====================================================
WITH auto_select_components AS (
    SELECT 
        pt.id as product_type_id,
        pt.name as product_type_name,
        pt.organization_id,
        bc.id as component_id,
        bc.component_role,
        bc.component_sub_role,
        bc.sku_resolution_rule,
        bc.qty_type,
        bt.id as template_id,
        bt.name as template_name
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
),
resolvable_check AS (
    SELECT 
        asc_comp.*,
        -- Try to get category codes
        CASE 
            WHEN EXISTS (
                SELECT 1
                FROM "CatalogItems" ci
                INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                WHERE ic.code = ANY(public.get_item_category_codes_from_role(asc_comp.component_role, asc_comp.component_sub_role))
                AND ci.organization_id = asc_comp.organization_id
                AND ci.deleted = false
                AND ci.active = true
                AND ci.uom IS NOT NULL
                AND TRIM(ci.uom) <> ''
            ) THEN true
            ELSE false
        END as is_resolvable
    FROM auto_select_components asc_comp
)
SELECT 
    rc.product_type_id,
    rc.product_type_name,
    rc.template_id,
    rc.template_name,
    COUNT(*) as total_auto_select,
    COUNT(*) FILTER (WHERE rc.is_resolvable = true) as resolvable_count,
    COUNT(*) FILTER (WHERE rc.is_resolvable = false) as unresolvable_count,
    ARRAY_AGG(
        jsonb_build_object(
            'component_id', rc.component_id,
            'component_role', rc.component_role,
            'component_sub_role', rc.component_sub_role,
            'mapped_categories', (
                SELECT public.get_item_category_codes_from_role(rc.component_role, rc.component_sub_role)
            ),
            'available_catalog_items', (
                SELECT COUNT(*)
                FROM "CatalogItems" ci
                INNER JOIN "ItemCategories" ic ON ic.id = ci.item_category_id
                WHERE ic.code = ANY(public.get_item_category_codes_from_role(rc.component_role, rc.component_sub_role))
                AND ci.organization_id = rc.organization_id
                AND ci.deleted = false
                AND ci.active = true
                AND ci.uom IS NOT NULL
                AND TRIM(ci.uom) <> ''
            )
        )
    ) FILTER (WHERE rc.is_resolvable = false) as unresolvable_components
FROM resolvable_check rc
GROUP BY rc.product_type_id, rc.product_type_name, rc.template_id, rc.template_name
HAVING COUNT(*) FILTER (WHERE rc.is_resolvable = false) > 0
ORDER BY rc.product_type_name, rc.template_name;

-- ====================================================
-- Query 3: Quick summary by ProductType
-- ====================================================
SELECT 
    pt.id,
    pt.name,
    COUNT(DISTINCT bt.id) as template_count,
    COUNT(DISTINCT bc.id) as total_components,
    COUNT(DISTINCT bc.id) FILTER (WHERE bc.component_item_id IS NOT NULL) as fixed_components,
    COUNT(DISTINCT bc.id) FILTER (WHERE bc.auto_select = true OR bc.component_item_id IS NULL) as auto_select_components,
    -- Invalid fixed (exact logic)
    COUNT(DISTINCT bc.id) FILTER (WHERE bc.component_item_id IS NOT NULL) - 
    COUNT(DISTINCT bc.id) FILTER (
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
    ) as invalid_fixed_count
FROM "ProductTypes" pt
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id AND bt.deleted = false AND bt.active = true
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE pt.deleted = false
GROUP BY pt.id, pt.name
ORDER BY pt.name;

