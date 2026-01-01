-- ====================================================
-- Quick Check: Why Sales Orders are not showing
-- ====================================================
-- Run this to quickly diagnose the issue
-- ====================================================

-- 1. Check if SalesOrders exist at all
SELECT 
    COUNT(*) as total_sales_orders,
    COUNT(*) FILTER (WHERE deleted = false) as active_orders
FROM "SalesOrders";

-- 2. Show recent SalesOrders
SELECT 
    sale_order_no,
    organization_id,
    status,
    deleted,
    created_at
FROM "SalesOrders"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 10;

-- 3. Check SalesOrders by organization (if you know your org_id)
-- Replace 'YOUR-ORG-ID' with actual UUID if needed:
-- SELECT 
--     sale_order_no,
--     organization_id,
--     status,
--     deleted,
--     created_at
-- FROM "SalesOrders"
-- WHERE organization_id = 'YOUR-ORG-ID'::uuid
-- AND deleted = false
-- ORDER BY created_at DESC;

