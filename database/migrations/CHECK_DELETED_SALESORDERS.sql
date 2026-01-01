-- ====================================================
-- Check WHY SalesOrders are marked as deleted
-- ====================================================
-- This will show us when and why they were deleted
-- ====================================================

-- 1. Show recent SalesOrders (including deleted ones)
SELECT 
    id,
    sale_order_no,
    organization_id,
    status,
    deleted,
    created_at,
    updated_at,
    created_by,
    updated_by
FROM "SalesOrders"
ORDER BY created_at DESC
LIMIT 20;

-- 2. Check if they were deleted at creation or later
SELECT 
    COUNT(*) as total_orders,
    COUNT(*) FILTER (WHERE deleted = false) as active_orders,
    COUNT(*) FILTER (WHERE deleted = true) as deleted_orders,
    COUNT(*) FILTER (WHERE deleted = true AND created_at = updated_at) as deleted_at_creation,
    COUNT(*) FILTER (WHERE deleted = true AND created_at != updated_at) as deleted_after_creation
FROM "SalesOrders";

-- 3. Show the most recent ones (to see the pattern)
SELECT 
    sale_order_no,
    organization_id,
    status,
    deleted,
    created_at::date as created_date,
    updated_at::date as updated_date,
    CASE 
        WHEN created_at = updated_at THEN 'Deleted at creation'
        ELSE 'Deleted later'
    END as deletion_timing
FROM "SalesOrders"
ORDER BY created_at DESC
LIMIT 10;



