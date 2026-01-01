-- ====================================================
-- Migration 341: Diagnose BOM Generation with Results Table
-- ====================================================
-- Diagnostic script that returns results in a table format
-- ====================================================

-- Step 1: Check prerequisites
WITH mo_info AS (
    SELECT 
        mo.id as mo_id,
        mo.manufacturing_order_no,
        mo.sale_order_id,
        so.sale_order_no,
        so.quote_id
    FROM "ManufacturingOrders" mo
    LEFT JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
    WHERE mo.manufacturing_order_no = 'MO-000003'
    AND mo.deleted = false
    LIMIT 1
),
sol_count AS (
    SELECT COUNT(*) as count
    FROM "SalesOrderLines" sol
    INNER JOIN mo_info ON mo_info.sale_order_id = sol.sale_order_id
    WHERE sol.deleted = false
),
qlc_count AS (
    SELECT COUNT(*) as count
    FROM "QuoteLineComponents" qlc
    INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
    INNER JOIN mo_info ON mo_info.quote_id = ql.quote_id
    WHERE qlc.deleted = false
    AND qlc.source = 'configured_component'
),
bi_count AS (
    SELECT COUNT(DISTINCT bi.id) as count
    FROM "BomInstances" bi
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN mo_info ON mo_info.sale_order_id = sol.sale_order_id
    WHERE bi.deleted = false
),
bil_count AS (
    SELECT COUNT(DISTINCT bil.id) as count
    FROM "BomInstanceLines" bil
    INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
    INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
    INNER JOIN mo_info ON mo_info.sale_order_id = sol.sale_order_id
    WHERE bil.deleted = false
)
SELECT 
    'MO-000003' as manufacturing_order_no,
    (SELECT mo_id FROM mo_info) as mo_id,
    (SELECT sale_order_no FROM mo_info) as sale_order_no,
    (SELECT quote_id FROM mo_info) as quote_id,
    (SELECT count FROM sol_count) as sales_order_lines,
    (SELECT count FROM qlc_count) as quote_line_components,
    (SELECT count FROM bi_count) as bom_instances,
    (SELECT count FROM bil_count) as bom_instance_lines,
    CASE 
        WHEN (SELECT count FROM sol_count) = 0 THEN '❌ No SalesOrderLines'
        WHEN (SELECT count FROM qlc_count) = 0 THEN '❌ No QuoteLineComponents'
        WHEN (SELECT count FROM bi_count) = 0 THEN '❌ No BomInstances'
        WHEN (SELECT count FROM bil_count) = 0 THEN '⚠️ BomInstances exist but no Lines'
        ELSE '✅ BOM exists'
    END as status;

-- Step 2: Show QuoteLineComponents details
SELECT 
    'QuoteLineComponents Details' as section,
    qlc.component_role,
    qlc.qty,
    qlc.uom,
    ci.sku,
    ci.item_name,
    ql.id as quote_line_id
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
INNER JOIN "SalesOrders" so ON so.quote_id = ql.quote_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000003'
AND qlc.deleted = false
AND qlc.source = 'configured_component'
AND mo.deleted = false
ORDER BY qlc.component_role
LIMIT 50;

-- Step 3: Show SalesOrderLines details
SELECT 
    'SalesOrderLines Details' as section,
    sol.id as sale_order_line_id,
    sol.line_number,
    sol.quote_line_id,
    sol.product_type,
    EXISTS(
        SELECT 1 FROM "BomInstances" bi 
        WHERE bi.sale_order_line_id = sol.id 
        AND bi.deleted = false
    ) as has_bom_instance
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000003'
AND sol.deleted = false
AND mo.deleted = false
ORDER BY sol.line_number;


