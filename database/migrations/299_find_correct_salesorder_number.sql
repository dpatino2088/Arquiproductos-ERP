-- ====================================================
-- Migration 299: Find the correct SalesOrder number
-- ====================================================
-- Searches for SalesOrders that might match
-- ====================================================

-- Search for SalesOrders with similar numbers
SELECT 
    'All SalesOrders' as step,
    so.id,
    so.sale_order_no,
    so.organization_id,
    so.quote_id,
    so.status,
    so.deleted,
    q.quote_no
FROM "SalesOrders" so
LEFT JOIN "Quotes" q ON q.id = so.quote_id
WHERE so.sale_order_no ILIKE '%090154%'
   OR so.sale_order_no ILIKE '%SO%090154%'
   OR so.sale_order_no ILIKE '%S0%090154%'
ORDER BY so.created_at DESC;

-- Also check for the quote QT-000003
SELECT 
    'Quote QT-000003 SalesOrders' as step,
    so.id,
    so.sale_order_no,
    so.organization_id,
    so.quote_id,
    so.status,
    so.deleted
FROM "SalesOrders" so
JOIN "Quotes" q ON q.id = so.quote_id
WHERE q.quote_no = 'QT-000003'
AND so.deleted = false
ORDER BY so.created_at DESC;

-- Get the most recent SalesOrder
SELECT 
    'Most Recent SalesOrder' as step,
    so.id,
    so.sale_order_no,
    so.organization_id,
    so.quote_id,
    so.status,
    q.quote_no
FROM "SalesOrders" so
LEFT JOIN "Quotes" q ON q.id = so.quote_id
WHERE so.deleted = false
ORDER BY so.created_at DESC
LIMIT 5;


