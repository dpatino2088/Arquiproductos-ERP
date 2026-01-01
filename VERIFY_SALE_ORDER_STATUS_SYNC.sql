-- ====================================================
-- Verification Script: SaleOrders Status Sync
-- ====================================================
-- Run this AFTER executing migration 193_sync_sale_order_status_from_manufacturing.sql
-- ====================================================

-- Query 1: Verify CHECK constraint exists
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = (SELECT oid FROM pg_class WHERE relname = 'SaleOrders')
AND conname = 'SaleOrders_status_check';

-- Query 2: Show status distribution
SELECT 
    status,
    COUNT(*) AS count
FROM "SaleOrders"
WHERE deleted = false
GROUP BY status
ORDER BY count DESC;

-- Query 3: Verify function exists
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('map_mo_status_to_so_status', 'on_manufacturing_order_status_change')
ORDER BY routine_name;

-- Query 4: Verify trigger exists
SELECT
    tgname AS trigger_name,
    relname AS table_name,
    pg_get_triggerdef(t.oid) AS trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
WHERE LOWER(c.relname) = LOWER('ManufacturingOrders')
AND tgname = 'trg_mo_status_sync_sale_order';

-- Query 5: Test mapping function
SELECT 
    'planned' AS mo_status,
    public.map_mo_status_to_so_status('planned') AS so_status
UNION ALL
SELECT 'in_production', public.map_mo_status_to_so_status('in_production')
UNION ALL
SELECT 'completed', public.map_mo_status_to_so_status('completed')
UNION ALL
SELECT 'cancelled', public.map_mo_status_to_so_status('cancelled')
UNION ALL
SELECT 'draft', public.map_mo_status_to_so_status('draft')
ORDER BY mo_status;

-- Query 6: Check if there are any SaleOrders with old status values
SELECT 
    id,
    sale_order_no,
    status,
    created_at
FROM "SaleOrders"
WHERE deleted = false
AND status NOT IN ('Draft', 'Confirmed', 'In Production', 'Ready for Delivery', 'Delivered', 'Cancelled')
LIMIT 10;








