-- Verificar si el Quote de SO-000006 tiene líneas
SELECT 
    q.quote_no,
    q.status,
    COUNT(ql.id) as quote_lines_count
FROM "SalesOrders" so
JOIN "Quotes" q ON q.id = so.quote_id
LEFT JOIN "QuoteLines" ql ON ql.quote_id = q.id AND ql.deleted = false
WHERE so.sale_order_no = 'SO-000006'
GROUP BY q.id, q.quote_no, q.status;






