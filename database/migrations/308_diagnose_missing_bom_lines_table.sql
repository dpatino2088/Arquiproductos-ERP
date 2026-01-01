-- ====================================================
-- Migration 308: Diagnose missing BomInstanceLines (returns table)
-- ====================================================

-- Returns diagnostic information as a table for easy viewing
WITH mo_info AS (
    SELECT 
        mo.id as mo_id,
        mo.manufacturing_order_no,
        mo.sale_order_id,
        mo.organization_id
    FROM "ManufacturingOrders" mo
    WHERE mo.manufacturing_order_no = 'MO-000002'
    AND mo.deleted = false
    LIMIT 1
),
bom_instances_info AS (
    SELECT 
        bi.id as bom_instance_id,
        bi.quote_line_id,
        bi.sale_order_line_id
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    JOIN mo_info ON mo_info.sale_order_id = sol.sale_order_id
    WHERE bi.deleted = false
    AND sol.deleted = false
),
qlc_counts AS (
    SELECT 
        bi.bom_instance_id,
        bi.quote_line_id,
        COUNT(*) FILTER (WHERE qlc.deleted = false) as total_qlc,
        COUNT(*) FILTER (WHERE qlc.deleted = false AND qlc.source = 'configured_component') as qlc_configured,
        COUNT(*) FILTER (WHERE qlc.deleted = false AND qlc.source != 'configured_component') as qlc_other_source,
        STRING_AGG(DISTINCT qlc.source, ', ') FILTER (WHERE qlc.deleted = false) as all_sources
    FROM bom_instances_info bi
    LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = bi.quote_line_id
    GROUP BY bi.bom_instance_id, bi.quote_line_id
),
bil_counts AS (
    SELECT 
        bi.bom_instance_id,
        COUNT(*) FILTER (WHERE bil.deleted = false) as existing_bil_count
    FROM bom_instances_info bi
    LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.bom_instance_id
    GROUP BY bi.bom_instance_id
)
SELECT 
    bi.bom_instance_id::text as bom_instance_id,
    bi.quote_line_id::text as quote_line_id,
    COALESCE(qlc.total_qlc, 0) as total_quote_line_components,
    COALESCE(qlc.qlc_configured, 0) as qlc_with_source_configured,
    COALESCE(qlc.qlc_other_source, 0) as qlc_with_other_source,
    COALESCE(qlc.all_sources, 'NONE') as all_sources_found,
    COALESCE(bil.existing_bil_count, 0) as existing_bom_instance_lines,
    CASE 
        WHEN COALESCE(qlc.qlc_configured, 0) = 0 THEN '❌ NO QuoteLineComponents with source=configured_component'
        WHEN COALESCE(bil.existing_bil_count, 0) > 0 THEN '⚠️ BomInstanceLines already exist'
        ELSE '✅ Ready to create BomInstanceLines'
    END as diagnosis
FROM bom_instances_info bi
LEFT JOIN qlc_counts qlc ON qlc.bom_instance_id = bi.bom_instance_id
LEFT JOIN bil_counts bil ON bil.bom_instance_id = bi.bom_instance_id
ORDER BY bi.bom_instance_id;

-- Also show sample QuoteLineComponents
WITH mo_info AS (
    SELECT 
        mo.id as mo_id,
        mo.manufacturing_order_no,
        mo.sale_order_id,
        mo.organization_id
    FROM "ManufacturingOrders" mo
    WHERE mo.manufacturing_order_no = 'MO-000002'
    AND mo.deleted = false
    LIMIT 1
),
bom_instances_info AS (
    SELECT 
        bi.id as bom_instance_id,
        bi.quote_line_id,
        bi.sale_order_line_id
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    JOIN mo_info ON mo_info.sale_order_id = sol.sale_order_id
    WHERE bi.deleted = false
    AND sol.deleted = false
)
SELECT 
    'Sample QuoteLineComponents' as info_type,
    bi.bom_instance_id::text as bom_instance_id,
    qlc.id::text as qlc_id,
    qlc.component_role,
    qlc.source,
    qlc.catalog_item_id::text as catalog_item_id,
    ci.sku,
    qlc.qty,
    qlc.uom,
    qlc.deleted
FROM bom_instances_info bi
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = bi.quote_line_id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.deleted = false
ORDER BY bi.bom_instance_id, qlc.component_role
LIMIT 20;

