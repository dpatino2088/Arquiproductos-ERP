-- ====================================================
-- Delete ALL deleted SalesOrders permanently
-- ====================================================
-- ⚠️ This will PERMANENTLY DELETE all SalesOrders with deleted = true
-- Use this during testing/development when you want to clean up
-- ====================================================

-- First, check how many will be deleted
SELECT 
    COUNT(*) as will_be_deleted,
    MIN(created_at) as oldest,
    MAX(created_at) as newest
FROM "SalesOrders"
WHERE deleted = true;

-- Show sample of what will be deleted
SELECT 
    sale_order_no,
    organization_id,
    status,
    created_at
FROM "SalesOrders"
WHERE deleted = true
ORDER BY created_at DESC
LIMIT 10;

-- DELETE ALL deleted SalesOrders permanently
DELETE FROM "SalesOrders"
WHERE deleted = true;

-- Verify: Should show 0 deleted orders
SELECT 
    COUNT(*) FILTER (WHERE deleted = false) as active_orders,
    COUNT(*) FILTER (WHERE deleted = true) as deleted_orders,
    COUNT(*) as total_orders
FROM "SalesOrders";



