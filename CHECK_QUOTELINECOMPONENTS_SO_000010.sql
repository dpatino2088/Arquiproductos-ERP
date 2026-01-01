-- ====================================================
-- Script: Check QuoteLineComponents for SO-000010
-- ====================================================
-- This script checks all components in QuoteLineComponents for SO-000010
-- ====================================================

-- Step 1: All QuoteLineComponents for SO-000010 with categories
SELECT 
    'Step 1: All QuoteLineComponents' as check_type,
    qlc.id,
    qlc.quote_line_id,
    COALESCE(public.derive_category_code_from_role(qlc.component_role), 'unknown') as category_code,
    qlc.component_role,
    ci.sku,
    ci.item_name,
    qlc.qty,
    qlc.uom,
    qlc.unit_cost_exw,
    qlc.source,
    qlc.deleted
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000010'
ORDER BY category_code, ci.sku;

-- Step 2: Count by category
SELECT 
    'Step 2: Count by Category' as check_type,
    COALESCE(public.derive_category_code_from_role(qlc.component_role), 'unknown') as category_code,
    COUNT(*) as component_count,
    SUM(qlc.qty) as total_qty,
    STRING_AGG(DISTINCT qlc.uom, ', ' ORDER BY qlc.uom) as uoms,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) as skus
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000010'
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY category_code
ORDER BY category_code;

-- Step 3: Check if there are components with different component_role values
SELECT 
    'Step 3: Component Roles' as check_type,
    qlc.component_role,
    COUNT(*) as count,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) as sample_skus
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000010'
AND qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY qlc.component_role
ORDER BY qlc.component_role;

-- Step 4: Check QuoteLine IDs for SO-000010
SELECT 
    'Step 4: QuoteLines for SO-000010' as check_type,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.name as product_type_name,
    ql.catalog_item_id,
    ci.item_name as catalog_item_name,
    ql.drive_type,
    ql.bottom_rail_type,
    ql.cassette,
    ql.side_channel,
    ql.hardware_color
FROM "QuoteLines" ql
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "CatalogItems" ci ON ci.id = ql.catalog_item_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false;








