-- ====================================================
-- Migration 344: Complete Diagnosis for MO-000003
-- ====================================================
-- Shows all relevant information in one view
-- ====================================================

-- Summary
SELECT 
    'SUMMARY' as section,
    'MO-000003' as manufacturing_order_no,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol
     INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
     INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
     WHERE mo.manufacturing_order_no = 'MO-000003' AND sol.deleted = false) as sales_order_lines,
    
    (SELECT COUNT(*) FROM "QuoteLineComponents" qlc
     INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
     INNER JOIN "SalesOrders" so ON so.quote_id = ql.quote_id
     INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
     WHERE mo.manufacturing_order_no = 'MO-000003' 
     AND qlc.source = 'configured_component' 
     AND qlc.deleted = false) as quote_line_components,
    
    (SELECT COUNT(*) FROM "BomInstances" bi
     INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
     INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
     INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
     WHERE mo.manufacturing_order_no = 'MO-000003' AND bi.deleted = false) as bom_instances,
    
    (SELECT COUNT(*) FROM "BomInstanceLines" bil
     INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
     INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
     INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
     INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
     WHERE mo.manufacturing_order_no = 'MO-000003' AND bil.deleted = false) as bom_instance_lines;

-- QuoteLineComponents Details
SELECT 
    'QUOTE_LINE_COMPONENTS' as section,
    qlc.component_role,
    qlc.qty,
    qlc.uom,
    qlc.source,
    qlc.deleted,
    ci.sku,
    ci.item_name,
    CASE WHEN qlc.catalog_item_id IS NULL THEN '❌ NULL' ELSE '✅' END as catalog_item_status
FROM "QuoteLineComponents" qlc
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SalesOrders" so ON so.quote_id = ql.quote_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000003'
AND mo.deleted = false
ORDER BY qlc.component_role;


