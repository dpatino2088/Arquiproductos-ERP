-- ========================================
-- FIX: Map BOMComponents to CatalogItems
-- ========================================
-- This script helps map BOMComponents to actual CatalogItems
-- INSTRUCTIONS: 
-- 1. Replace 'YOUR_BOM_TEMPLATE_ID' with your actual BOMTemplate ID
-- 2. Replace 'YOUR_ORGANIZATION_ID' with your organization ID
-- 3. Review the suggested mappings and update component_item_id accordingly
-- ========================================

-- INSTRUCTIONS: Replace 'YOUR_BOM_TEMPLATE_ID' and 'YOUR_ORGANIZATION_ID' with actual values

-- Step 1: Find BOMComponents that need mapping
SELECT 
  'BOMComponents Needing Mapping' as check_name,
  bc.id as bom_component_id,
  bc.component_role,
  bc.block_type,
  bc.auto_select,
  bc.sku_resolution_rule,
  bc.component_item_id,
  CASE 
    WHEN bc.component_item_id IS NOT NULL THEN '✅ HAS: Direct item_id'
    WHEN bc.auto_select = true AND bc.sku_resolution_rule IS NOT NULL THEN '✅ HAS: Auto-select'
    ELSE '❌ MISSING: Needs mapping'
  END as status
FROM "BOMComponents" bc
WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
  AND bc.deleted = false
  AND bc.component_item_id IS NULL
  AND (bc.auto_select = false OR bc.sku_resolution_rule IS NULL)
ORDER BY bc.sequence_order;

-- Step 2: Find potential CatalogItems for each component role
-- This helps identify which CatalogItems to use

-- For operating_system_drive
SELECT 
  'Suggested: Drive/Motor Items' as check_name,
  bc.id as bom_component_id,
  bc.component_role,
  ci.id as suggested_catalog_item_id,
  ci.sku,
  ci.item_name
FROM "BOMComponents" bc
CROSS JOIN "CatalogItems" ci
WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
  AND bc.component_role = 'operating_system_drive'
  AND bc.deleted = false
  AND ci.organization_id = 'YOUR_ORGANIZATION_ID'::uuid -- CHANGE THIS
  AND ci.deleted = false
  AND ci.is_fabric = false
  AND (ci.sku ILIKE '%MOTOR%' OR ci.sku ILIKE '%DRIVE%' OR ci.item_name ILIKE '%motor%' OR ci.item_name ILIKE '%drive%')
ORDER BY ci.sku
LIMIT 5;

-- For brackets
SELECT 
  'Suggested: Bracket Items' as check_name,
  bc.id as bom_component_id,
  bc.component_role,
  ci.id as suggested_catalog_item_id,
  ci.sku,
  ci.item_name
FROM "BOMComponents" bc
CROSS JOIN "CatalogItems" ci
WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
  AND bc.component_role = 'bracket'
  AND bc.deleted = false
  AND ci.organization_id = 'YOUR_ORGANIZATION_ID'::uuid -- CHANGE THIS
  AND ci.deleted = false
  AND ci.is_fabric = false
  AND (ci.sku ILIKE '%BRACKET%' OR ci.item_name ILIKE '%bracket%')
ORDER BY ci.sku
LIMIT 5;

-- For bottom_bar
SELECT 
  'Suggested: Bottom Bar Items' as check_name,
  bc.id as bom_component_id,
  bc.component_role,
  ci.id as suggested_catalog_item_id,
  ci.sku,
  ci.item_name
FROM "BOMComponents" bc
CROSS JOIN "CatalogItems" ci
WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
  AND bc.component_role = 'bottom_bar'
  AND bc.deleted = false
  AND ci.organization_id = 'YOUR_ORGANIZATION_ID'::uuid -- CHANGE THIS
  AND ci.deleted = false
  AND ci.is_fabric = false
  AND (ci.sku ILIKE '%BOTTOM%' OR ci.sku ILIKE '%RAIL%' OR ci.item_name ILIKE '%bottom%' OR ci.item_name ILIKE '%rail%')
ORDER BY ci.sku
LIMIT 5;

-- ========================================
-- Step 3: Example UPDATE statements
-- ========================================
-- Use these as templates, replacing the IDs with actual values from the queries above

/*
-- Example: Map operating_system_drive to a specific CatalogItem
UPDATE "BOMComponents"
SET 
  component_item_id = 'CATALOG_ITEM_ID_HERE'::uuid,
  updated_at = now()
WHERE id = 'BOM_COMPONENT_ID_HERE'::uuid
  AND deleted = false;

-- Example: Map bracket to a specific CatalogItem
UPDATE "BOMComponents"
SET 
  component_item_id = 'CATALOG_ITEM_ID_HERE'::uuid,
  updated_at = now()
WHERE id = 'BOM_COMPONENT_ID_HERE'::uuid
  AND deleted = false;

-- Example: Map bottom_bar to a specific CatalogItem
UPDATE "BOMComponents"
SET 
  component_item_id = 'CATALOG_ITEM_ID_HERE'::uuid,
  updated_at = now()
WHERE id = 'BOM_COMPONENT_ID_HERE'::uuid
  AND deleted = false;
*/

-- ========================================
-- Step 4: Verify Mappings
-- ========================================
SELECT 
  'Verification: BOMComponents after mapping' as check_name,
  bc.component_role,
  COUNT(*) as total,
  COUNT(CASE WHEN bc.component_item_id IS NOT NULL THEN 1 END) as has_item_id,
  COUNT(CASE WHEN bc.auto_select = true AND bc.sku_resolution_rule IS NOT NULL THEN 1 END) as has_auto_select,
  COUNT(CASE WHEN bc.component_item_id IS NULL AND (bc.auto_select = false OR bc.sku_resolution_rule IS NULL) THEN 1 END) as still_needs_mapping
FROM "BOMComponents" bc
WHERE bc.bom_template_id = 'YOUR_BOM_TEMPLATE_ID'::uuid -- CHANGE THIS
  AND bc.deleted = false
GROUP BY bc.component_role
ORDER BY bc.component_role;

-- ========================================
-- NOTE: After mapping, test BOM generation:
-- 1. Re-configure a quote line
-- 2. Verify that all components appear in QuoteLineComponents
-- 3. Check that BomInstanceLines has all components after quote approval
-- ========================================

