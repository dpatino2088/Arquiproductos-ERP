-- ========================================
-- DIAGNOSTIC COMPLETE: BOM Missing Components
-- ========================================
-- This comprehensive script diagnoses ALL possible causes
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number in all queries below

-- ========================================
-- STEP 1: Sale Order and QuoteLine Configuration
-- ========================================
SELECT 
  'STEP 1: QuoteLine Configuration' as step,
  so.sale_order_no,
  ql.id as quote_line_id,
  pt.code as product_type_code,
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
    WHEN ql.drive_type IS NULL THEN '❌ MISSING: drive_type'
    WHEN ql.bottom_rail_type IS NULL THEN '❌ MISSING: bottom_rail_type'
    WHEN ql.cassette IS NULL THEN '❌ MISSING: cassette'
    WHEN ql.side_channel IS NULL THEN '❌ MISSING: side_channel'
    WHEN ql.hardware_color IS NULL THEN '❌ MISSING: hardware_color'
    ELSE '✅ OK: All config present'
  END as config_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false;

-- ========================================
-- STEP 2: BOMTemplate Existence and Components
-- ========================================
SELECT 
  'STEP 2: BOMTemplate Status' as step,
  bt.id as bom_template_id,
  bt.name as template_name,
  pt.code as product_type_code,
  bt.active,
  COUNT(bc.id) as total_components,
  COUNT(CASE WHEN bc.component_role = 'fabric' THEN 1 END) as fabric_count,
  COUNT(CASE WHEN bc.component_role = 'operating_system_drive' THEN 1 END) as drive_count,
  COUNT(CASE WHEN bc.component_role = 'tube' THEN 1 END) as tube_count,
  COUNT(CASE WHEN bc.component_role = 'bracket' THEN 1 END) as bracket_count,
  COUNT(CASE WHEN bc.component_role = 'bottom_bar' THEN 1 END) as bottom_bar_count,
  COUNT(CASE WHEN bc.component_role LIKE '%cassette%' THEN 1 END) as cassette_count,
  COUNT(CASE WHEN bc.component_role LIKE '%side_channel%' THEN 1 END) as side_channel_count,
  CASE 
    WHEN COUNT(bc.id) = 0 THEN '❌ PROBLEM: No BOMTemplate found'
    WHEN COUNT(bc.id) = 1 AND COUNT(CASE WHEN bc.component_role = 'fabric' THEN 1 END) = 1 THEN '❌ PROBLEM: Only fabric component'
    WHEN COUNT(bc.id) > 1 THEN '✅ OK: Multiple components'
    ELSE '⚠️ WARNING: Check manually'
  END as status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
  INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id 
    AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bt.id, bt.name, pt.code, bt.active;

-- ========================================
-- STEP 3: BOMComponents Detail (Resolution Status)
-- ========================================
SELECT 
  'STEP 3: BOMComponents Resolution' as step,
  bc.component_role,
  bc.block_type,
  bc.block_condition,
  bc.applies_color,
  bc.hardware_color,
  bc.auto_select,
  bc.sku_resolution_rule,
  bc.component_item_id,
  ci.sku as catalog_item_sku,
  CASE 
    WHEN bc.component_item_id IS NOT NULL THEN '✅ HAS: Direct item_id'
    WHEN bc.auto_select = true AND bc.sku_resolution_rule IS NOT NULL THEN '✅ HAS: Auto-select with rule'
    WHEN bc.component_item_id IS NULL AND (bc.auto_select = false OR bc.sku_resolution_rule IS NULL) THEN '❌ MISSING: Cannot resolve'
    ELSE '⚠️ UNKNOWN'
  END as resolution_status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id 
    AND bc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
ORDER BY 
  CASE bc.component_role
    WHEN 'fabric' THEN 1
    WHEN 'operating_system_drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_bar' THEN 5
    ELSE 99
  END,
  bc.sequence_order;

-- ========================================
-- STEP 4: QuoteLineComponents Generated
-- ========================================
SELECT 
  'STEP 4: QuoteLineComponents Generated' as step,
  qlc.component_role,
  qlc.source,
  qlc.qty,
  qlc.uom,
  ci.sku,
  ci.item_name,
  COUNT(*) as count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  LEFT JOIN "QuoteLineComponents" qlc ON qlc.quote_line_id = ql.id 
    AND qlc.source = 'configured_component' 
    AND qlc.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = qlc.catalog_item_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY qlc.component_role, qlc.source, qlc.qty, qlc.uom, ci.sku, ci.item_name
ORDER BY 
  CASE qlc.component_role
    WHEN 'fabric' THEN 1
    WHEN 'operating_system_drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_bar' THEN 5
    ELSE 99
  END;

-- ========================================
-- STEP 5: BomInstanceLines (Final BOM)
-- ========================================
SELECT 
  'STEP 5: BomInstanceLines (Final BOM)' as step,
  bil.category_code,
  bil.part_role,
  bil.qty,
  bil.uom,
  ci.sku,
  ci.item_name,
  COUNT(*) as count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "BomInstances" bi ON bi.sale_order_line_id = sol.id AND bi.deleted = false
  INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bil.category_code, bil.part_role, bil.qty, bil.uom, ci.sku, ci.item_name
ORDER BY 
  CASE bil.category_code
    WHEN 'fabric' THEN 1
    WHEN 'motor' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_rail' THEN 5
    WHEN 'cassette' THEN 6
    WHEN 'side_channel' THEN 7
    ELSE 99
  END;

-- ========================================
-- STEP 6: Block Condition Matching Simulation
-- ========================================
WITH quote_line_config AS (
  SELECT 
    ql.id as quote_line_id,
    ql.product_type_id,
    ql.organization_id,
    ql.drive_type,
    ql.bottom_rail_type,
    ql.cassette,
    ql.cassette_type,
    ql.side_channel,
    ql.side_channel_type,
    ql.hardware_color
  FROM "SaleOrders" so
    INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
    INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
    AND so.deleted = false
  LIMIT 1
),
bom_components AS (
  SELECT 
    bc.*,
    bt.id as bom_template_id
  FROM quote_line_config qlc
    INNER JOIN "BOMTemplates" bt ON bt.product_type_id = qlc.product_type_id 
      AND bt.organization_id = qlc.organization_id
      AND bt.deleted = false
      AND bt.active = true
    LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id 
      AND bc.deleted = false
)
SELECT 
  'STEP 6: Block Condition Matching' as step,
  bc.component_role,
  bc.block_type,
  bc.block_condition,
  bc.applies_color,
  bc.hardware_color as bom_hardware_color,
  qlc.drive_type as config_drive_type,
  qlc.bottom_rail_type as config_bottom_rail_type,
  qlc.cassette as config_cassette,
  qlc.cassette_type as config_cassette_type,
  qlc.side_channel as config_side_channel,
  qlc.side_channel_type as config_side_channel_type,
  qlc.hardware_color as config_hardware_color,
  CASE 
    -- Check drive_type match
    WHEN bc.block_condition->>'drive_type' IS NOT NULL 
      AND bc.block_condition->>'drive_type' != qlc.drive_type THEN '❌ BLOCKED: drive_type mismatch'
    -- Check bottom_rail_type match
    WHEN bc.block_condition->>'bottom_rail_type' IS NOT NULL 
      AND bc.block_condition->>'bottom_rail_type' != qlc.bottom_rail_type THEN '❌ BLOCKED: bottom_rail_type mismatch'
    -- Check cassette match
    WHEN bc.block_condition->>'cassette' IS NOT NULL 
      AND (bc.block_condition->>'cassette')::boolean != COALESCE(qlc.cassette, false) THEN '❌ BLOCKED: cassette mismatch'
    -- Check cassette_type match
    WHEN bc.block_condition->>'cassette_type' IS NOT NULL 
      AND (COALESCE(qlc.cassette, false) = false OR bc.block_condition->>'cassette_type' != qlc.cassette_type) THEN '❌ BLOCKED: cassette_type mismatch'
    -- Check side_channel match
    WHEN bc.block_condition->>'side_channel' IS NOT NULL 
      AND (bc.block_condition->>'side_channel')::boolean != COALESCE(qlc.side_channel, false) THEN '❌ BLOCKED: side_channel mismatch'
    -- Check side_channel_type match
    WHEN bc.block_condition->>'side_channel_type' IS NOT NULL 
      AND (COALESCE(qlc.side_channel, false) = false OR bc.block_condition->>'side_channel_type' != qlc.side_channel_type) THEN '❌ BLOCKED: side_channel_type mismatch'
    -- Check hardware_color match
    WHEN bc.applies_color = true 
      AND bc.hardware_color != qlc.hardware_color THEN '❌ BLOCKED: hardware_color mismatch'
    -- Check if component has item_id or auto_select
    WHEN bc.component_item_id IS NULL 
      AND (bc.auto_select = false OR bc.sku_resolution_rule IS NULL) THEN '❌ BLOCKED: No item_id and cannot auto-select'
    ELSE '✅ SHOULD MATCH'
  END as match_status
FROM bom_components bc
  CROSS JOIN quote_line_config qlc
ORDER BY 
  CASE 
    WHEN CASE 
      WHEN bc.block_condition->>'drive_type' IS NOT NULL 
        AND bc.block_condition->>'drive_type' != qlc.drive_type THEN '❌ BLOCKED: drive_type mismatch'
      WHEN bc.block_condition->>'bottom_rail_type' IS NOT NULL 
        AND bc.block_condition->>'bottom_rail_type' != qlc.bottom_rail_type THEN '❌ BLOCKED: bottom_rail_type mismatch'
      WHEN bc.block_condition->>'cassette' IS NOT NULL 
        AND (bc.block_condition->>'cassette')::boolean != COALESCE(qlc.cassette, false) THEN '❌ BLOCKED: cassette mismatch'
      WHEN bc.block_condition->>'cassette_type' IS NOT NULL 
        AND (COALESCE(qlc.cassette, false) = false OR bc.block_condition->>'cassette_type' != qlc.cassette_type) THEN '❌ BLOCKED: cassette_type mismatch'
      WHEN bc.block_condition->>'side_channel' IS NOT NULL 
        AND (bc.block_condition->>'side_channel')::boolean != COALESCE(qlc.side_channel, false) THEN '❌ BLOCKED: side_channel mismatch'
      WHEN bc.block_condition->>'side_channel_type' IS NOT NULL 
        AND (COALESCE(qlc.side_channel, false) = false OR bc.block_condition->>'side_channel_type' != qlc.side_channel_type) THEN '❌ BLOCKED: side_channel_type mismatch'
      WHEN bc.applies_color = true 
        AND bc.hardware_color != qlc.hardware_color THEN '❌ BLOCKED: hardware_color mismatch'
      WHEN bc.component_item_id IS NULL 
        AND (bc.auto_select = false OR bc.sku_resolution_rule IS NULL) THEN '❌ BLOCKED: No item_id and cannot auto-select'
      ELSE '✅ SHOULD MATCH'
    END = '✅ SHOULD MATCH' THEN 1
    ELSE 2
  END,
  bc.component_role;

-- ========================================
-- INTERPRETATION GUIDE
-- ========================================
-- 
-- STEP 1: If config_status shows "MISSING" → Configuration not saved correctly
-- STEP 2: If status shows "Only fabric component" → BOMTemplate is incomplete
-- STEP 3: If resolution_status shows "MISSING" → BOMComponents need component_item_id or auto_select
-- STEP 4: If only 'fabric' appears → generate_configured_bom_for_quote_line only generated fabrics
-- STEP 5: If only 'fabric' appears → Final BOM only has fabrics (expected if STEP 4 only has fabrics)
-- STEP 6: If most show "BLOCKED" → Block conditions are too restrictive or config doesn't match
--
-- ========================================

