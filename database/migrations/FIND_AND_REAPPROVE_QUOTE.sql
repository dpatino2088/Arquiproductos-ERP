-- ====================================================
-- Find and Re-approve Quote
-- ====================================================
-- This will find the most recent approved quote and re-approve it
-- ====================================================

-- 1. Find all approved quotes
SELECT 
    id,
    quote_no,
    status,
    organization_id,
    customer_id,
    deleted,
    updated_at
FROM "Quotes"
WHERE deleted = false
ORDER BY updated_at DESC
LIMIT 10;

-- 2. Re-approve the most recent approved quote (to trigger the function)
-- First, change to draft
UPDATE "Quotes"
SET status = 'draft',
    updated_at = now()
WHERE id = (
    SELECT id 
    FROM "Quotes" 
    WHERE status = 'approved' 
    AND deleted = false 
    ORDER BY updated_at DESC 
    LIMIT 1
);

-- 3. Then approve it again (this should trigger the function)
UPDATE "Quotes"
SET status = 'approved',
    updated_at = now()
WHERE id = (
    SELECT id 
    FROM "Quotes" 
    WHERE status = 'draft' 
    AND deleted = false 
    ORDER BY updated_at DESC 
    LIMIT 1
);

-- 4. Check if SalesOrder was created
SELECT 
    q.quote_no,
    q.status as quote_status,
    so.id as sale_order_id,
    so.sale_order_no,
    so.status as so_status,
    so.deleted as so_deleted,
    so.created_at as so_created_at
FROM "Quotes" q
LEFT JOIN "SalesOrders" so ON so.quote_id = q.id
WHERE q.deleted = false
ORDER BY q.updated_at DESC
LIMIT 5;



