-- ====================================================
-- Migration 348: Debug QuoteLine ID Matching
-- ====================================================
-- Check if quote_line_id in SalesOrderLines matches QuoteLineComponents
-- ====================================================

-- Check the relationship
SELECT 
    'RELATIONSHIP_CHECK' as check_type,
    sol.id as sale_order_line_id,
    sol.quote_line_id as sol_quote_line_id,
    (SELECT COUNT(*) FROM "QuoteLineComponents" qlc 
     WHERE qlc.quote_line_id = sol.quote_line_id 
     AND qlc.deleted = false 
     AND qlc.source = 'configured_component') as qlc_count_for_this_quote_line,
    (SELECT COUNT(*) FROM "QuoteLineComponents" qlc 
     INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
     INNER JOIN "SalesOrders" so2 ON so2.quote_id = ql.quote_id
     WHERE so2.id = sol.sale_order_id
     AND qlc.deleted = false 
     AND qlc.source = 'configured_component') as qlc_count_for_entire_quote
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000003'
AND sol.deleted = false
AND mo.deleted = false;

-- Show all QuoteLineComponents for the Quote (not just the specific QuoteLine)
SELECT 
    'ALL_QLC_FOR_QUOTE' as check_type,
    qlc.quote_line_id,
    qlc.component_role,
    qlc.catalog_item_id,
    ci.sku,
    qlc.qty,
    qlc.uom,
    qlc.source,
    qlc.deleted
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
INNER JOIN "SalesOrders" so ON so.quote_id = ql.quote_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000003'
AND mo.deleted = false
ORDER BY qlc.quote_line_id, qlc.component_role;


