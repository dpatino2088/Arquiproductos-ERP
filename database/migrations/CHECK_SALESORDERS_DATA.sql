-- ====================================================
-- Check SalesOrders data - especially sale_order_no
-- ====================================================
-- Since SalesOrders ARE being created, let's check the data format
-- ====================================================

-- 1. Check all SalesOrders and their sale_order_no format
SELECT 
    id,
    sale_order_no,
    organization_id,
    status,
    deleted,
    created_at,
    CASE 
        WHEN sale_order_no IS NULL THEN '❌ NULL'
        WHEN sale_order_no = '' THEN '❌ EMPTY'
        WHEN sale_order_no NOT LIKE 'SO-%' THEN '⚠️ Wrong format: ' || sale_order_no
        ELSE '✅ OK'
    END as sale_order_no_status
FROM "SalesOrders"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 20;

-- 2. Check if there are SalesOrders with NULL sale_order_no
SELECT 
    COUNT(*) as orders_with_null_sale_order_no
FROM "SalesOrders"
WHERE deleted = false
AND sale_order_no IS NULL;

-- 3. Show recent SalesOrders with full details
SELECT 
    sale_order_no,
    organization_id,
    quote_id,
    customer_id,
    status,
    total,
    currency,
    created_at
FROM "SalesOrders"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 10;



