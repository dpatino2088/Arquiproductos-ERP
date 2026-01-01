-- ====================================================
-- Script: Fix BOMTemplate for Independent Side Channel and Bottom Rail
-- ====================================================
-- Problem: Side Channel and Bottom Rail are INDEPENDENT options
-- Solution: Use ONE base template with block_condition to filter components
-- ====================================================
-- 
-- The correct approach:
-- - ONE template for "Roller Shade" ProductType
-- - All components in that template
-- - Use block_condition to activate components based on QuoteLine config:
--   * Bottom Rail components: block_condition = {"bottom_rail_type": "standard"} or {"bottom_rail_type": "wrapped"}
--   * Side Channel components: block_condition = {"side_channel": true}
--   * Components without block_condition: always included (tube, motor, etc.)
-- ====================================================

-- Step 1: Check current BOMTemplate structure
SELECT 
    'Step 1: Current BOMTemplate Components' as check_type,
    bt.name as template_name,
    bc.component_role,
    bc.block_type,
    bc.block_condition,
    bc.component_item_id,
    bc.auto_select,
    ci.sku,
    CASE 
        WHEN bc.block_condition IS NULL THEN 'Always included'
        WHEN bc.block_condition->>'bottom_rail_type' IS NOT NULL THEN 'Bottom Rail conditional'
        WHEN bc.block_condition->>'side_channel' IS NOT NULL THEN 'Side Channel conditional'
        ELSE 'Other conditional'
    END as condition_type
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE bt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
AND bt.name = 'SIDE_CHANNEL_WITH_BOTTOM_RAIL'
AND bt.deleted = false
AND bt.active = true
ORDER BY bc.sequence_order, bc.component_role;

-- Step 2: Verify block_condition logic for Bottom Rail components
SELECT 
    'Step 2: Bottom Rail Components Block Conditions' as check_type,
    bc.component_role,
    bc.block_condition,
    CASE 
        WHEN bc.block_condition IS NULL THEN '❌ Missing block_condition (will always be included)'
        WHEN bc.block_condition->>'bottom_rail_type' IS NOT NULL THEN '✅ Has bottom_rail_type condition'
        ELSE '⚠️ Has other condition'
    END as status
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
AND bt.name = 'SIDE_CHANNEL_WITH_BOTTOM_RAIL'
AND bt.deleted = false
AND bt.active = true
AND (bc.component_role LIKE '%bottom%rail%' OR bc.component_role LIKE '%bottom_rail%' OR bc.component_role LIKE '%bottom%channel%')
ORDER BY bc.component_role;

-- Step 3: Verify block_condition logic for Side Channel components
SELECT 
    'Step 3: Side Channel Components Block Conditions' as check_type,
    bc.component_role,
    bc.block_condition,
    CASE 
        WHEN bc.block_condition IS NULL THEN '❌ Missing block_condition (will always be included)'
        WHEN bc.block_condition->>'side_channel' IS NOT NULL THEN '✅ Has side_channel condition'
        ELSE '⚠️ Has other condition'
    END as status
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
AND bt.name = 'SIDE_CHANNEL_WITH_BOTTOM_RAIL'
AND bt.deleted = false
AND bt.active = true
AND (bc.component_role LIKE '%side%channel%' OR bc.component_role LIKE '%side_channel%')
ORDER BY bc.component_role;

-- Step 4: Check QuoteLine configuration for SO-000008
SELECT 
    'Step 4: QuoteLine Configuration' as check_type,
    ql.id as quote_line_id,
    ql.side_channel,
    ql.side_channel_type,
    ql.bottom_rail_type,
    ql.drive_type,
    ql.cassette,
    ql.hardware_color,
    CASE 
        WHEN ql.side_channel = true AND ql.bottom_rail_type IS NOT NULL THEN 'Both Side Channel and Bottom Rail'
        WHEN ql.side_channel = true THEN 'Only Side Channel'
        WHEN ql.bottom_rail_type IS NOT NULL THEN 'Only Bottom Rail'
        ELSE 'Neither Side Channel nor Bottom Rail'
    END as configuration_type
FROM "QuoteLines" ql
INNER JOIN "Quotes" q ON q.id = ql.quote_id
INNER JOIN "SaleOrders" so ON so.quote_id = q.id
WHERE so.sale_order_no = 'SO-000008'
AND ql.deleted = false
AND q.deleted = false
AND so.deleted = false;

-- Step 5: FIX - Update block_condition for Bottom Rail components to be independent
DO $$
DECLARE
    v_updated_count integer := 0;
BEGIN
    RAISE NOTICE '🔧 Step 5: Fixing block_condition for Bottom Rail components...';
    RAISE NOTICE '';
    
    -- Update Bottom Rail components to have block_condition based on bottom_rail_type
    -- These should be independent of side_channel
    UPDATE "BOMComponents" bc
    SET block_condition = jsonb_build_object('bottom_rail_type', 'standard'),
        updated_at = NOW()
    FROM "BOMTemplates" bt
    WHERE bc.bom_template_id = bt.id
    AND bt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
    AND bt.name = 'SIDE_CHANNEL_WITH_BOTTOM_RAIL'
    AND bt.deleted = false
    AND bt.active = true
    AND bc.deleted = false
    AND (bc.component_role LIKE '%bottom%rail%' OR bc.component_role LIKE '%bottom_rail%' OR bc.component_role LIKE '%bottom%channel%')
    AND bc.component_role NOT LIKE '%side%'
    AND (bc.block_condition IS NULL OR bc.block_condition->>'side_channel' IS NOT NULL);
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Updated % Bottom Rail components', v_updated_count;
    
    -- Update Side Channel components to have block_condition based on side_channel only
    -- These should be independent of bottom_rail_type
    UPDATE "BOMComponents" bc
    SET block_condition = jsonb_build_object('side_channel', true),
        updated_at = NOW()
    FROM "BOMTemplates" bt
    WHERE bc.bom_template_id = bt.id
    AND bt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
    AND bt.name = 'SIDE_CHANNEL_WITH_BOTTOM_RAIL'
    AND bt.deleted = false
    AND bt.active = true
    AND bc.deleted = false
    AND (bc.component_role LIKE '%side%channel%' OR bc.component_role LIKE '%side_channel%')
    AND bc.component_role NOT LIKE '%bottom%'
    AND (bc.block_condition IS NULL OR bc.block_condition->>'bottom_rail_type' IS NOT NULL);
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '  ✅ Updated % Side Channel components', v_updated_count;
    
    RAISE NOTICE '';
    RAISE NOTICE '✨ Fix completed!';
END $$;

-- Step 6: Verify fixed block_conditions
SELECT 
    'Step 6: Fixed Block Conditions' as check_type,
    bc.component_role,
    bc.block_condition,
    CASE 
        WHEN bc.component_role LIKE '%bottom%rail%' OR bc.component_role LIKE '%bottom_rail%' THEN
            CASE 
                WHEN bc.block_condition->>'bottom_rail_type' IS NOT NULL THEN '✅ Independent (bottom_rail_type only)'
                WHEN bc.block_condition->>'side_channel' IS NOT NULL THEN '❌ Wrong (has side_channel condition)'
                ELSE '⚠️ No condition'
            END
        WHEN bc.component_role LIKE '%side%channel%' OR bc.component_role LIKE '%side_channel%' THEN
            CASE 
                WHEN bc.block_condition->>'side_channel' IS NOT NULL THEN '✅ Independent (side_channel only)'
                WHEN bc.block_condition->>'bottom_rail_type' IS NOT NULL THEN '❌ Wrong (has bottom_rail_type condition)'
                ELSE '⚠️ No condition'
            END
        ELSE 'N/A'
    END as status
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6'
AND bt.name = 'SIDE_CHANNEL_WITH_BOTTOM_RAIL'
AND bt.deleted = false
AND bt.active = true
ORDER BY bc.sequence_order, bc.component_role;








