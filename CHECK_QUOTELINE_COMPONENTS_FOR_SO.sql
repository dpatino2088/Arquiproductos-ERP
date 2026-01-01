-- ====================================================
-- Script: Check QuoteLineComponents for Sale Order
-- ====================================================
-- This script checks what components exist in QuoteLineComponents
-- for SO-000008 to see why they're not being copied to BomInstanceLines
-- ====================================================

-- Check 1: QuoteLineComponents for SO-000008
SELECT 
    'QuoteLineComponents for SO-000008' as check_type,
    qlc.component_role,
    qlc.source,
    qlc.uom,
    COUNT(*) as count,
    COUNT(DISTINCT qlc.quote_line_id) as quote_lines_count,
    STRING_AGG(DISTINCT ci.sku, ', ' ORDER BY ci.sku) FILTER (WHERE ci.sku IS NOT NULL) as sample_skus
FROM "QuoteLineComponents" qlc
INNER JOIN "QuoteLines" ql ON ql.id = qlc.quote_line_id
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000008'
AND qlc.deleted = false
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY qlc.component_role, qlc.source, qlc.uom
ORDER BY qlc.component_role, qlc.source;

-- Check 2: QuoteLine configuration for SO-000008
SELECT 
    'QuoteLine Configuration' as check_type,
    ql.id as quote_line_id,
    ql.product_type_id,
    ql.drive_type,
    ql.bottom_rail_type,
    ql.cassette,
    ql.cassette_type,
    ql.side_channel,
    ql.side_channel_type,
    ql.hardware_color,
    ql.width_m,
    ql.height_m,
    ql.qty
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false;

-- Check 3: Check if BOM was generated for QuoteLines
SELECT 
    'BOM Generation Check' as check_type,
    ql.id as quote_line_id,
    COUNT(qlc.id) FILTER (WHERE qlc.source = 'configured_component') as configured_components,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role = 'fabric') as fabric_components,
    COUNT(qlc.id) FILTER (WHERE qlc.component_role != 'fabric' AND qlc.source = 'configured_component') as other_components
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id AND qlc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY ql.id;

-- Check 4: Check BOMTemplate for the ProductType
SELECT 
    'BOMTemplate Check' as check_type,
    pt.name as product_type_name,
    bt.name as template_name,
    bt.active,
    COUNT(bc.id) as component_count
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id AND bt.organization_id = ql.organization_id AND bt.deleted = false
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY pt.name, bt.name, bt.active, ql.product_type_id, ql.organization_id;

