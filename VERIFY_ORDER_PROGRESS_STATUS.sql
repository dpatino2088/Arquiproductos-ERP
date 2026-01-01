-- ============================================================================
-- VERIFICATION QUERIES - Order Progress Status
-- ============================================================================
-- Run these queries after executing migration 192 to verify everything works
-- ============================================================================

-- Query 1: Verify column exists and has correct structure
SELECT 
    column_name,
    data_type,
    column_default,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'SaleOrders'
AND column_name = 'order_progress_status';

-- Query 2: Show SaleOrders distribution by order_progress_status
SELECT 
    order_progress_status,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE deleted = false) as active_count,
    COUNT(*) FILTER (WHERE deleted = true) as deleted_count
FROM "SaleOrders"
GROUP BY order_progress_status
ORDER BY total_count DESC;

-- Query 3: Show SaleOrders with their ManufacturingOrders status (if any)
SELECT 
    so.id,
    so.sale_order_no,
    so.order_progress_status,
    so.status as sale_order_status,
    COUNT(mo.id) as manufacturing_orders_count,
    STRING_AGG(DISTINCT mo.status, ', ') as mo_statuses
FROM "SaleOrders" so
LEFT JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id AND mo.deleted = false
WHERE so.deleted = false
GROUP BY so.id, so.sale_order_no, so.order_progress_status, so.status
ORDER BY so.created_at DESC
LIMIT 20;

-- Query 4: Verify triggers exist
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'public'
AND event_object_table = 'ManufacturingOrders'
AND trigger_name LIKE '%sync_sale_order_progress%'
ORDER BY trigger_name;

-- Query 5: Verify function exists
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'sync_sale_order_progress_from_manufacturing';








