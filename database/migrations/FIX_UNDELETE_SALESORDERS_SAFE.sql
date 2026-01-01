-- ====================================================
-- SAFE Fix: Undelete SalesOrders (avoiding duplicates)
-- ====================================================
-- This will only undelete SalesOrders that don't have active duplicates
-- ====================================================

-- Strategy: Only undelete SalesOrders where there's NO active version with same (org_id, sale_order_no)

-- 1. First, check how many would be undeleted safely
SELECT 
    COUNT(*) as can_safely_undelete,
    COUNT(*) FILTER (WHERE sale_order_no IS NULL) as null_sale_order_no
FROM "SalesOrders" so_deleted
WHERE so_deleted.deleted = true
AND NOT EXISTS (
    SELECT 1 
    FROM "SalesOrders" so_active
    WHERE so_active.organization_id = so_deleted.organization_id
    AND so_active.sale_order_no = so_deleted.sale_order_no
    AND so_active.deleted = false
);

-- 2. Show sample of what can be safely undeleted
SELECT 
    id,
    sale_order_no,
    organization_id,
    status,
    created_at
FROM "SalesOrders" so_deleted
WHERE so_deleted.deleted = true
AND NOT EXISTS (
    SELECT 1 
    FROM "SalesOrders" so_active
    WHERE so_active.organization_id = so_deleted.organization_id
    AND so_active.sale_order_no = so_deleted.sale_order_no
    AND so_active.deleted = false
)
ORDER BY created_at DESC
LIMIT 20;

-- 3. UNDELETE ONLY the ones that don't have active duplicates (SAFE)
UPDATE "SalesOrders"
SET deleted = false,
    updated_at = now()
WHERE deleted = true
AND NOT EXISTS (
    SELECT 1 
    FROM "SalesOrders" so_active
    WHERE so_active.organization_id = "SalesOrders".organization_id
    AND so_active.sale_order_no = "SalesOrders".sale_order_no
    AND so_active.deleted = false
);

-- 4. For the duplicates, we need to decide what to do:
-- Option A: Delete the deleted duplicates permanently (they're redundant)
-- DELETE FROM "SalesOrders"
-- WHERE deleted = true
-- AND EXISTS (
--     SELECT 1 
--     FROM "SalesOrders" so_active
--     WHERE so_active.organization_id = "SalesOrders".organization_id
--     AND so_active.sale_order_no = "SalesOrders".sale_order_no
--     AND so_active.deleted = false
-- );

-- Option B: Rename the deleted duplicates (if we want to keep them)
-- This would require updating sale_order_no to something like 'SO-000001-DELETED'
-- (More complex, not recommended unless you need to keep them)



