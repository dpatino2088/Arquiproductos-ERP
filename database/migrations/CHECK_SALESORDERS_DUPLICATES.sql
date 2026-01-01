-- ====================================================
-- Check for duplicate sale_order_no (active vs deleted)
-- ====================================================
-- This will show which sale_order_no have both active and deleted versions
-- ====================================================

-- 1. Find duplicates (same organization_id + sale_order_no with both deleted=true and deleted=false)
SELECT 
    organization_id,
    sale_order_no,
    COUNT(*) FILTER (WHERE deleted = false) as active_count,
    COUNT(*) FILTER (WHERE deleted = true) as deleted_count,
    COUNT(*) as total_count
FROM "SalesOrders"
GROUP BY organization_id, sale_order_no
HAVING COUNT(*) FILTER (WHERE deleted = false) > 0 
   AND COUNT(*) FILTER (WHERE deleted = true) > 0
ORDER BY total_count DESC, sale_order_no;

-- 2. Show the actual duplicate records
SELECT 
    id,
    sale_order_no,
    organization_id,
    status,
    deleted,
    created_at,
    updated_at
FROM "SalesOrders"
WHERE (organization_id, sale_order_no) IN (
    SELECT organization_id, sale_order_no
    FROM "SalesOrders"
    GROUP BY organization_id, sale_order_no
    HAVING COUNT(*) FILTER (WHERE deleted = false) > 0 
       AND COUNT(*) FILTER (WHERE deleted = true) > 0
)
ORDER BY organization_id, sale_order_no, deleted, created_at;

-- 3. Count total duplicates
SELECT 
    COUNT(DISTINCT (organization_id, sale_order_no)) as duplicate_combinations,
    SUM(CASE WHEN deleted = true THEN 1 ELSE 0 END) as deleted_duplicates,
    SUM(CASE WHEN deleted = false THEN 1 ELSE 0 END) as active_duplicates
FROM "SalesOrders"
WHERE (organization_id, sale_order_no) IN (
    SELECT organization_id, sale_order_no
    FROM "SalesOrders"
    GROUP BY organization_id, sale_order_no
    HAVING COUNT(*) FILTER (WHERE deleted = false) > 0 
       AND COUNT(*) FILTER (WHERE deleted = true) > 0
);



