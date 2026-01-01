-- ====================================================
-- TEMPORARY FIX: Undelete SalesOrders
-- ====================================================
-- ⚠️ USE WITH CAUTION: This will undelete ALL SalesOrders
-- Run CHECK_DELETED_SALESORDERS.sql first to understand WHY they were deleted
-- ====================================================

-- Option 1: Undelete ALL SalesOrders (READY TO RUN)
-- ⚠️ This will reactivate all 69 SalesOrders that were deleted
UPDATE "SalesOrders"
SET deleted = false,
    updated_at = now()
WHERE deleted = true;

-- Option 2: Undelete only recent ones (safer - uncomment and adjust date)
-- UPDATE "SalesOrders"
-- SET deleted = false,
--     updated_at = now()
-- WHERE deleted = true
-- AND created_at >= '2024-12-01'::date;  -- Adjust date as needed

-- Option 3: Check first what would be undeleted (SAFE - just shows what would change)
SELECT 
    COUNT(*) as would_undelete,
    MIN(created_at) as oldest_created,
    MAX(created_at) as newest_created
FROM "SalesOrders"
WHERE deleted = true;

-- Show sample of what would be undeleted
SELECT 
    sale_order_no,
    organization_id,
    status,
    created_at,
    updated_at
FROM "SalesOrders"
WHERE deleted = true
ORDER BY created_at DESC
LIMIT 10;

