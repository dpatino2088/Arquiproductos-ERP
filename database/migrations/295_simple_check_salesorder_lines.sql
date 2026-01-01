-- ====================================================
-- Migration 295: Simple check - Do SalesOrderLines exist for SO-090154?
-- ====================================================
-- Simple verification without RLS concerns
-- ====================================================

-- Check SalesOrder
SELECT 
    'SalesOrder' as check_type,
    so.id as sale_order_id,
    so.sale_order_no,
    so.organization_id,
    so.status,
    so.deleted
FROM "SalesOrders" so
WHERE so.sale_order_no = 'SO-090154';

-- Check SalesOrderLines
SELECT 
    'SalesOrderLines' as check_type,
    sol.id,
    sol.sale_order_id,
    sol.quote_line_id,
    sol.line_number,
    sol.organization_id,
    sol.catalog_item_id,
    ci.sku,
    sol.qty,
    sol.deleted
FROM "SalesOrderLines" sol
LEFT JOIN "CatalogItems" ci ON ci.id = sol.catalog_item_id
WHERE sol.sale_order_id = (
    SELECT id FROM "SalesOrders" 
    WHERE sale_order_no = 'SO-090154' 
    LIMIT 1
)
ORDER BY sol.line_number;

-- Count summary
SELECT 
    'Summary' as check_type,
    COUNT(DISTINCT so.id) as sales_orders,
    COUNT(DISTINCT sol.id) as sales_order_lines,
    COUNT(DISTINCT bi.id) as bom_instances
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.sale_order_no = 'SO-090154';


