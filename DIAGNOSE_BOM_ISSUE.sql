-- ========================================
-- DIAGNOSTIC SCRIPT: BOM Missing Components
-- ========================================
-- Purpose: Diagnose why Manufacturing Order BOM only shows fabrics
-- Run each section and share the results
--
-- INSTRUCTIONS:
-- 1. Replace 'YOUR_SALE_ORDER_ID' with the actual Sale Order ID (e.g., '123e4567-e89b-12d3-a456-426614174000')
-- 2. Replace 'YOUR_ORG_ID' with your Organization ID
-- 3. Run each section in order
-- ========================================

-- Replace these values before running:
\set sale_order_id 'YOUR_SALE_ORDER_ID'
\set org_id 'YOUR_ORG_ID'

-- ========================================
-- STEP 1: Check SaleOrderLines configuration
-- ========================================
-- This shows what configuration was saved when creating the Sale Order

SELECT 
  sol.id as sale_order_line_id,
  sol.product_type_id,
  pt.code as product_type_code,
  pt.name as product_type_name,
  sol.drive_type,
  sol.cassette,
  sol.cassette_type,
  sol.side_channel,
  sol.side_channel_type,
  sol.hardware_color,
  sol.bottom_rail_type,
  sol.width_m,
  sol.height_m,
  sol.metadata
FROM "SaleOrderLines" sol
  LEFT JOIN "ProductTypes" pt ON pt.id = sol.product_type_id
WHERE sol.sale_order_id = :'sale_order_id'
  AND sol.deleted = false;

-- EXPECTED:
-- - drive_type should be 'motor' or 'manual'
-- - cassette should be true or false
-- - hardware_color should be 'white', 'black', etc.
-- If these are NULL, the problem is in Quote → Sale Order conversion

-- ========================================
-- STEP 2: Check if BOMTemplate exists for ProductType
-- ========================================

WITH sale_order_product_types AS (
  SELECT DISTINCT sol.product_type_id
  FROM "SaleOrderLines" sol
  WHERE sol.sale_order_id = :'sale_order_id'
    AND sol.deleted = false
)
SELECT 
  bt.id as bom_template_id,
  bt.name as template_name,
  bt.product_type_id,
  bt.active,
  COUNT(bc.id) as total_components,
  COUNT(CASE WHEN bc.component_role = 'fabric' THEN 1 END) as fabric_components,
  COUNT(CASE WHEN bc.component_role = 'operating_system_drive' THEN 1 END) as drive_components,
  COUNT(CASE WHEN bc.component_role = 'tube' THEN 1 END) as tube_components,
  COUNT(CASE WHEN bc.component_role = 'bracket' THEN 1 END) as bracket_components,
  COUNT(CASE WHEN bc.component_role = 'bottom_bar' THEN 1 END) as bottom_bar_components
FROM "BOMTemplates" bt
  LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.product_type_id IN (SELECT product_type_id FROM sale_order_product_types)
  AND bt.deleted = false
GROUP BY bt.id, bt.name, bt.product_type_id, bt.active;

-- EXPECTED:
-- - At least 1 active BOMTemplate
-- - total_components should be > 10 (fabric + drive + tube + brackets + bottom_bar + hardware)
-- If total_components is low, BOMTemplate is incomplete

-- ========================================
-- STEP 3: Check BOMComponents details
-- ========================================

WITH sale_order_product_types AS (
  SELECT DISTINCT sol.product_type_id
  FROM "SaleOrderLines" sol
  WHERE sol.sale_order_id = :'sale_order_id'
    AND sol.deleted = false
),
template AS (
  SELECT id FROM "BOMTemplates"
  WHERE product_type_id IN (SELECT product_type_id FROM sale_order_product_types)
    AND deleted = false
    AND active = true
  LIMIT 1
)
SELECT 
  bc.id,
  bc.component_role,
  bc.block_type,
  bc.block_condition,
  bc.applies_color,
  bc.hardware_color,
  bc.auto_select,
  bc.qty_per_unit,
  bc.uom,
  ci.sku,
  ci.item_name,
  CASE WHEN bc.component_item_id IS NULL THEN 'NULL - needs mapping' ELSE 'OK' END as item_status
FROM "BOMComponents" bc
  LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id AND ci.deleted = false
WHERE bc.bom_template_id IN (SELECT id FROM template)
  AND bc.deleted = false
ORDER BY bc.sequence_order;

-- EXPECTED:
-- - Multiple rows with different component_role values
-- - component_item_id should NOT be NULL (or should have auto_select=true)
-- If all component_item_id are NULL, need to map components to CatalogItems

-- ========================================
-- STEP 4: Check BomInstances created
-- ========================================

SELECT 
  bi.id as bom_instance_id,
  bi.sale_order_line_id,
  bi.bom_template_id,
  bi.metadata,
  bi.created_at
FROM "BomInstances" bi
WHERE bi.sale_order_line_id IN (
  SELECT id FROM "SaleOrderLines" 
  WHERE sale_order_id = :'sale_order_id' 
  AND deleted = false
)
AND bi.deleted = false;

-- EXPECTED:
-- - One BomInstance per SaleOrderLine
-- - metadata should contain configuration (drive_type, hardware_color, etc.)

-- ========================================
-- STEP 5: Check BomInstanceLines generated
-- ========================================

WITH bom_instances AS (
  SELECT bi.id 
  FROM "BomInstances" bi
  WHERE bi.sale_order_line_id IN (
    SELECT id FROM "SaleOrderLines" 
    WHERE sale_order_id = :'sale_order_id' 
    AND deleted = false
  )
  AND bi.deleted = false
)
SELECT 
  bil.id,
  bil.bom_instance_id,
  bil.category_code,
  bil.component_role,
  bil.resolved_part_id,
  bil.qty,
  bil.uom,
  bil.description,
  ci.sku,
  ci.item_name,
  bil.metadata
FROM "BomInstanceLines" bil
  LEFT JOIN "CatalogItems" ci ON ci.id = bil.resolved_part_id
WHERE bil.bom_instance_id IN (SELECT id FROM bom_instances)
  AND bil.deleted = false
ORDER BY 
  CASE bil.category_code
    WHEN 'fabric' THEN 1
    WHEN 'drive' THEN 2
    WHEN 'tube' THEN 3
    WHEN 'bracket' THEN 4
    WHEN 'bottom_rail' THEN 5
    ELSE 99
  END,
  bil.component_role;

-- EXPECTED:
-- - Multiple rows (10-20+ depending on configuration)
-- - Different component_role values
-- - If only fabric appears, the problem is in generate_configured_bom function

-- ========================================
-- STEP 6: Check for function errors
-- ========================================

-- Check if generate_configured_bom function was called and succeeded
-- Look for any errors in postgres logs or check if function exists

SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%generate%bom%'
  AND routine_type = 'FUNCTION';

-- ========================================
-- SUMMARY
-- ========================================
-- After running all steps, you should know:
-- 1. ✅ or ❌ SaleOrderLines has complete configuration
-- 2. ✅ or ❌ BOMTemplate exists and is complete
-- 3. ✅ or ❌ BOMComponents are configured correctly
-- 4. ✅ or ❌ BomInstances were created
-- 5. ✅ or ❌ BomInstanceLines has all components or only fabric

-- Next steps depend on which step shows the problem








