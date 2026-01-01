-- ====================================================
-- Migration 343: Check QuoteLineComponents for MO-000003
-- ====================================================
-- Check if QuoteLineComponents exist for the QuoteLine related to MO-000003
-- ====================================================

-- Get Quote ID from MO
WITH mo_info AS (
    SELECT 
        mo.id as mo_id,
        mo.manufacturing_order_no,
        so.quote_id,
        sol.id as sale_order_line_id,
        sol.quote_line_id
    FROM "ManufacturingOrders" mo
    INNER JOIN "SalesOrders" so ON so.id = mo.sale_order_id AND so.deleted = false
    INNER JOIN "SalesOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
    WHERE mo.manufacturing_order_no = 'MO-000003'
    AND mo.deleted = false
    LIMIT 1
)
-- Check QuoteLineComponents
SELECT 
    'QuoteLineComponents Check' as check_type,
    (SELECT quote_id FROM mo_info) as quote_id,
    (SELECT quote_line_id FROM mo_info) as quote_line_id,
    COUNT(*) as total_quote_line_components,
    COUNT(*) FILTER (WHERE qlc.source = 'configured_component' AND qlc.deleted = false) as configured_components,
    COUNT(*) FILTER (WHERE qlc.catalog_item_id IS NULL) as components_without_catalog_item
FROM "QuoteLineComponents" qlc
WHERE qlc.quote_line_id = (SELECT quote_line_id FROM mo_info)
OR qlc.quote_line_id IN (
    SELECT ql.id 
    FROM "QuoteLines" ql 
    WHERE ql.quote_id = (SELECT quote_id FROM mo_info)
);

-- Show all QuoteLineComponents for this Quote
SELECT 
    qlc.id,
    qlc.quote_line_id,
    qlc.component_role,
    qlc.catalog_item_id,
    qlc.source,
    qlc.deleted,
    qlc.qty,
    qlc.uom,
    ci.sku,
    ci.item_name
FROM "QuoteLineComponents" qlc
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "SalesOrders" so ON so.quote_id = ql.quote_id
INNER JOIN "ManufacturingOrders" mo ON mo.sale_order_id = so.id
WHERE mo.manufacturing_order_no = 'MO-000003'
AND mo.deleted = false
ORDER BY qlc.component_role;


