-- ====================================================
-- Migration 304: Verify SalesOrderLines have correct organization_id
-- ====================================================

SELECT 
    'SalesOrderLines Check' as step,
    sol.id,
    sol.sale_order_id,
    sol.line_number,
    sol.organization_id as sol_org_id,
    so.organization_id as so_org_id,
    CASE 
        WHEN sol.organization_id = so.organization_id THEN '✅ Match'
        ELSE '❌ Mismatch'
    END as org_match
FROM "SalesOrderLines" sol
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090154'
AND sol.deleted = false
AND so.deleted = false
ORDER BY sol.line_number;

-- Update organization_id if it doesn't match
UPDATE "SalesOrderLines" sol
SET organization_id = so.organization_id,
    updated_at = now()
FROM "SalesOrders" so
WHERE sol.sale_order_id = so.id
AND so.sale_order_no = 'SO-090154'
AND sol.deleted = false
AND so.deleted = false
AND (sol.organization_id IS NULL OR sol.organization_id != so.organization_id);

-- Final verification
SELECT 
    'Final Verification' as step,
    COUNT(*) as total_lines,
    COUNT(*) FILTER (WHERE sol.organization_id = so.organization_id) as matching_org_id
FROM "SalesOrderLines" sol
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090154'
AND sol.deleted = false
AND so.deleted = false;


