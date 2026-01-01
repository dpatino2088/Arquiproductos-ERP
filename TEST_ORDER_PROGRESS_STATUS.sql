-- ============================================================================
-- TEST ORDER PROGRESS STATUS - Step by Step Testing
-- ============================================================================
-- Use this script to test the order_progress_status functionality
-- ============================================================================

-- ============================================================================
-- TEST 1: Verify initial state after migration
-- ============================================================================
SELECT 
    'TEST 1: Initial State' as test_name,
    COUNT(*) FILTER (WHERE order_progress_status = 'approved_awaiting_confirmation') as approved_awaiting_confirmation,
    COUNT(*) FILTER (WHERE order_progress_status = 'confirmed') as confirmed,
    COUNT(*) FILTER (WHERE order_progress_status = 'scheduled') as scheduled,
    COUNT(*) FILTER (WHERE order_progress_status = 'in_production') as in_production,
    COUNT(*) FILTER (WHERE order_progress_status = 'production_completed') as production_completed,
    COUNT(*) FILTER (WHERE order_progress_status = 'ready_for_delivery') as ready_for_delivery,
    COUNT(*) FILTER (WHERE order_progress_status = 'delivered') as delivered,
    COUNT(*) FILTER (WHERE order_progress_status IS NULL) as null_status
FROM "SaleOrders"
WHERE deleted = false;

-- ============================================================================
-- TEST 2: Find a SaleOrder to test with (one without ManufacturingOrder)
-- ============================================================================
SELECT 
    'TEST 2: SaleOrders without ManufacturingOrders' as test_name,
    so.id,
    so.sale_order_no,
    so.order_progress_status,
    so.status as sale_order_status,
    COUNT(mo.id) as manufacturing_orders_count
FROM "SaleOrders" so
LEFT JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id AND mo.deleted = false
WHERE so.deleted = false
GROUP BY so.id, so.sale_order_no, so.order_progress_status, so.status
HAVING COUNT(mo.id) = 0
ORDER BY so.created_at DESC
LIMIT 5;

-- ============================================================================
-- TEST 3: Find SaleOrders with ManufacturingOrders to verify sync
-- ============================================================================
SELECT 
    'TEST 3: SaleOrders with ManufacturingOrders' as test_name,
    so.id,
    so.sale_order_no,
    so.order_progress_status,
    mo.id as mo_id,
    mo.manufacturing_order_no,
    mo.status as mo_status
FROM "SaleOrders" so
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id AND mo.deleted = false
WHERE so.deleted = false
ORDER BY so.created_at DESC
LIMIT 10;

-- ============================================================================
-- TEST 4: Example test scenario (DO NOT EXECUTE - for reference only)
-- ============================================================================
/*
-- STEP 1: Get a SaleOrder ID to test with
-- Replace 'YOUR_SALE_ORDER_ID' with an actual ID from TEST 2 above
SELECT id, sale_order_no, order_progress_status 
FROM "SaleOrders" 
WHERE id = 'YOUR_SALE_ORDER_ID'::uuid;

-- STEP 2: Create a ManufacturingOrder for that SaleOrder
-- This should automatically set order_progress_status to 'scheduled'
INSERT INTO "ManufacturingOrders" (
    organization_id,
    sale_order_id,
    manufacturing_order_no,
    status
) VALUES (
    (SELECT organization_id FROM "SaleOrders" WHERE id = 'YOUR_SALE_ORDER_ID'::uuid),
    'YOUR_SALE_ORDER_ID'::uuid,
    'MO-TEST-001',
    'planned'
);

-- STEP 3: Verify order_progress_status changed to 'scheduled'
SELECT id, sale_order_no, order_progress_status 
FROM "SaleOrders" 
WHERE id = 'YOUR_SALE_ORDER_ID'::uuid;
-- Expected: order_progress_status = 'scheduled'

-- STEP 4: Update ManufacturingOrder status to 'in_production'
UPDATE "ManufacturingOrders"
SET status = 'in_production'
WHERE id = (SELECT id FROM "ManufacturingOrders" WHERE sale_order_id = 'YOUR_SALE_ORDER_ID'::uuid LIMIT 1);

-- STEP 5: Verify order_progress_status changed to 'in_production'
SELECT id, sale_order_no, order_progress_status 
FROM "SaleOrders" 
WHERE id = 'YOUR_SALE_ORDER_ID'::uuid;
-- Expected: order_progress_status = 'in_production'

-- STEP 6: Update ManufacturingOrder status to 'completed'
UPDATE "ManufacturingOrders"
SET status = 'completed'
WHERE id = (SELECT id FROM "ManufacturingOrders" WHERE sale_order_id = 'YOUR_SALE_ORDER_ID'::uuid LIMIT 1);

-- STEP 7: Verify order_progress_status changed to 'production_completed'
SELECT id, sale_order_no, order_progress_status 
FROM "SaleOrders" 
WHERE id = 'YOUR_SALE_ORDER_ID'::uuid;
-- Expected: order_progress_status = 'production_completed'

-- STEP 8: Test protection of manual states
-- Set order_progress_status manually to 'ready_for_delivery'
UPDATE "SaleOrders"
SET order_progress_status = 'ready_for_delivery'
WHERE id = 'YOUR_SALE_ORDER_ID'::uuid;

-- Try to update ManufacturingOrder status (should NOT overwrite 'ready_for_delivery')
UPDATE "ManufacturingOrders"
SET status = 'in_production'
WHERE id = (SELECT id FROM "ManufacturingOrders" WHERE sale_order_id = 'YOUR_SALE_ORDER_ID'::uuid LIMIT 1);

-- Verify order_progress_status is still 'ready_for_delivery' (not overwritten)
SELECT id, sale_order_no, order_progress_status 
FROM "SaleOrders" 
WHERE id = 'YOUR_SALE_ORDER_ID'::uuid;
-- Expected: order_progress_status = 'ready_for_delivery' (unchanged)
*/

-- ============================================================================
-- TEST 5: Check trigger logs (if you have access to PostgreSQL logs)
-- ============================================================================
-- Note: This requires access to PostgreSQL logs, which may not be available in Supabase UI
-- The triggers will log NOTICE messages when they fire

-- ============================================================================
-- TEST 6: Verify all constraints and triggers are in place
-- ============================================================================
SELECT 
    'TEST 6: Constraints and Triggers' as test_name,
    'CHECK constraint on order_progress_status' as item,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.table_constraints tc
            JOIN information_schema.check_constraints cc ON tc.constraint_name = cc.constraint_name
            WHERE tc.table_schema = 'public'
            AND tc.table_name = 'SaleOrders'
            AND tc.constraint_type = 'CHECK'
            AND cc.check_clause LIKE '%order_progress_status%'
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status
UNION ALL
SELECT 
    'TEST 6: Constraints and Triggers',
    'Trigger: trg_sync_sale_order_progress_on_mo_insert',
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.triggers
            WHERE trigger_schema = 'public'
            AND event_object_table = 'ManufacturingOrders'
            AND trigger_name = 'trg_sync_sale_order_progress_on_mo_insert'
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END
UNION ALL
SELECT 
    'TEST 6: Constraints and Triggers',
    'Trigger: trg_sync_sale_order_progress_on_mo_status_update',
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.triggers
            WHERE trigger_schema = 'public'
            AND event_object_table = 'ManufacturingOrders'
            AND trigger_name = 'trg_sync_sale_order_progress_on_mo_status_update'
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END;








