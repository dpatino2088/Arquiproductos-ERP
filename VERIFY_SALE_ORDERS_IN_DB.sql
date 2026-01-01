-- ====================================================
-- Verify SaleOrders in Database
-- ====================================================
-- This script verifies if SaleOrders exist in the database
-- ====================================================

-- 1. Check all SaleOrders
SELECT 
    id,
    sale_order_no,
    quote_id,
    status,
    order_progress_status,
    created_at
FROM "SaleOrders"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 10;

-- 2. Check approved quotes and their SaleOrders
SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.status AS quote_status,
    q.organization_id,
    so.id AS sale_order_id,
    so.sale_order_no,
    so.status AS sale_order_status,
    so.order_progress_status,
    so.organization_id AS so_organization_id
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.created_at DESC;

-- 3. Check if there are any SaleOrders for QT-000019 specifically
SELECT 
    q.id AS quote_id,
    q.quote_no,
    so.id AS sale_order_id,
    so.sale_order_no,
    so.status,
    so.order_progress_status
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.quote_no = 'QT-000019'
AND q.deleted = false;

-- 4. Check organization_id match (this could be the issue!)
SELECT 
    q.id AS quote_id,
    q.quote_no,
    q.organization_id AS quote_org_id,
    so.id AS sale_order_id,
    so.sale_order_no,
    so.organization_id AS so_org_id,
    CASE 
        WHEN q.organization_id = so.organization_id THEN '✅ Match'
        WHEN so.organization_id IS NULL THEN '❌ No SaleOrder'
        ELSE '❌ Mismatch'
    END AS org_match
FROM "Quotes" q
LEFT JOIN "SaleOrders" so ON so.quote_id = q.id AND so.deleted = false
WHERE q.status = 'approved'
AND q.deleted = false
ORDER BY q.created_at DESC;








