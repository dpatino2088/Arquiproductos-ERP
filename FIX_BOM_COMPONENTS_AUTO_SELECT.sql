-- ========================================
-- FIX: Add sku_resolution_rule to Components with auto_select
-- ========================================
-- This script fixes components that have auto_select=true but no sku_resolution_rule
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

DO $$
DECLARE
  v_bom_template_id uuid;
  v_updated_count integer;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'FIXING BOMComponents with Missing sku_resolution_rule';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Get BOMTemplate ID from Sale Order
  SELECT bt.id INTO v_bom_template_id
  FROM "SaleOrders" so
    INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
    INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
    INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
      AND bt.organization_id = ql.organization_id
      AND bt.deleted = false
      AND bt.active = true
  WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
    AND so.deleted = false
  LIMIT 1;

  IF v_bom_template_id IS NULL THEN
    RAISE EXCEPTION 'No BOMTemplate found for Sale Order SO-000003';
  END IF;

  RAISE NOTICE '✅ Found BOMTemplate ID: %', v_bom_template_id;
  RAISE NOTICE '';

  -- Fix tube component
  UPDATE "BOMComponents"
  SET 
    sku_resolution_rule = 'width_rule_42_65_80',
    updated_at = NOW()
  WHERE bom_template_id = v_bom_template_id
    AND component_role = 'tube'
    AND auto_select = true
    AND sku_resolution_rule IS NULL
    AND deleted = false;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed tube component: Added sku_resolution_rule = width_rule_42_65_80';
  END IF;

  -- Fix bottom_bar component
  UPDATE "BOMComponents"
  SET 
    sku_resolution_rule = 'direct',
    updated_at = NOW()
  WHERE bom_template_id = v_bom_template_id
    AND component_role = 'bottom_bar'
    AND auto_select = true
    AND sku_resolution_rule IS NULL
    AND deleted = false;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed bottom_bar component: Added sku_resolution_rule = direct';
  END IF;

  -- Fix side_channel_profile component
  UPDATE "BOMComponents"
  SET 
    sku_resolution_rule = 'direct',
    updated_at = NOW()
  WHERE bom_template_id = v_bom_template_id
    AND component_role = 'side_channel_profile'
    AND auto_select = true
    AND sku_resolution_rule IS NULL
    AND deleted = false;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed side_channel_profile component: Added sku_resolution_rule = direct';
  END IF;

  -- Fix cassette component
  UPDATE "BOMComponents"
  SET 
    sku_resolution_rule = 'direct',
    updated_at = NOW()
  WHERE bom_template_id = v_bom_template_id
    AND component_role = 'cassette'
    AND auto_select = true
    AND sku_resolution_rule IS NULL
    AND deleted = false;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed cassette component: Added sku_resolution_rule = direct';
  END IF;

  -- Fix bracket with cassette:true
  UPDATE "BOMComponents"
  SET 
    sku_resolution_rule = 'direct',
    updated_at = NOW()
  WHERE bom_template_id = v_bom_template_id
    AND component_role = 'bracket'
    AND auto_select = true
    AND sku_resolution_rule IS NULL
    AND block_condition->>'cassette' = 'true'
    AND deleted = false;

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Fixed bracket (cassette:true) component: Added sku_resolution_rule = direct';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✨ FIX COMPLETED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Next steps:';
  RAISE NOTICE '1. Re-configure the QuoteLine in the UI to regenerate BOM';
  RAISE NOTICE '2. Run CHECK_BOM_GENERATED.sql again to verify';
  RAISE NOTICE '';

END $$;

-- Verification: Show fixed components
SELECT 
  'Verification: Fixed Components' as check_name,
  bc.component_role,
  bc.auto_select,
  bc.sku_resolution_rule,
  CASE 
    WHEN bc.auto_select = true AND bc.sku_resolution_rule IS NULL THEN '❌ STILL MISSING'
    WHEN bc.auto_select = true AND bc.sku_resolution_rule IS NOT NULL THEN '✅ FIXED'
    ELSE 'ℹ️ N/A'
  END as status
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id 
    AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
  AND bc.auto_select = true
  AND bc.component_role IN ('tube', 'bottom_bar', 'side_channel_profile', 'cassette', 'bracket')
ORDER BY bc.component_role;








