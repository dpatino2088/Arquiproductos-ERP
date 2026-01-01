-- ====================================================
-- Migration 309: Simple check for QuoteLineComponents
-- ====================================================

-- Check if QuoteLineComponents exist for the QuoteLines in MO-000002
SELECT 
    bi.id::text as bom_instance_id,
    bi.quote_line_id::text as quote_line_id,
    (SELECT COUNT(*) FROM "QuoteLineComponents" qlc 
     WHERE qlc.quote_line_id = bi.quote_line_id 
     AND qlc.deleted = false) as total_qlc,
    (SELECT COUNT(*) FROM "QuoteLineComponents" qlc 
     WHERE qlc.quote_line_id = bi.quote_line_id 
     AND qlc.deleted = false 
     AND qlc.source = 'configured_component') as qlc_configured,
    (SELECT STRING_AGG(DISTINCT qlc.source, ', ') 
     FROM "QuoteLineComponents" qlc 
     WHERE qlc.quote_line_id = bi.quote_line_id 
     AND qlc.deleted = false) as all_sources
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bi.deleted = false
AND sol.deleted = false;

-- Show actual QuoteLineComponents
SELECT 
    bi.id::text as bom_instance_id,
    qlc.id::text as qlc_id,
    qlc.component_role,
    qlc.source,
    ci.sku,
    qlc.qty,
    qlc.uom,
    qlc.deleted
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = bi.quote_line_id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND bi.deleted = false
AND sol.deleted = false
AND qlc.deleted = false
ORDER BY bi.id, qlc.component_role;


