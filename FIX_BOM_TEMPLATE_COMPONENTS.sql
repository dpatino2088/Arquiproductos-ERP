-- ========================================
-- FIX: Add Missing BOMComponents to BOMTemplate
-- ========================================
-- This script adds missing BOMComponents for a given BOMTemplate
-- INSTRUCTIONS: 
-- 1. Replace 'YOUR_BOM_TEMPLATE_ID' with your actual BOMTemplate ID
-- 2. Replace 'YOUR_ORGANIZATION_ID' with your organization ID
-- 3. Review and adjust component_item_id values based on your CatalogItems
-- ========================================

-- INSTRUCTIONS: Replace 'YOUR_BOM_TEMPLATE_ID' and 'YOUR_ORGANIZATION_ID' with actual values

-- Step 1: Check current BOMComponents
SELECT 
  'Current BOMComponents' as check_name,
  bc.component_role,
  COUNT(*) as count
FROM "BOMComponents" bc
WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
  AND bc.deleted = false
GROUP BY bc.component_role
ORDER BY bc.component_role;

-- Step 2: Find CatalogItems for each component type
-- This helps identify which CatalogItems to use for component_item_id

-- Find drive/motor items
SELECT 
  'Available Drive/Motor Items' as check_name,
  ci.id,
  ci.sku,
  ci.item_name,
  ci.is_fabric
FROM "CatalogItems" ci
WHERE ci.organization_id = 'YOUR_ORGANIZATION_ID'::uuid -- CHANGE THIS
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
FROM "CatalogItems" ci
WHERE ci.organization_id = 'YOUR_ORGANIZATION_ID'::uuid -- CHANGE THIS
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
FROM "CatalogItems" ci
WHERE ci.organization_id = 'YOUR_ORGANIZATION_ID'::uuid -- CHANGE THIS
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
FROM "CatalogItems" ci
WHERE ci.organization_id = 'YOUR_ORGANIZATION_ID'::uuid -- CHANGE THIS
  AND ci.deleted = false
  AND (ci.sku ILIKE '%BOTTOM%' OR ci.sku ILIKE '%RAIL%' OR ci.item_name ILIKE '%bottom%' OR ci.item_name ILIKE '%rail%')
  AND ci.is_fabric = false
ORDER BY ci.sku
LIMIT 10;

-- ========================================
-- Step 3: Add Missing BOMComponents
-- ========================================
-- IMPORTANT: Update the component_item_id values based on your CatalogItems
-- You can use the queries above to find the correct IDs

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
  'YOUR_ORGANIZATION_ID'::uuid, -- CHANGE THIS
  'YOUR_BOM_TEMPLATE_ID'::uuid, -- CHANGE THIS
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
  WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
    AND bc.component_role = 'operating_system_drive'
    AND bc.deleted = false
);

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
  'YOUR_ORGANIZATION_ID'::uuid, -- CHANGE THIS
  'YOUR_BOM_TEMPLATE_ID'::uuid, -- CHANGE THIS
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
  WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
    AND bc.component_role = 'tube'
    AND bc.deleted = false
);

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
  'YOUR_ORGANIZATION_ID'::uuid, -- CHANGE THIS
  'YOUR_BOM_TEMPLATE_ID'::uuid, -- CHANGE THIS
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
  WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
    AND bc.component_role = 'bracket'
    AND bc.deleted = false
);

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
  'YOUR_ORGANIZATION_ID'::uuid, -- CHANGE THIS
  'YOUR_BOM_TEMPLATE_ID'::uuid, -- CHANGE THIS
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
  WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
    AND bc.component_role = 'bottom_bar'
    AND bc.deleted = false
);

-- ========================================
-- Step 4: Verify Added Components
-- ========================================
SELECT 
  'Verification: BOMComponents after fix' as check_name,
  bc.component_role,
  bc.block_type,
  bc.component_item_id,
  bc.auto_select,
  bc.sku_resolution_rule,
  COUNT(*) as count
FROM "BOMComponents" bc
WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
  AND bc.deleted = false
GROUP BY bc.component_role, bc.block_type, bc.component_item_id, bc.auto_select, bc.sku_resolution_rule
ORDER BY bc.sequence_order;

-- ========================================
-- NOTE: After adding BOMComponents, you need to:
-- 1. Set component_item_id for components that need direct mapping
-- 2. Test BOM generation by re-configuring a quote line
-- 3. Verify that all components appear in QuoteLineComponents
-- ========================================

