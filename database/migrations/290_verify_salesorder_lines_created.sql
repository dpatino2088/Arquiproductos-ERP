-- ====================================================
-- Migration 290: Verify SalesOrderLines were created
-- ====================================================
-- Quick verification query to check SalesOrderLines
-- ====================================================

SELECT 
    'SalesOrderLines Check' as check_type,
    so.sale_order_no,
    so.status as so_status,
    COUNT(DISTINCT sol.id) as sales_order_lines_count,
    COUNT(DISTINCT ql.id) as quote_lines_count,
    COUNT(DISTINCT bi.id) as bom_instances_count
FROM "SalesOrders" so
LEFT JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
LEFT JOIN "QuoteLines" ql ON ql.quote_id = so.quote_id AND ql.deleted = false
LEFT JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
WHERE so.sale_order_no = 'SO-090154'
AND so.deleted = false
GROUP BY so.sale_order_no, so.status;

-- Detailed view of SalesOrderLines
SELECT 
    sol.id as sol_id,
    sol.line_number,
    sol.catalog_item_id,
    ci.sku,
    ci.item_name,
    sol.qty,
    sol.width_m,
    sol.height_m,
    sol.product_type,
    sol.drive_type,
    sol.tube_type,
    sol.operating_system_variant
FROM "SalesOrderLines" sol
LEFT JOIN "CatalogItems" ci ON ci.id = sol.catalog_item_id
WHERE sol.sale_order_id = (
    SELECT id FROM "SalesOrders" 
    WHERE sale_order_no = 'SO-090154' 
    AND deleted = false
    LIMIT 1
)
AND sol.deleted = false
ORDER BY sol.line_number;


