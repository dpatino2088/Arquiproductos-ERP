-- ====================================================
-- Migration 354: Diagnose Why No BomInstanceLines Created
-- ====================================================
-- Returns diagnostic information in a table format
-- ====================================================

WITH bom_instance_info AS (
    SELECT 
        bi.id as bom_instance_id,
        bi.quote_line_id,
        bi.organization_id,
        mo.manufacturing_order_no
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
    WHERE mo.manufacturing_order_no = 'MO-000003'
    AND bi.deleted = false
    LIMIT 1
),
quote_line_components AS (
    SELECT 
        qlc.id,
        qlc.catalog_item_id,
        qlc.component_role,
        qlc.qty,
        qlc.uom,
        ci.sku,
        ci.item_name,
        bi.bom_instance_id
    FROM bom_instance_info bi
    INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = bi.quote_line_id
    INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
    WHERE qlc.deleted = false
    AND qlc.source = 'configured_component'
),
existing_bom_lines AS (
    SELECT 
        bil.id,
        bil.resolved_part_id,
        bil.part_role,
        qlc.bom_instance_id,
        qlc.catalog_item_id,
        qlc.component_role,
        qlc.sku
    FROM quote_line_components qlc
    LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = qlc.bom_instance_id
        AND bil.resolved_part_id = qlc.catalog_item_id
        AND COALESCE(bil.part_role, '') = COALESCE(qlc.component_role, '')
        AND bil.deleted = false
)
SELECT 
    'BomInstance Info' as check_type,
    bom_instance_id::text as value_1,
    quote_line_id::text as value_2,
    manufacturing_order_no as value_3,
    NULL::text as value_4
FROM bom_instance_info
UNION ALL
SELECT 
    'QuoteLineComponents Count' as check_type,
    COUNT(*)::text as value_1,
    NULL::text as value_2,
    NULL::text as value_3,
    NULL::text as value_4
FROM quote_line_components
UNION ALL
SELECT 
    'Existing BomInstanceLines Count' as check_type,
    COUNT(*)::text as value_1,
    NULL::text as value_2,
    NULL::text as value_3,
    NULL::text as value_4
FROM existing_bom_lines
WHERE id IS NOT NULL
UNION ALL
SELECT 
    'Components NOT in BomInstanceLines' as check_type,
    component_role as value_1,
    sku as value_2,
    catalog_item_id::text as value_3,
    NULL::text as value_4
FROM existing_bom_lines
WHERE id IS NULL
ORDER BY check_type;

