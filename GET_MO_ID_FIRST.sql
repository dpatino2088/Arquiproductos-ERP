-- ====================================================
-- STEP 0: Get MO ID first
-- ====================================================
-- Run this FIRST to get the MO ID, then use it in VERIFY_BOM_COMPONENTS_AND_UOM.sql
-- ====================================================

-- Option 1: Get MO ID by manufacturing_order_no
SELECT 
    mo.id as mo_id,
    mo.manufacturing_order_no,
    mo.status,
    so.sale_order_no,
    so.id as sale_order_id
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
WHERE mo.manufacturing_order_no = 'MO-000003'  -- Change this to your MO number
AND mo.deleted = false;

-- Option 2: Get all recent MOs
SELECT 
    mo.id as mo_id,
    mo.manufacturing_order_no,
    mo.status,
    so.sale_order_no
FROM "ManufacturingOrders" mo
INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id
WHERE mo.deleted = false
ORDER BY mo.created_at DESC
LIMIT 10;






