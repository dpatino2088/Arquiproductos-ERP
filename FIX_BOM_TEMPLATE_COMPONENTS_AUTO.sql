-- ========================================
-- FIX: Add Missing BOMComponents to BOMTemplate (AUTO)
-- ========================================
-- This script automatically finds the BOMTemplate ID from the Sale Order
-- INSTRUCTIONS: Replace 'SO-000003' with your Sale Order number
-- ========================================

-- Step 1: Get BOMTemplate ID and Organization ID automatically
WITH sale_order_info AS (
  SELECT 
    so.id as sale_order_id,
    ql.product_type_id,
    ql.organization_id,
    bt.id as bom_template_id,
    bt.name as template_name,
    pt.code as product_type_code
  FROM "SaleOrders" so
    INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
    INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
    LEFT JOIN "ProductTypes" pt ON pt.id = ql.product_type_id
    INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
      AND bt.organization_id = ql.organization_id
      AND bt.deleted = false
      AND bt.active = true
  WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
    AND so.deleted = false
  LIMIT 1
)
SELECT 
  'BOMTemplate Info' as info_type,
  bom_template_id,
  organization_id,
  product_type_code,
  template_name
FROM sale_order_info;

-- Step 2: Check current BOMComponents
SELECT 
  'Current BOMComponents' as check_name,
  bc.component_role,
  COUNT(*) as count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id 
    AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bc.component_role
ORDER BY bc.component_role;

-- Step 3: Find CatalogItems for each component type
-- This helps identify which CatalogItems to use for component_item_id

-- Find drive/motor items
SELECT 
  'Available Drive/Motor Items' as check_name,
  ci.id,
  ci.sku,
  ci.item_name,
  ci.is_fabric
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  CROSS JOIN "CatalogItems" ci
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
  AND ci.organization_id = ql.organization_id
  AND ci.deleted = false
  AND (ci.sku ILIKE '%MOTOR%' OR ci.sku ILIKE '%DRIVE%' OR ci.item_name ILIKE '%motor%' OR ci.item_name ILIKE '%drive%')
  AND ci.is_fabric = false
ORDER BY ci.sku
LIMIT 10;

-- Find tube items
SELECT 
  'Available Tube Items' as check_name,
  ci.id,
  ci.sku,
  ci.item_name,
  ci.is_fabric
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  CROSS JOIN "CatalogItems" ci
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
  AND ci.organization_id = ql.organization_id
  AND ci.deleted = false
  AND (ci.sku ILIKE '%TUBE%' OR ci.sku ILIKE '%RTU%' OR ci.item_name ILIKE '%tube%')
  AND ci.is_fabric = false
ORDER BY ci.sku
LIMIT 10;

-- Find bracket items
SELECT 
  'Available Bracket Items' as check_name,
  ci.id,
  ci.sku,
  ci.item_name,
  ci.is_fabric
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  CROSS JOIN "CatalogItems" ci
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
  AND ci.organization_id = ql.organization_id
  AND ci.deleted = false
  AND (ci.sku ILIKE '%BRACKET%' OR ci.item_name ILIKE '%bracket%')
  AND ci.is_fabric = false
ORDER BY ci.sku
LIMIT 10;

-- Find bottom bar items
SELECT 
  'Available Bottom Bar Items' as check_name,
  ci.id,
  ci.sku,
  ci.item_name,
  ci.is_fabric
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  CROSS JOIN "CatalogItems" ci
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
  AND ci.organization_id = ql.organization_id
  AND ci.deleted = false
  AND (ci.sku ILIKE '%BOTTOM%' OR ci.sku ILIKE '%RAIL%' OR ci.item_name ILIKE '%bottom%' OR ci.item_name ILIKE '%rail%')
  AND ci.is_fabric = false
ORDER BY ci.sku
LIMIT 10;

-- ========================================
-- Step 4: Add Missing BOMComponents (AUTO)
-- ========================================
-- This uses a DO block to automatically get the BOMTemplate ID

DO $$
DECLARE
  v_bom_template_id uuid;
  v_organization_id uuid;
  v_product_type_id uuid;
  v_updated_count integer;
  v_bom_template_active boolean;
BEGIN
  -- Get Organization ID and Product Type ID from Sale Order
  SELECT 
    ql.organization_id,
    ql.product_type_id
  INTO 
    v_organization_id,
    v_product_type_id
  FROM "SaleOrders" so
    INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
    INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
    AND so.deleted = false
  LIMIT 1;

  IF v_organization_id IS NULL OR v_product_type_id IS NULL THEN
    RAISE EXCEPTION 'Sale Order SO-000003 not found or missing QuoteLine. Please check the Sale Order number.';
  END IF;

  -- Try to find existing BOMTemplate (active or inactive)
  SELECT bt.id INTO v_bom_template_id
  FROM "BOMTemplates" bt
  WHERE bt.product_type_id = v_product_type_id 
    AND bt.organization_id = v_organization_id
    AND bt.deleted = false
  ORDER BY bt.active DESC, bt.created_at DESC
  LIMIT 1;

  -- If BOMTemplate doesn't exist, create it
  IF v_bom_template_id IS NULL THEN
    RAISE NOTICE '⚠️  No BOMTemplate found. Creating new BOMTemplate...';
    
    INSERT INTO "BOMTemplates" (
      organization_id,
      product_type_id,
      name,
      active,
      deleted
    )
    SELECT 
      v_organization_id,
      v_product_type_id,
      'BOM Template for ' || pt.code || ' - ' || pt.name,
      true,
      false
    FROM "ProductTypes" pt
    WHERE pt.id = v_product_type_id
    RETURNING id INTO v_bom_template_id;
    
    RAISE NOTICE '✅ Created new BOMTemplate with ID: %', v_bom_template_id;
  ELSE
    -- Check if BOMTemplate is active
    SELECT bt.active INTO v_bom_template_active
    FROM "BOMTemplates" bt
    WHERE bt.id = v_bom_template_id;
    
    IF v_bom_template_active = false THEN
      RAISE NOTICE '⚠️  BOMTemplate exists but is inactive. Activating...';
      UPDATE "BOMTemplates"
      SET active = true, updated_at = NOW()
      WHERE id = v_bom_template_id;
      RAISE NOTICE '✅ Activated BOMTemplate';
    END IF;
  END IF;

  RAISE NOTICE '✅ Found BOMTemplate ID: %', v_bom_template_id;
  RAISE NOTICE '✅ Organization ID: %', v_organization_id;
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
    jsonb_build_object('drive_type', 'motor'), -- or 'manual' depending on your needs
    true, -- applies_color
    'white', -- hardware_color (will be mapped via HardwareColorMapping)
    NULL, -- component_item_id (set this based on your CatalogItems)
    false, -- auto_select
    NULL, -- sku_resolution_rule
    1, -- qty_per_unit
    'ea', -- uom
    10 -- sequence_order
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
    NULL, -- block_condition (always active)
    false, -- applies_color
    NULL, -- hardware_color
    NULL, -- component_item_id (set this or use auto_select)
    true, -- auto_select
    'width_rule_42_65_80', -- sku_resolution_rule
    1, -- qty_per_unit
    'mts', -- uom (linear meters)
    20 -- sequence_order
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
    NULL, -- block_condition (always active)
    true, -- applies_color
    'white', -- hardware_color (will be mapped via HardwareColorMapping)
    NULL, -- component_item_id (set this based on your CatalogItems)
    false, -- auto_select
    NULL, -- sku_resolution_rule
    2, -- qty_per_unit (typically 2 brackets)
    'ea', -- uom
    30 -- sequence_order
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
    jsonb_build_object('bottom_rail_type', 'standard'), -- or 'wrapped'
    true, -- applies_color
    'white', -- hardware_color (will be mapped via HardwareColorMapping)
    NULL, -- component_item_id (set this based on your CatalogItems)
    false, -- auto_select
    NULL, -- sku_resolution_rule
    1, -- qty_per_unit
    'mts', -- uom (linear meters)
    40 -- sequence_order
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
  RAISE NOTICE '✨ Fix completed!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Next steps:';
  RAISE NOTICE '1. Review the "Available ... Items" queries above to find CatalogItem IDs';
  RAISE NOTICE '2. Update component_item_id for components that need direct mapping';
  RAISE NOTICE '3. Re-configure the QuoteLine to test BOM generation';
  RAISE NOTICE '4. Verify that all components appear in QuoteLineComponents';

END $$;

-- Step 5: Verify Added Components
SELECT 
  'Verification: BOMComponents after fix' as check_name,
  bc.component_role,
  bc.block_type,
  bc.component_item_id,
  bc.auto_select,
  bc.sku_resolution_rule,
  COUNT(*) as count
FROM "SaleOrders" so
  INNER JOIN "SaleOrderLines" sol ON sol.sale_order_id = so.id AND sol.deleted = false
  INNER JOIN "QuoteLines" ql ON ql.id = sol.quote_line_id AND ql.deleted = false
  INNER JOIN "BOMTemplates" bt ON bt.product_type_id = ql.product_type_id 
    AND bt.organization_id = ql.organization_id
    AND bt.deleted = false
    AND bt.active = true
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id 
    AND bc.deleted = false
WHERE so.sale_order_no = 'SO-000003' -- CHANGE THIS
  AND so.deleted = false
GROUP BY bc.component_role, bc.block_type, bc.component_item_id, bc.auto_select, bc.sku_resolution_rule
ORDER BY bc.component_role;

-- ========================================
-- NOTE: After running this script:
-- 1. Review the "Available ... Items" queries to find CatalogItem IDs
-- 2. Update component_item_id for components that need direct mapping (use FIX_BOM_COMPONENTS_RESOLUTION.sql)
-- 3. Test BOM generation by re-configuring a quote line
-- 4. Verify that all components appear in QuoteLineComponents
-- ========================================

