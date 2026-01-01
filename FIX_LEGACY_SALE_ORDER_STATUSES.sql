-- ====================================================
-- Fix Legacy SaleOrder Statuses
-- ====================================================
-- This script migrates any SaleOrders that still have old status values
-- to the new customer-facing format
-- ====================================================

-- Step 1: Check how many records need migration (case-insensitive check, trim whitespace)
SELECT 
    status AS current_status,
    LENGTH(status) AS status_length,
    COUNT(*) AS count
FROM "SaleOrders"
WHERE deleted = false
AND (
    LOWER(TRIM(status)) NOT IN ('draft', 'confirmed', 'in production', 'ready for delivery', 'delivered', 'cancelled')
    OR status NOT IN ('Draft', 'Confirmed', 'In Production', 'Ready for Delivery', 'Delivered', 'Cancelled')
)
GROUP BY status, LENGTH(status)
ORDER BY count DESC;

-- Step 2: Migrate old status values to new format (case-insensitive, trim whitespace)
UPDATE "SaleOrders"
SET status = CASE
    WHEN LOWER(TRIM(status)) = 'draft' THEN 'Draft'
    WHEN LOWER(TRIM(status)) = 'confirmed' THEN 'Confirmed'
    WHEN LOWER(TRIM(status)) = 'in_production' THEN 'In Production'
    WHEN LOWER(TRIM(status)) = 'shipped' THEN 'Ready for Delivery'
    WHEN LOWER(TRIM(status)) = 'delivered' THEN 'Delivered'
    WHEN LOWER(TRIM(status)) = 'cancelled' THEN 'Cancelled'
    ELSE 'Draft' -- Default fallback for any unknown status
END,
updated_at = now()
WHERE deleted = false
AND (
    LOWER(TRIM(status)) NOT IN ('draft', 'confirmed', 'in production', 'ready for delivery', 'delivered', 'cancelled')
    OR status NOT IN ('Draft', 'Confirmed', 'In Production', 'Ready for Delivery', 'Delivered', 'Cancelled')
);

-- Step 3: Verify migration completed
SELECT 
    status,
    COUNT(*) AS count
FROM "SaleOrders"
WHERE deleted = false
GROUP BY status
ORDER BY count DESC;

-- Step 4: Check if any records still have invalid statuses
SELECT 
    id,
    sale_order_no,
    status,
    created_at
FROM "SaleOrders"
WHERE deleted = false
AND status NOT IN ('Draft', 'Confirmed', 'In Production', 'Ready for Delivery', 'Delivered', 'Cancelled')
LIMIT 10;

