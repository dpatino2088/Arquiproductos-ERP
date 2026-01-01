-- ====================================================
-- Verificar flujo Quote -> Sales Order
-- ====================================================

-- Verificar el Sales Order SO-000006 y su Quote
SELECT 
    'SO-000006 Info' as paso,
    so.id as so_id,
    so.sale_order_no,
    so.quote_id,
    q.quote_no,
    q.status as quote_status,
    COUNT(DISTINCT ql.id) as quote_lines_in_quote,
    COUNT(DISTINCT sol.id) as sales_order_lines_in_so
FROM "SalesOrders" so
LEFT JOIN "Quotes" q ON q.id = so.quote_id
LEFT JOIN "QuoteLines" ql ON ql.quote_id = q.id AND ql.deleted = false
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
WHERE so.sale_order_no = 'SO-000006'
AND so.deleted = false
GROUP BY so.id, so.sale_order_no, so.quote_id, q.quote_no, q.status;

-- Ver las QuoteLines del Quote
SELECT 
    'QuoteLines del Quote' as paso,
    ql.id,
    ql.quote_id,
    ql.product_type_id,
    ql.qty,
    ql.line_total
FROM "SalesOrders" so
JOIN "Quotes" q ON q.id = so.quote_id
JOIN "QuoteLines" ql ON ql.quote_id = q.id AND ql.deleted = false
WHERE so.sale_order_no = 'SO-000006'
AND so.deleted = false;

-- Ver si hay SalesOrderLines
SELECT 
    'SalesOrderLines del SO' as paso,
    sol.id,
    sol.sale_order_id,
    sol.quote_line_id,
    sol.qty,
    sol.line_total
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
WHERE so.sale_order_no = 'SO-000006'
AND so.deleted = false;

