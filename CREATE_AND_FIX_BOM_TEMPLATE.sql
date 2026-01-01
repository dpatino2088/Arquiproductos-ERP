-- ========================================
-- CREATE AND FIX: BOMTemplate Complete Solution
-- ========================================
-- This script:
-- 1. Verifies Sale Order exists
-- 2. Creates BOMTemplate if it doesn't exist
-- 3. Activates it if it's inactive
-- 4. Adds missing components
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

DO $$
DECLARE
  v_sale_order_id uuid;
  v_quote_line_id uuid;
  v_product_type_id uuid;
  v_product_type_code text;
  v_product_type_name text;
  v_organization_id uuid;
  v_bom_template_id uuid;
  v_bom_template_active boolean;
  v_updated_count integer;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'CREATING AND FIXING BOMTemplate';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';

  -- Step 1: Verify Sale Order exists and get QuoteLine info
  SELECT 
    so.id,
    ql.id,
    ql.product_type_id,
    pt.code,
    pt.name,
    ql.organization_id
  INTO 
    v_sale_order_id,
    v_quote_line_id,
    v_product_type_id,
    v_product_type_code,
    v_product_type_name,
    v_organization_id
  FROM "SaleOrders" so
    INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
    INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
    LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
  WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
    AND so.deleted = false
  LIMIT 1;

  IF v_sale_order_id IS NULL THEN
    RAISE EXCEPTION 'Sale Order SO-000003 not found. Please check the Sale Order number.';
  END IF;

  IF v_product_type_id IS NULL THEN
    RAISE EXCEPTION 'QuoteLine is missing product_type_id. Cannot proceed.';
  END IF;

  RAISE NOTICE '✅ Sale Order found: %', v_sale_order_id;
  RAISE NOTICE '✅ Quote Line ID: %', v_quote_line_id;
  RAISE NOTICE '✅ Product Type: % (%)', v_product_type_name, v_product_type_code;
  RAISE NOTICE '✅ Organization ID: %', v_organization_id;
  RAISE NOTICE '';

  -- Step 2: Check if BOMTemplate exists (active or inactive)
  SELECT 
    bt.id,
    bt.active
  INTO 
    v_bom_template_id,
    v_bom_template_active
  FROM "BOMTemplates" bt
  WHERE bt.product_type_id = v_product_type_id 
    AND bt.organization_id = v_organization_id
    AND bt.deleted = false
  ORDER BY bt.active DESC, bt.created_at DESC
  LIMIT 1;

  -- Step 3: Create or activate BOMTemplate
  IF v_bom_template_id IS NULL THEN
    RAISE NOTICE '⚠️  No BOMTemplate found. Creating new one...';
    
    INSERT INTO "BOMTemplates" (
      organization_id,
      product_type_id,
      name,
      active,
      deleted
    )
    VALUES (
      v_organization_id,
      v_product_type_id,
      'BOM Template - ' || COALESCE(v_product_type_name, v_product_type_code),
      true,
      false
    )
    RETURNING id INTO v_bom_template_id;
    
    RAISE NOTICE '✅ Created BOMTemplate with ID: %', v_bom_template_id;
  ELSE
    IF v_bom_template_active = false THEN
      RAISE NOTICE '⚠️  BOMTemplate exists but is inactive. Activating...';
      UPDATE "BOMTemplates"
      SET active = true, updated_at = NOW()
      WHERE id = v_bom_template_id;
      RAISE NOTICE '✅ Activated BOMTemplate';
    ELSE
      RAISE NOTICE '✅ BOMTemplate already exists and is active: %', v_bom_template_id;
    END IF;
  END IF;

  RAISE NOTICE '';

  -- Step 4: Add missing components
  RAISE NOTICE 'Adding missing BOMComponents...';
  RAISE NOTICE '';

  -- Add operating_system_drive component (if missing)
  INSERT INTO "BOMComponents" (
    organization_id,
    bom_template_id,
    component_role,
    block_type,
    block_condition,
    applies_color,
    hardware_color,
    component_item_id,
    auto_select,
    sku_resolution_rule,
    qty_per_unit,
    uom,
    sequence_order
  )
  SELECT 
    v_organization_id,
    v_bom_template_id,
    'operating_system_drive',
    'drive',
    jsonb_build_object('drive_type', 'motor'),
    true,
    'white',
    NULL,
    false,
    NULL,
    1,
    'ea',
    10
  WHERE NOT EXISTS (
    SELECT 1 FROM "BOMComponents" bc
    WHERE bc.bom_template_id = v_bom_template_id
      AND bc.component_role = 'operating_system_drive'
      AND bc.deleted = false
  );

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Added operating_system_drive component';
  ELSE
    RAISE NOTICE 'ℹ️  operating_system_drive component already exists';
  END IF;

  -- Add tube component (if missing)
  INSERT INTO "BOMComponents" (
    organization_id,
    bom_template_id,
    component_role,
    block_type,
    block_condition,
    applies_color,
    hardware_color,
    component_item_id,
    auto_select,
    sku_resolution_rule,
    qty_per_unit,
    uom,
    sequence_order
  )
  SELECT 
    v_organization_id,
    v_bom_template_id,
    'tube',
    'tube',
    NULL,
    false,
    NULL,
    NULL,
    true,
    'width_rule_42_65_80',
    1,
    'mts',
    20
  WHERE NOT EXISTS (
    SELECT 1 FROM "BOMComponents" bc
    WHERE bc.bom_template_id = v_bom_template_id
      AND bc.component_role = 'tube'
      AND bc.deleted = false
  );

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Added tube component';
  ELSE
    RAISE NOTICE 'ℹ️  tube component already exists';
  END IF;

  -- Add bracket component (if missing)
  INSERT INTO "BOMComponents" (
    organization_id,
    bom_template_id,
    component_role,
    block_type,
    block_condition,
    applies_color,
    hardware_color,
    component_item_id,
    auto_select,
    sku_resolution_rule,
    qty_per_unit,
    uom,
    sequence_order
  )
  SELECT 
    v_organization_id,
    v_bom_template_id,
    'bracket',
    'brackets',
    NULL,
    true,
    'white',
    NULL,
    false,
    NULL,
    2,
    'ea',
    30
  WHERE NOT EXISTS (
    SELECT 1 FROM "BOMComponents" bc
    WHERE bc.bom_template_id = v_bom_template_id
      AND bc.component_role = 'bracket'
      AND bc.deleted = false
  );

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Added bracket component';
  ELSE
    RAISE NOTICE 'ℹ️  bracket component already exists';
  END IF;

  -- Add bottom_bar component (if missing)
  INSERT INTO "BOMComponents" (
    organization_id,
    bom_template_id,
    component_role,
    block_type,
    block_condition,
    applies_color,
    hardware_color,
    component_item_id,
    auto_select,
    sku_resolution_rule,
    qty_per_unit,
    uom,
    sequence_order
  )
  SELECT 
    v_organization_id,
    v_bom_template_id,
    'bottom_bar',
    'bottom_rail',
    jsonb_build_object('bottom_rail_type', 'standard'),
    true,
    'white',
    NULL,
    false,
    NULL,
    1,
    'mts',
    40
  WHERE NOT EXISTS (
    SELECT 1 FROM "BOMComponents" bc
    WHERE bc.bom_template_id = v_bom_template_id
      AND bc.component_role = 'bottom_bar'
      AND bc.deleted = false
  );

  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  IF v_updated_count > 0 THEN
    RAISE NOTICE '✅ Added bottom_bar component';
  ELSE
    RAISE NOTICE 'ℹ️  bottom_bar component already exists';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✨ PROCESS COMPLETED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Next steps:';
  RAISE NOTICE '1. Re-configure the QuoteLine in the UI';
  RAISE NOTICE '2. Verify that all components appear in QuoteLineComponents';
  RAISE NOTICE '3. If components still missing, check FIX_BOM_COMPONENTS_RESOLUTION.sql';
  RAISE NOTICE '   (Some components may need component_item_id mapping)';
  RAISE NOTICE '';

END $$;

-- Verification: Show final BOMTemplate status
SELECT 
  'Verification: Final BOMTemplate Status' as check_name,
  bt.id as bom_template_id,
  bt.name as template_name,
  bt.active,
  bt.deleted,
  COUNT(bc.id) as component_count,
  STRING_AGG(DISTINCT bc.component_role, ', ' ORDER BY bc.component_role) as component_roles
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bt.id, bt.name, bt.active, bt.deleted
ORDER BY bt.active DESC, COUNT(bc.id) DESC
LIMIT 1;








