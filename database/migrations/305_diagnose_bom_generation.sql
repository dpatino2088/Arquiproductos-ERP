-- ====================================================
-- Migration 305: Diagnose BOM generation for MO-000002
-- ====================================================

-- Step 1: Check Manufacturing Order
SELECT 
    'Manufacturing Order' as step,
    mo.id as mo_id,
    mo.manufacturing_order_no,
    mo.sale_order_id,
    mo.status,
    so.sale_order_no
FROM "ManufacturingOrders" mo
JOIN "SalesOrders" so ON so.id = mo.sale_order_id
WHERE mo.manufacturing_order_no = 'MO-000002'
AND mo.deleted = false;

-- Step 2: Check SalesOrderLines
SELECT 
    'SalesOrderLines' as step,
    sol.id as sol_id,
    sol.sale_order_id,
    sol.line_number,
    sol.quote_line_id,
    sol.product_type
FROM "SalesOrderLines" sol
WHERE sol.sale_order_id = (
    SELECT sale_order_id FROM "ManufacturingOrders" 
    WHERE manufacturing_order_no = 'MO-000002' 
    AND deleted = false
    LIMIT 1
)
AND sol.deleted = false
ORDER BY sol.line_number;

-- Step 3: Check BomInstances
SELECT 
    'BomInstances' as step,
    bi.id as bi_id,
    bi.sale_order_line_id,
    bi.quote_line_id,
    sol.line_number
FROM "BomInstances" bi
LEFT JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
WHERE bi.sale_order_line_id IN (
    SELECT id FROM "SalesOrderLines"
    WHERE sale_order_id = (
        SELECT sale_order_id FROM "ManufacturingOrders" 
        WHERE manufacturing_order_no = 'MO-000002' 
        AND deleted = false
        LIMIT 1
    )
    AND deleted = false
)
AND bi.deleted = false;

-- Step 4: Check BomInstanceLines
SELECT 
    'BomInstanceLines' as step,
    COUNT(*) as bil_count
FROM "BomInstanceLines" bil
WHERE bil.bom_instance_id IN (
    SELECT id FROM "BomInstances"
    WHERE sale_order_line_id IN (
        SELECT id FROM "SalesOrderLines"
        WHERE sale_order_id = (
            SELECT sale_order_id FROM "ManufacturingOrders" 
            WHERE manufacturing_order_no = 'MO-000002' 
            AND deleted = false
            LIMIT 1
        )
        AND deleted = false
    )
    AND deleted = false
)
AND bil.deleted = false;

-- Step 5: Check QuoteLineComponents (source for BOM)
SELECT 
    'QuoteLineComponents' as step,
    qlc.id,
    qlc.quote_line_id,
    qlc.component_role,
    qlc.catalog_item_id,
    ci.sku,
    qlc.qty,
    qlc.uom,
    qlc.source
FROM "QuoteLineComponents" qlc
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE qlc.quote_line_id IN (
    SELECT quote_line_id FROM "SalesOrderLines"
    WHERE sale_order_id = (
        SELECT sale_order_id FROM "ManufacturingOrders" 
        WHERE manufacturing_order_no = 'MO-000002' 
        AND deleted = false
        LIMIT 1
    )
    AND deleted = false
)
AND qlc.deleted = false
ORDER BY qlc.quote_line_id, qlc.component_role;


