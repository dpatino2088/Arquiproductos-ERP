-- ====================================================
-- Quick Test: Verify SalesOrder Creation After Quote Approval
-- ====================================================
-- Replace <quote_id> with the actual quote ID you just approved
-- ====================================================

-- 1. Verify SalesOrder was created
SELECT 
    so.id as sales_order_id,
    so.sale_order_no,
    so.status,
    so.quote_id,
    so.customer_id,
    so.subtotal,
    so.tax,
    so.total,
    so.created_at,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol WHERE sol.sale_order_id = so.id AND sol.deleted = false) as line_count
FROM "SalesOrders" so
WHERE so.quote_id = '<quote_id>'  -- Replace with actual quote ID
AND so.deleted = false;

-- 2. Verify SalesOrderLines were created
SELECT 
    sol.id,
    sol.line_number,
    sol.sku,
    sol.item_name,
    sol.qty,
    sol.unit_price,
    sol.line_total,
    sol.product_type,
    sol.drive_type,
    sol.hardware_color
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.quote_id = '<quote_id>'  -- Replace with actual quote ID
AND sol.deleted = false
ORDER BY sol.line_number;

-- 3. Verify BomInstances were created
SELECT 
    bi.id as bom_instance_id,
    bi.status,
    sol.line_number,
    sol.sku,
    (SELECT COUNT(*) FROM "BomInstanceLines" bil WHERE bil.bom_instance_id = bi.id AND bil.deleted = false) as component_count
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.quote_id = '<quote_id>'  -- Replace with actual quote ID
AND bi.deleted = false
ORDER BY sol.line_number;

-- 4. Quick summary: Quote vs SalesOrder
SELECT 
    'Quote' as entity_type,
    q.quote_no as document_number,
    q.status as status,
    q.created_at
FROM "Quotes" q
WHERE q.id = '<quote_id>'  -- Replace with actual quote ID

UNION ALL

SELECT 
    'SalesOrder' as entity_type,
    so.sale_order_no as document_number,
    so.status as status,
    so.created_at
FROM "SalesOrders" so
WHERE so.quote_id = '<quote_id>'  -- Replace with actual quote ID
AND so.deleted = false

ORDER BY created_at;




