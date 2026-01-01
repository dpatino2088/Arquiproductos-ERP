-- ====================================================
-- QUERY 10: Count ALL Components (Fixed and Auto-Select)
-- ====================================================
-- This shows the total count of components to verify the discrepancy
-- ====================================================

SELECT 
    pt.name as product_type,
    COUNT(*) as total_components,
    COUNT(*) FILTER (WHERE bc.component_item_id IS NOT NULL) as fixed_components,
    COUNT(*) FILTER (WHERE bc.auto_select = true OR bc.component_item_id IS NULL) as auto_select_components,
    -- Show fixed components with component_item_id
    ARRAY_AGG(bc.id) FILTER (WHERE bc.component_item_id IS NOT NULL) as fixed_component_ids,
    -- Show auto-select components
    ARRAY_AGG(bc.id) FILTER (WHERE bc.auto_select = true OR bc.component_item_id IS NULL) as auto_select_component_ids
FROM "ProductTypes" pt
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = pt.id
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE pt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'::uuid
    AND pt.deleted = false
    AND bt.deleted = false
    AND bt.active = true
    AND bc.deleted = false
GROUP BY pt.id, pt.name
ORDER BY pt.name;

