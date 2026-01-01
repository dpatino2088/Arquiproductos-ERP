-- ====================================================
-- DIAGNOSE: Why fabric and linear_m components not copied to BOM
-- ====================================================
-- MO-000003: 36245978-4d87-4288-8a7d-b4f3acce9f58
-- ====================================================

-- Check QuoteLineComponents that should be in BOM
SELECT 
    'QuoteLineComponents' as source,
    qlc.id,
    qlc.component_role,
    qlc.source,
    qlc.deleted,
    ci.sku,
    ci.measure_basis,
    ci.item_type,
    qlc.uom,
    ql.id as quote_line_id,
    sol.id as sale_order_line_id
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id AND ci.deleted = false
WHERE mo.id = '36245978-4d87-4288-8a7d-b4f3acce9f58'  -- MO-000003
AND qlc.deleted = false
ORDER BY ci.measure_basis, qlc.component_role;

-- Check if BomInstances exist for the SaleOrderLines
SELECT 
    'BomInstances' as source,
    bi.id as bom_instance_id,
    bi.sale_order_line_id,
    sol.id as sale_order_line_id_check,
    COUNT(bil.id) as bom_lines_count
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE mo.id = '36245978-4d87-4288-8a7d-b4f3acce9f58'  -- MO-000003
AND bi.deleted = false
GROUP BY bi.id, bi.sale_order_line_id, sol.id
ORDER BY bi.sale_order_line_id;

-- Check if CatalogItems exist and are not deleted
SELECT 
    'CatalogItems Check' as source,
    ci.id,
    ci.sku,
    ci.measure_basis,
    ci.item_type,
    ci.deleted,
    qlc.id as quote_line_component_id
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SalesOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE mo.id = '36245978-4d87-4288-8a7d-b4f3acce9f58'  -- MO-000003
AND qlc.deleted = false
ORDER BY ci.measure_basis, ci.sku;






