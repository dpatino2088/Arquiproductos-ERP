-- ====================================================
-- Check QuoteLineComponents for SO-090151
-- ====================================================
-- This is critical - BomInstanceLines are created from QuoteLineComponents
-- ====================================================

-- 1. Get Quote ID from SalesOrder
SELECT 
    so.id as sale_order_id,
    so.sale_order_no,
    so.quote_id,
    q.quote_no,
    q.status as quote_status
FROM "SalesOrders" so
LEFT JOIN "Quotes" q ON q.id = so.quote_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false;

-- 2. Check QuoteLineComponents (replace quote_id with result from query 1)
SELECT 
    qlc.id,
    qlc.quote_line_id,
    qlc.catalog_item_id,
    qlc.component_role,
    qlc.qty,
    qlc.uom,
    qlc.source,
    qlc.deleted,
    ci.sku,
    ci.item_name
FROM "QuoteLineComponents" qlc
JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
JOIN "Quotes" q ON q.id = ql.quote_id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE q.id = (SELECT quote_id FROM "SalesOrders" WHERE sale_order_no = 'SO-090151' AND deleted = false LIMIT 1)
AND qlc.deleted = false
AND ql.deleted = false
AND q.deleted = false
ORDER BY ql.created_at, qlc.id;

-- 3. Count summary
SELECT 
    COUNT(DISTINCT ql.id) as quote_lines_count,
    COUNT(qlc.id) as quote_line_components_count,
    COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component') as configured_components_count
FROM "QuoteLineComponents" qlc
JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
JOIN "Quotes" q ON q.id = ql.quote_id
WHERE q.id = (SELECT quote_id FROM "SalesOrders" WHERE sale_order_no = 'SO-090151' AND deleted = false LIMIT 1)
AND qlc.deleted = false
AND ql.deleted = false
AND q.deleted = false;



