-- ====================================================
-- Debug: Why BOM is not being created
-- ====================================================
-- Check each step of the BOM creation process
-- ====================================================

-- 1. Check if Quote exists and is approved
SELECT 
    q.id as quote_id,
    q.quote_no,
    q.status,
    q.organization_id,
    q.deleted as quote_deleted
FROM "Quotes" q
WHERE q.quote_no = 'QT-000001'  -- ⚠️ Change to your actual quote number
AND q.deleted = false;

-- 2. Check if SalesOrder was created
SELECT 
    so.id as sale_order_id,
    so.sale_order_no,
    so.quote_id,
    so.organization_id,
    so.deleted as so_deleted
FROM "SalesOrders" so
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false;

-- 3. Check if SalesOrderLines exist
SELECT 
    sol.id as sol_id,
    sol.sale_order_id,
    sol.quote_line_id,
    sol.product_type_id,
    sol.deleted as sol_deleted
FROM "SalesOrderLines" sol
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND sol.deleted = false;

-- 4. Check if QuoteLineComponents exist (needed for BOM creation)
SELECT 
    qlc.id,
    qlc.quote_line_id,
    qlc.catalog_item_id,
    qlc.component_role,
    qlc.qty,
    qlc.uom,
    qlc.source,
    qlc.deleted
FROM "QuoteLineComponents" qlc
JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
JOIN "Quotes" q ON q.id = ql.quote_id
WHERE q.quote_no = 'QT-000001'  -- ⚠️ Change to your actual quote number
AND qlc.deleted = false
AND ql.deleted = false
AND q.deleted = false;

-- 5. Check if BOMTemplate exists for the product type
SELECT 
    bt.id as template_id,
    bt.name as template_name,
    bt.product_type_id,
    bt.active,
    bt.deleted
FROM "BOMTemplates" bt
JOIN "SalesOrderLines" sol ON sol.product_type_id = bt.product_type_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND sol.deleted = false
AND bt.deleted = false
AND bt.active = true
LIMIT 1;

-- 6. Check if BomInstances should exist (but don't)
SELECT 
    bi.id as bom_instance_id,
    bi.sale_order_line_id,
    bi.bom_template_id,
    bi.deleted
FROM "BomInstances" bi
JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-090151'
AND so.deleted = false
AND sol.deleted = false
AND bi.deleted = false;

-- 7. Check recent logs (if available) - this might not work
-- SELECT * FROM pg_stat_statements WHERE query LIKE '%on_quote_approved%' ORDER BY calls DESC LIMIT 5;



