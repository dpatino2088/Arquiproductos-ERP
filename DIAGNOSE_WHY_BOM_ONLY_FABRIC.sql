-- ====================================================
-- Script: Diagnose Why BOM Only Generates Fabric
-- ====================================================
-- This script checks why generate_configured_bom_for_quote_line
-- only generates fabric and not other components
-- ====================================================

-- Check 1: BOMTemplate for the ProductType
SELECT 
    'BOMTemplate Check' as check_type,
    pt.name as product_type_name,
    pt.id as product_type_id,
    bt.id as bom_template_id,
    bt.name as template_name,
    bt.active,
    COUNT(bc.id) as total_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') as fabric_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%' AND bc.component_role IS NOT NULL) as other_components
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY pt.name, pt.id, bt.id, bt.name, bt.active, ql.product_type_id, ql.organization_id;

-- Check 2: BOMComponents details for the BOMTemplate
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

-- Check 3: QuoteLine configuration vs block_condition
SELECT 
    'Configuration Match' as check_type,
    ql.id as quote_line_id,
    ql.drive_type,
    ql.bottom_rail_type,
    ql.cassette,
    ql.cassette_type,
    ql.side_channel,
    ql.side_channel_type,
    ql.hardware_color,
    bc.component_role,
    bc.block_condition,
    CASE 
        WHEN bc.block_condition IS NULL THEN '✅ No condition - will always match'
        WHEN bc.block_condition->>'drive_type' IS NOT NULL 
            AND bc.block_condition->>'drive_type' != COALESCE(ql.drive_type, 'manual') THEN '❌ drive_type mismatch'
        WHEN bc.block_condition->>'bottom_rail_type' IS NOT NULL 
            AND bc.block_condition->>'bottom_rail_type' != COALESCE(ql.bottom_rail_type, 'standard') THEN '❌ bottom_rail_type mismatch'
        WHEN bc.block_condition->>'cassette' IS NOT NULL 
            AND (bc.block_condition->>'cassette')::boolean != COALESCE(ql.cassette, false) THEN '❌ cassette mismatch'
        WHEN bc.block_condition->>'side_channel' IS NOT NULL 
            AND (bc.block_condition->>'side_channel')::boolean != COALESCE(ql.side_channel, false) THEN '❌ side_channel mismatch'
        WHEN bc.block_condition->>'side_channel_type' IS NOT NULL 
            AND bc.block_condition->>'side_channel_type' != ql.side_channel_type THEN '❌ side_channel_type mismatch'
        ELSE '✅ Condition matches'
    END as match_status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY ql.id, bc.sequence_order;

-- Check 4: Components with missing component_item_id
SELECT 
    'Missing Item IDs' as check_type,
    bc.component_role,
    bc.auto_select,
    bc.sku_resolution_rule,
    COUNT(*) as count
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
AND bc.component_item_id IS NULL
AND bc.auto_select = false
GROUP BY bc.component_role, bc.auto_select, bc.sku_resolution_rule;








