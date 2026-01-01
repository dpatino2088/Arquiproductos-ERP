-- ====================================================
-- QUERY 4: BOM Readiness Results as Table
-- ====================================================
-- This query returns results as a table instead of RAISE NOTICE
-- Easier to view in Supabase SQL Editor
-- ====================================================

WITH product_type_analysis AS (
    SELECT 
        pt.id as product_type_id,
        pt.name as product_type_name,
        -- Count fixed components
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
        -- Count auto-select components
        COUNT(*) FILTER (WHERE bc.auto_select = true OR bc.component_item_id IS NULL) as auto_select_count,
        -- Count incomplete auto-select
        COUNT(*) FILTER (
            WHERE (bc.auto_select = true OR bc.component_item_id IS NULL)
            AND bc.component_role IS NOT NULL
            AND (bc.sku_resolution_rule IS NULL OR bc.qty_type IS NULL)
        ) as incomplete_auto_select_count
    FROM "ProductTypes" pt
    INNER JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id
    INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
    WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
        AND pt.deleted = false
        AND bt.deleted = false
        AND bt.active = true
        AND bc.deleted = false
    GROUP BY pt.id, pt.name
)
SELECT 
    product_type_name,
    fixed_component_count,
    valid_fixed_count,
    (fixed_component_count - valid_fixed_count) as invalid_fixed_count,
    auto_select_count,
    incomplete_auto_select_count,
    CASE 
        WHEN fixed_component_count > valid_fixed_count THEN 'INVALID_FIXED_COMPONENTS'
        WHEN incomplete_auto_select_count > 0 THEN 'INCOMPLETE_AUTO_SELECT'
        WHEN auto_select_count > incomplete_auto_select_count THEN 'CHECK_UNRESOLVABLE'
        ELSE 'OK'
    END as issue_type,
    CASE 
        WHEN fixed_component_count > valid_fixed_count THEN 
            format('%s fixed component(s) have missing CatalogItems, NULL UOM, or missing item_category_id', 
                fixed_component_count - valid_fixed_count)
        WHEN incomplete_auto_select_count > 0 THEN 
            format('%s auto-select component(s) are missing required fields (sku_resolution_rule or qty_type)', 
                incomplete_auto_select_count)
        ELSE 'No issues detected'
    END as issue_message
FROM product_type_analysis
ORDER BY product_type_name;

