-- ====================================================
-- Fix SalesOrders - Step by Step
-- ====================================================
-- Execute these queries IN ORDER
-- ====================================================

-- STEP 1: Check for duplicates first
-- ====================================================
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

-- STEP 2: Delete duplicate deleted records (keep active ones)
-- ====================================================
-- This removes the deleted duplicates, keeping only the active versions
DELETE FROM "SalesOrders"
WHERE deleted = true
AND EXISTS (
    SELECT 1 
    FROM "SalesOrders" so_active
    WHERE so_active.organization_id = "SalesOrders".organization_id
    AND so_active.sale_order_no = "SalesOrders".sale_order_no
    AND so_active.deleted = false
);

-- STEP 3: Now undelete the remaining ones (no duplicates left)
-- ====================================================
UPDATE "SalesOrders"
SET deleted = false,
    updated_at = now()
WHERE deleted = true;

-- STEP 4: Verify the results
-- ====================================================
SELECT 
    COUNT(*) FILTER (WHERE deleted = false) as active_orders,
    COUNT(*) FILTER (WHERE deleted = true) as deleted_orders,
    COUNT(*) as total_orders
FROM "SalesOrders";



