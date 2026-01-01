-- ====================================================
-- Check Why No BOM Lines for SO-025080
-- ====================================================

-- Step 1: Check BomInstance
SELECT 
    'Step 1: BomInstance' as step,
    bi.id,
    bi.sale_order_line_id,
    bi.quote_line_id,
    bi.organization_id
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-025080'
AND bi.deleted = false;

-- Step 2: Check QuoteLine from SalesOrderLine
SELECT 
    'Step 2: QuoteLine from SalesOrderLine' as step,
    sol.id as sale_order_line_id,
    sol.quote_line_id
FROM "SalesOrderLines" sol
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-025080'
AND sol.deleted = false;

-- Step 3: Check QuoteLineComponents count
SELECT 
    'Step 3: QuoteLineComponents Count' as step,
    COUNT(*) as count
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = COALESCE(bi.quote_line_id, sol.quote_line_id)
WHERE so.sale_order_no = 'SO-025080'
AND bi.deleted = false
AND qlc.source = 'configured_component'
AND qlc.deleted = false;

-- Step 4: List all QuoteLineComponents
SELECT 
    'Step 4: QuoteLineComponents List' as step,
    qlc.id,
    qlc.quote_line_id,
    qlc.catalog_item_id,
    ci.sku,
    ci.item_name,
    qlc.component_role,
    qlc.qty,
    qlc.uom
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = COALESCE(bi.quote_line_id, sol.quote_line_id)
INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-025080'
AND bi.deleted = false
AND qlc.source = 'configured_component'
AND qlc.deleted = false
AND ci.deleted = false;

-- Step 5: Check if BomInstanceLines exist
SELECT 
    'Step 5: BomInstanceLines Count' as step,
    COUNT(*) as count
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-025080'
AND bi.deleted = false;






