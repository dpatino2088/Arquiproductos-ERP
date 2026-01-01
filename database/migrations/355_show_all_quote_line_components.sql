-- ====================================================
-- Migration 355: Show All QuoteLineComponents for MO-000003
-- ====================================================
-- Shows all QuoteLineComponents that should be converted to BomInstanceLines
-- ====================================================

SELECT 
    qlc.id as qlc_id,
    qlc.quote_line_id,
    qlc.component_role,
    qlc.catalog_item_id,
    qlc.qty,
    qlc.uom,
    ci.sku,
    ci.item_name,
    bi.id as bom_instance_id,
    CASE 
        WHEN bil.id IS NOT NULL THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as bom_line_status,
    bil.id as bom_instance_line_id
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
INNER JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id
INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id
INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id
INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
    AND bil.resolved_part_id = qlc.catalog_item_id
    AND COALESCE(bil.part_role, '') = COALESCE(qlc.component_role, '')
    AND bil.deleted = false
WHERE mo.manufacturing_order_no = 'MO-000003'
AND mo.deleted = false
AND qlc.deleted = false
AND qlc.source = 'configured_component'
AND bi.deleted = false
ORDER BY qlc.component_role;


