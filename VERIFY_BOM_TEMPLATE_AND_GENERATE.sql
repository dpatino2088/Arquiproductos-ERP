-- ====================================================
-- Script: Verify BOMTemplate and Force BOM Generation
-- ====================================================
-- This script verifies if BOMTemplate exists and forces BOM generation
-- ====================================================

-- Step 1: Check ProductType and BOMTemplate for SO-000008
SELECT 
    'ProductType & BOMTemplate Check' as check_type,
    pt.name as product_type_name,
    pt.id as product_type_id,
    ql.organization_id,
    ql.product_type_id as quote_line_product_type_id,
    bt.id as bom_template_id,
    bt.name as template_name,
    bt.active,
    bt.product_type_id as bom_template_product_type_id,
    COUNT(bc.id) as component_count,
    COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') as fabric_count,
    COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%' AND bc.component_role IS NOT NULL) as other_count,
    CASE 
        WHEN ql.product_type_id IS NULL THEN '❌ QuoteLine has NO product_type_id'
        WHEN pt.id IS NULL THEN '❌ ProductType NOT FOUND in ProductTypes table'
        WHEN bt.id IS NULL THEN '❌ NO BOMTemplate found for this product_type_id'
        WHEN bt.active = false THEN '⚠️ BOMTemplate INACTIVE'
        WHEN COUNT(bc.id) = 0 THEN '❌ BOMTemplate has NO components'
        WHEN COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') = COUNT(bc.id) THEN '❌ BOMTemplate ONLY has fabric'
        ELSE '✅ BOMTemplate OK'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id AND pt.organization_id = ql.organization_id AND pt.deleted = false
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY pt.name, pt.id, ql.organization_id, ql.product_type_id, bt.id, bt.name, bt.active, bt.product_type_id;

-- Step 2: Show all BOMComponents for the BOMTemplate
SELECT 
    'BOMComponents Details' as check_type,
    bc.component_role,
    bc.block_type,
    bc.block_condition,
    bc.component_item_id,
    bc.auto_select,
    bc.applies_color,
    ci.sku,
    ci.item_name,
    bc.qty_per_unit,
    bc.uom
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY bc.sequence_order, bc.component_role;

-- Step 3: QuoteLine configuration
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

