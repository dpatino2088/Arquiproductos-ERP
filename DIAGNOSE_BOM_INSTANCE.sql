-- ====================================================
-- Diagnostic Script for BomInstance MO-000001 / SO-025080
-- ====================================================

-- Step 1: Check BomInstance details
SELECT 
    'Step 1: BomInstance Details' as step,
    bi.id as bom_instance_id,
    bi.sale_order_line_id,
    bi.quote_line_id,
    bi.organization_id,
    bi.status,
    bi.created_at
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-025080'
AND bi.deleted = false;

-- Step 2: Check if QuoteLine exists and has product_type_id
SELECT 
    'Step 2: QuoteLine Details' as step,
    ql.id as quote_line_id,
    ql.product_type_id,
    ql.organization_id,
    ql.drive_type,
    ql.bottom_rail_type,
    ql.cassette,
    ql.side_channel,
    ql.width_m,
    ql.height_m,
    ql.qty
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "QuoteLines" ql ON ql.id = bi.quote_line_id
WHERE so.sale_order_no = 'SO-025080'
AND bi.deleted = false;

-- Step 3: Check if QuoteLineComponents exist
SELECT 
    'Step 3: QuoteLineComponents Count' as step,
    COUNT(*) as component_count
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = bi.quote_line_id
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
    qlc.uom,
    qlc.source
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
INNER JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = bi.quote_line_id
INNER JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-025080'
AND bi.deleted = false
AND qlc.source = 'configured_component'
AND qlc.deleted = false
AND ci.deleted = false;

-- Step 5: Check BomInstanceLines
SELECT 
    'Step 5: BomInstanceLines Count' as step,
    COUNT(*) as bom_line_count
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
INNER JOIN "SalesOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE so.sale_order_no = 'SO-025080'
AND bi.deleted = false;

-- Step 6: Check if functions exist
SELECT 
    'Step 6: Function Check' as step,
    proname as function_name,
    CASE 
        WHEN proname = 'generate_configured_bom_for_quote_line' THEN '✅ Exists'
        WHEN proname = 'normalize_uom_to_canonical' THEN '✅ Exists'
        WHEN proname = 'get_unit_cost_in_uom' THEN '✅ Exists'
        WHEN proname = 'derive_category_code_from_role' THEN '✅ Exists'
        ELSE '❌ Unknown'
    END as status
FROM pg_proc
WHERE proname IN (
    'generate_configured_bom_for_quote_line',
    'normalize_uom_to_canonical',
    'get_unit_cost_in_uom',
    'derive_category_code_from_role'
)
AND pronamespace = 'public'::regnamespace;






