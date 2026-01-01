-- ====================================================
-- Script: Verify Block Condition Matching for SO-000010
-- ====================================================
-- This script simulates block_condition matching with the actual QuoteLine configuration
-- ====================================================

-- Step 1: Get QuoteLine configuration
WITH quote_line_config AS (
    SELECT 
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
        bc.organization_id,
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
    'Step 1: Block Condition Matching Simulation' as check_type,
    bc.component_role,
    bc.sku,
    bc.item_name,
    bc.block_condition,
    bc.applies_color,
    bc.auto_select,
    bc.organization_id as component_org_id,
    qlc.drive_type as config_drive_type,
    qlc.bottom_rail_type as config_bottom_rail_type,
    qlc.cassette as config_cassette,
    qlc.side_channel as config_side_channel,
    qlc.hardware_color as config_hardware_color,
    -- Simulate matching logic (same as function)
    CASE 
        WHEN bc.component_role LIKE '%fabric%' THEN '✅ Always included (fabric)'
        WHEN bc.auto_select = true THEN '✅ Auto-select (no condition)'
        WHEN bc.block_condition IS NULL THEN '✅ No condition (always included)'
        WHEN bc.block_condition::text = '{}' THEN '✅ Empty condition (always included)'
        -- Check drive_type
        WHEN bc.block_condition ? 'drive_type' AND (bc.block_condition->>'drive_type') = qlc.drive_type THEN '✅ Drive type matches'
        WHEN bc.block_condition ? 'drive_type' AND (bc.block_condition->>'drive_type') != qlc.drive_type THEN '❌ Drive type does NOT match'
        -- Check bottom_rail_type
        WHEN bc.block_condition ? 'bottom_rail_type' AND (bc.block_condition->>'bottom_rail_type') = qlc.bottom_rail_type THEN '✅ Bottom rail type matches'
        WHEN bc.block_condition ? 'bottom_rail_type' AND (bc.block_condition->>'bottom_rail_type') != qlc.bottom_rail_type THEN '❌ Bottom rail type does NOT match'
        -- Check cassette (note: function uses 'casette' with one 's' - this is a bug!)
        WHEN bc.block_condition ? 'cassette' AND (bc.block_condition->>'cassette')::boolean = qlc.cassette THEN '✅ Cassette matches'
        WHEN bc.block_condition ? 'cassette' AND (bc.block_condition->>'cassette')::boolean != qlc.cassette THEN '❌ Cassette does NOT match'
        WHEN bc.block_condition ? 'casette' AND (bc.block_condition->>'casette')::boolean = qlc.cassette THEN '⚠️ Cassette matches (typo: casette)'
        WHEN bc.block_condition ? 'casette' AND (bc.block_condition->>'casette')::boolean != qlc.cassette THEN '❌ Cassette does NOT match (typo: casette)'
        -- Check side_channel
        WHEN bc.block_condition ? 'side_channel' AND (bc.block_condition->>'side_channel')::boolean = qlc.side_channel THEN '✅ Side channel matches'
        WHEN bc.block_condition ? 'side_channel' AND (bc.block_condition->>'side_channel')::boolean != qlc.side_channel THEN '❌ Side channel does NOT match'
        ELSE '❌ Condition does NOT match'
    END as match_status,
    -- Check organization_id match
    CASE 
        WHEN bc.organization_id IS NULL THEN '⚠️ organization_id is NULL'
        WHEN bc.organization_id = (SELECT organization_id FROM quote_line_config qlc2 INNER JOIN "QuoteLines" ql2 ON ql2.id = qlc2.quote_line_id LIMIT 1) THEN '✅ organization_id matches'
        ELSE '❌ organization_id does NOT match'
    END as org_match_status
FROM bom_components bc
CROSS JOIN quote_line_config qlc
ORDER BY 
    CASE WHEN bc.component_role LIKE '%fabric%' THEN 0 ELSE 1 END,
    bc.component_role;

-- Step 2: Check if components have organization_id
SELECT 
    'Step 2: Component organization_id Check' as check_type,
    bc.component_role,
    bc.organization_id,
    ql.organization_id as quote_line_org_id,
    CASE 
        WHEN bc.organization_id IS NULL THEN '❌ NULL - Will be filtered out!'
        WHEN bc.organization_id = ql.organization_id THEN '✅ Matches'
        ELSE '❌ Does NOT match - Will be filtered out!'
    END as status
FROM "BOMComponents" bc
INNER JOIN "QuoteLines" ql ON bc.bom_template_id IN (
    SELECT id FROM "BOMTemplates" 
    WHERE product_type_id = ql.product_type_id 
    AND active = true
)
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false
AND bc.deleted = false
ORDER BY bc.component_role;

-- Step 3: Check block_condition keys (to see if they use 'casette' or 'cassette')
SELECT 
    'Step 3: Block Condition Keys' as check_type,
    bc.component_role,
    bc.block_condition,
    jsonb_object_keys(bc.block_condition) as condition_key
FROM "BOMComponents" bc
INNER JOIN "QuoteLines" ql ON bc.bom_template_id IN (
    SELECT id FROM "BOMTemplates" 
    WHERE product_type_id = ql.product_type_id 
    AND active = true
)
INNER JOIN "SaleOrderLines" sol ON sol.quote_line_id = ql.id
INNER JOIN "SaleOrders" so ON so.id = sol.sale_order_id
WHERE so.sale_order_no = 'SO-000010'
AND ql.deleted = false
AND bc.deleted = false
AND bc.block_condition IS NOT NULL
ORDER BY bc.component_role, condition_key;








