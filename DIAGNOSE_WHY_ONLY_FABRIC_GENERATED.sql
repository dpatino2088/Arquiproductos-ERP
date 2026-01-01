-- ====================================================
-- Script: Diagnose Why Only Fabric is Generated
-- ====================================================
-- This script checks all the conditions that could cause
-- only fabric to be generated in the BOM
-- ====================================================

-- Step 1: Check QuoteLine configuration
SELECT 
    'Step 1: QuoteLine Configuration' as check_type,
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
    ql.qty,
    CASE 
        WHEN ql.product_type_id IS NULL THEN '❌ MISSING: product_type_id'
        WHEN ql.drive_type IS NULL THEN '❌ MISSING: drive_type'
        WHEN ql.bottom_rail_type IS NULL THEN '❌ MISSING: bottom_rail_type'
        WHEN ql.side_channel IS NULL THEN '❌ MISSING: side_channel'
        WHEN ql.hardware_color IS NULL THEN '❌ MISSING: hardware_color'
        ELSE '✅ OK: All config fields present'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false;

-- Step 2: Check BOMTemplate for this ProductType
SELECT 
    'Step 2: BOMTemplate Check' as check_type,
    bt.id as template_id,
    bt.name as template_name,
    bt.product_type_id,
    bt.active,
    pt.name as product_type_name,
    COUNT(bc.id) as total_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role LIKE '%fabric%') as fabric_components,
    COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%') as non_fabric_components,
    CASE 
        WHEN bt.id IS NULL THEN '❌ NO TEMPLATE FOUND'
        WHEN bt.active = false THEN '❌ TEMPLATE NOT ACTIVE'
        WHEN COUNT(bc.id) FILTER (WHERE bc.component_role NOT LIKE '%fabric%') = 0 THEN '❌ NO NON-FABRIC COMPONENTS'
        ELSE '✅ OK: Template has non-fabric components'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
GROUP BY bt.id, bt.name, bt.product_type_id, bt.active, pt.name;

-- Step 3: Check BOMComponents and their block_conditions
SELECT 
    'Step 3: BOMComponents Block Conditions' as check_type,
    bc.component_role,
    bc.block_type,
    bc.block_condition,
    bc.applies_color,
    bc.auto_select,
    bc.component_item_id,
    ci.sku,
    CASE 
        WHEN bc.component_role LIKE '%fabric%' THEN 'Fabric (always included)'
        WHEN bc.block_condition IS NULL THEN 'Always included (no condition)'
        WHEN bc.block_condition->>'drive_type' IS NOT NULL THEN 'Condition: drive_type'
        WHEN bc.block_condition->>'bottom_rail_type' IS NOT NULL THEN 'Condition: bottom_rail_type'
        WHEN bc.block_condition->>'side_channel' IS NOT NULL THEN 'Condition: side_channel'
        WHEN bc.block_condition->>'cassette' IS NOT NULL THEN 'Condition: cassette'
        ELSE 'Other condition'
    END as condition_type
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY 
    CASE WHEN bc.component_role LIKE '%fabric%' THEN 1 ELSE 2 END,
    bc.sequence_order;

-- Step 4: Simulate block_condition matching for each component
SELECT 
    'Step 4: Block Condition Matching Simulation' as check_type,
    bc.component_role,
    bc.block_condition,
    ql.drive_type as ql_drive_type,
    ql.bottom_rail_type as ql_bottom_rail_type,
    ql.side_channel as ql_side_channel,
    ql.side_channel_type as ql_side_channel_type,
    ql.cassette as ql_cassette,
    ql.hardware_color as ql_hardware_color,
    CASE 
        WHEN bc.component_role LIKE '%fabric%' THEN '✅ MATCH (fabric always included)'
        WHEN bc.block_condition IS NULL THEN '✅ MATCH (no condition)'
        WHEN bc.block_condition->>'drive_type' IS NOT NULL AND bc.block_condition->>'drive_type' != COALESCE(ql.drive_type, '') THEN '❌ NO MATCH: drive_type'
        WHEN bc.block_condition->>'bottom_rail_type' IS NOT NULL AND bc.block_condition->>'bottom_rail_type' != COALESCE(ql.bottom_rail_type, '') THEN '❌ NO MATCH: bottom_rail_type'
        WHEN bc.block_condition->>'side_channel' IS NOT NULL AND (bc.block_condition->>'side_channel')::boolean != COALESCE(ql.side_channel, false) THEN '❌ NO MATCH: side_channel'
        WHEN bc.block_condition->>'side_channel_type' IS NOT NULL AND bc.block_condition->>'side_channel_type' != COALESCE(ql.side_channel_type, '') THEN '❌ NO MATCH: side_channel_type'
        WHEN bc.block_condition->>'cassette' IS NOT NULL AND (bc.block_condition->>'cassette')::boolean != COALESCE(ql.cassette, false) THEN '❌ NO MATCH: cassette'
        ELSE '✅ MATCH'
    END as match_status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
ORDER BY 
    CASE WHEN bc.component_role LIKE '%fabric%' THEN 1 ELSE 2 END,
    bc.sequence_order;

-- Step 5: Check if components have component_item_id
SELECT 
    'Step 5: BOMComponents Item ID Check' as check_type,
    bc.component_role,
    bc.component_item_id,
    bc.auto_select,
    ci.sku,
    ci.item_name,
    CASE 
        WHEN bc.component_role LIKE '%fabric%' THEN 'N/A (fabric handled separately)'
        WHEN bc.component_item_id IS NOT NULL THEN '✅ Has item_id'
        WHEN bc.auto_select = true THEN '✅ Auto-select (will resolve)'
        ELSE '❌ MISSING: No item_id and not auto_select'
    END as status
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id 
    AND bt.deleted = false
    AND bt.active = true
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE so.sale_order_no IN ('SO-000008', '50-000008')
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false
AND bc.component_role NOT LIKE '%fabric%'
ORDER BY bc.sequence_order;








