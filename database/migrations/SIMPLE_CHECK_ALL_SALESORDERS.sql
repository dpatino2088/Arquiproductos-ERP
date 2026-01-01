-- ====================================================
-- Simple Check: Show ALL SalesOrders
-- ====================================================
-- Execute this to see all SalesOrders that exist
-- ====================================================

-- Show ALL SalesOrders (including deleted to see what exists)
SELECT 
    id,
    sale_order_no,
    organization_id,
    status,
    deleted,
    created_at
FROM "SalesOrders"
ORDER BY created_at DESC
LIMIT 20;

-- Show only active (not deleted) SalesOrders
SELECT 
    id,
    sale_order_no,
    organization_id,
    status,
    deleted,
    created_at
FROM "SalesOrders"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 20;



