-- ====================================================
-- Script: Diagnose Why Only Fabric Generated for SO-000010
-- ====================================================
-- This script checks why only fabric is being generated
-- ====================================================

-- Step 1: Verify product_type_id was updated
SELECT 
    'Step 1: product_type_id Status' as check_type,
    ql.id as quote_line_id,
    ql.product_type_id,
    pt.name as product_type_name,
    CASE 
        WHEN ql.product_type_id IS NULL THEN '❌ NULL - Problem!'
        ELSE '✅ Has product_type_id'
    END as status
FROM "QuoteLines" ql
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false;

-- Step 2: Check BOMTemplate and ALL its components
SELECT 
    'Step 2: BOMTemplate Components' as check_type,
    bt.id as bom_template_id,
    bt.name as bom_template_name,
    bt.active,
    bc.id as component_id,
    bc.component_role,
    bc.component_item_id,
    bc.auto_select,
    bc.block_condition,
    bc.applies_color,
    ci.sku as component_sku,
    ci.item_name as component_name,
    CASE 
        WHEN bc.component_role LIKE '%fabric%' THEN '✅ Fabric component'
        WHEN bc.component_item_id IS NULL AND bc.auto_select = false THEN '❌ Missing component_item_id'
        WHEN bc.auto_select = true THEN '✅ Auto-select component'
        ELSE '✅ Fixed component'
    END as component_status
FROM "QuoteLines" ql
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id AND bt.active = true
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false
ORDER BY 
    CASE WHEN bc.component_role LIKE '%fabric%' THEN 0 ELSE 1 END,
    bc.component_role,
    ci.sku;

-- Step 3: Check QuoteLine configuration for block_condition matching
SELECT 
    'Step 3: QuoteLine Configuration' as check_type,
    ql.id as quote_line_id,
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
    -- Build expected block_condition values
    jsonb_build_object(
        'drive_type', ql.drive_type,
        'bottom_rail_type', ql.bottom_rail_type,
        'cassette', ql.cassette,
        'cassette_type', ql.cassette_type,
        'side_channel', ql.side_channel,
        'side_channel_type', ql.side_channel_type,
        'hardware_color', ql.hardware_color
    ) as expected_block_conditions
FROM "QuoteLines" ql
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false;

-- Step 4: Simulate block_condition matching for each component
WITH quote_line_config AS (
    SELECT 
        ql.id as quote_line_id,
        ql.drive_type,
        ql.bottom_rail_type,
        ql.cassette,
        ql.cassette_type,
        ql.side_channel,
        ql.side_channel_type,
        ql.hardware_color,
        ql.product_type_id
    FROM "QuoteLines" ql
    INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
    INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
    WHERE so.sale_order_no = 'SO-000010'
    AND ql.deleted = false
    LIMIT 1
),
bom_components AS (
    SELECT 
        bc.id as component_id,
        bc.component_role,
        bc.block_condition,
        bc.applies_color,
        bc.auto_select,
        bc.component_item_id,
        ci.sku,
        ci.item_name
    FROM "BOMComponents" bc
    INNER JOIN quote_line_config qlc ON bc.bom_template_id IN (
        SELECT id FROM "BOMTemplates" 
        WHERE product_type_id = qlc.product_type_id 
        AND active = true
    )
    LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
    WHERE bc.deleted = false
)
SELECT 
    'Step 4: Block Condition Matching Simulation' as check_type,
    bc.component_role,
    bc.sku,
    bc.item_name,
    bc.block_condition,
    bc.applies_color,
    bc.auto_select,
    qlc.drive_type as config_drive_type,
    qlc.bottom_rail_type as config_bottom_rail_type,
    qlc.cassette as config_cassette,
    qlc.side_channel as config_side_channel,
    qlc.hardware_color as config_hardware_color,
    CASE 
        WHEN bc.component_role LIKE '%fabric%' THEN '✅ Always included (fabric)'
        WHEN bc.auto_select = true THEN '✅ Auto-select (no condition)'
        WHEN bc.block_condition IS NULL THEN '✅ No condition (always included)'
        WHEN bc.block_condition::text = '{}' THEN '✅ Empty condition (always included)'
        WHEN bc.block_condition ? 'drive_type' AND (bc.block_condition->>'drive_type') = qlc.drive_type THEN '✅ Drive type matches'
        WHEN bc.block_condition ? 'bottom_rail_type' AND (bc.block_condition->>'bottom_rail_type') = qlc.bottom_rail_type THEN '✅ Bottom rail type matches'
        WHEN bc.block_condition ? 'cassette' AND (bc.block_condition->>'cassette')::boolean = qlc.cassette THEN '✅ Cassette matches'
        WHEN bc.block_condition ? 'side_channel' AND (bc.block_condition->>'side_channel')::boolean = qlc.side_channel THEN '✅ Side channel matches'
        WHEN bc.block_condition ? 'hardware_color' AND (bc.block_condition->>'hardware_color') = qlc.hardware_color THEN '✅ Hardware color matches'
        ELSE '❌ Condition does NOT match'
    END as match_status
FROM bom_components bc
CROSS JOIN quote_line_config qlc
ORDER BY 
    CASE WHEN bc.component_role LIKE '%fabric%' THEN 0 ELSE 1 END,
    bc.component_role;

-- Step 5: Check if components have component_item_id or auto_select
SELECT 
    'Step 5: Component Resolution Status' as check_type,
    bc.component_role,
    bc.component_item_id,
    bc.auto_select,
    ci.sku,
    ci.item_name,
    CASE 
        WHEN bc.component_role LIKE '%fabric%' THEN '✅ Fabric (handled separately)'
        WHEN bc.component_item_id IS NOT NULL THEN '✅ Has component_item_id'
        WHEN bc.auto_select = true THEN '✅ Auto-select (will be resolved)'
        ELSE '❌ Missing component_item_id and NOT auto_select'
    END as resolution_status
FROM "BOMComponents" bc
INNER JOIN "QuoteLines" ql ON bc.bom_template_id IN (
    SELECT id FROM "BOMTemplates" 
    WHERE product_type_id = ql.product_type_id 
    AND active = true
)
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false
AND bc.deleted = false
ORDER BY bc.component_role;








