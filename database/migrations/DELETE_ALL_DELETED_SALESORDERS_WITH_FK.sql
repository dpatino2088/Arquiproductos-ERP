-- ====================================================
-- Delete ALL deleted SalesOrders permanently (handling FK constraints)
-- ====================================================
-- ⚠️ This will PERMANENTLY DELETE:
--   1. ManufacturingOrders that reference deleted SalesOrders
--   2. SalesOrderLines that belong to deleted SalesOrders
--   3. SalesOrders with deleted = true
-- Use this during testing/development when you want to clean up
-- ====================================================

-- STEP 1: Check what will be deleted
SELECT 
    (SELECT COUNT(*) FROM "SalesOrders" WHERE deleted = true) as deleted_sales_orders,
    (SELECT COUNT(*) FROM "ManufacturingOrders" mo 
     JOIN "SalesOrders" so ON so.id = mo.sale_order_id 
     WHERE so.deleted = true) as manufacturing_orders_to_delete,
    (SELECT COUNT(*) FROM "SalesOrderLines" sol 
     JOIN "SalesOrders" so ON so.id = sol.sale_order_id 
     WHERE so.deleted = true) as sales_order_lines_to_delete;

-- STEP 2: Delete ManufacturingOrders that reference deleted SalesOrders
DELETE FROM "ManufacturingOrders"
WHERE sale_order_id IN (
    SELECT id FROM "SalesOrders" WHERE deleted = true
);

-- STEP 3: Delete SalesOrderLines that belong to deleted SalesOrders
DELETE FROM "SalesOrderLines"
WHERE sale_order_id IN (
    SELECT id FROM "SalesOrders" WHERE deleted = true
);

-- STEP 4: Delete BomInstances that reference deleted SalesOrders (via SalesOrderLines)
-- First delete BomInstanceLines
DELETE FROM "BomInstanceLines"
WHERE bom_instance_id IN (
    SELECT bi.id 
    FROM "BomInstances" bi
    JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    WHERE so.deleted = true
);

-- Then delete BomInstances
DELETE FROM "BomInstances"
WHERE sale_order_line_id IN (
    SELECT sol.id 
    FROM "SalesOrderLines" sol
    JOIN "SalesOrders" so ON so.id = sol.sale_order_id
    WHERE so.deleted = true
);

-- STEP 5: Now we can safely delete SalesOrders
DELETE FROM "SalesOrders"
WHERE deleted = true;

-- STEP 6: Verify the results
SELECT 
    COUNT(*) FILTER (WHERE deleted = false) as active_orders,
    COUNT(*) FILTER (WHERE deleted = true) as deleted_orders,
    COUNT(*) as total_orders
FROM "SalesOrders";



