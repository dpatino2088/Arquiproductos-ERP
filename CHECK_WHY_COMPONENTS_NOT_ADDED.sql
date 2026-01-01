-- ====================================================
-- CHECK: Why Components Not Added
-- ====================================================
-- This script checks if SKUs were found but components not added
-- ====================================================

-- Check 1: Verify SKUs exist
SELECT 
  'Check 1: SKUs Found' as check_name,
  ci.sku,
  ci.id as catalog_item_id,
  ci.item_name,
  CASE 
    WHEN ci.sku ILIKE '%RCA-04%' THEN 'RCA-04 (Bottom Rail Profile)'
    WHEN ci.sku ILIKE '%RCA-21%' THEN 'RCA-21 (Bottom Rail End Cap)'
    WHEN ci.sku ILIKE '%RC3101%' THEN 'RC3101 (Side Channel Profile)'
    WHEN ci.sku ILIKE '%RC3102%' THEN 'RC3102 (Side Channel Cover)'
    WHEN ci.sku ILIKE '%RCAS-09-75%' THEN 'RCAS-09-75 (Insert/Gasket)'
    WHEN ci.sku ILIKE '%RC3104%' THEN 'RC3104 (Top Fix Bracket)'
    ELSE 'Other'
  END as expected_component
FROM "CatalogItems" ci
WHERE ci.organization_id = (
  SELECT id FROM "Organizations" WHERE deleted = false ORDER BY created_at ASC LIMIT 1
)
  AND ci.deleted = false
  AND (
    ci.sku ILIKE '%RCA-04%' OR ci.sku ILIKE '%RCA-21%'
    OR ci.sku ILIKE '%RC3101%' OR ci.sku ILIKE '%RC3102%'
    OR ci.sku ILIKE '%RCAS-09-75%' OR ci.sku ILIKE '%RC3104%'
  )
ORDER BY ci.sku;

-- Check 2: Verify BOMComponents created
SELECT 
  'Check 2: BOMComponents Created' as check_name,
  bt.name as template_name,
  bc.component_role,
  bc.block_type,
  bc.component_item_id,
  ci.sku,
  ci.item_name,
  bc.auto_select,
  bc.applies_color,
  CASE 
    WHEN bc.component_item_id IS NULL AND bc.auto_select = false THEN '❌ PROBLEM: Missing item_id and not auto_select'
    WHEN bc.component_item_id IS NULL AND bc.auto_select = true THEN '✅ OK: Auto-select component'
    WHEN bc.component_item_id IS NOT NULL THEN '✅ OK: Has item_id'
    ELSE '⚠️ Check manually'
  END as status
FROM "BOMTemplates" bt
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
LEFT JOIN "CatalogItems" ci ON ci.id = bc.component_item_id
WHERE bt.organization_id = (
  SELECT id FROM "Organizations" WHERE deleted = false ORDER BY created_at ASC LIMIT 1
)
  AND bt.deleted = false
ORDER BY bt.name, bc.sequence_order, bc.component_role;

-- Check 3: Count components by type
SELECT 
  'Check 3: Component Count by Type' as check_name,
  bt.name as template_name,
  COUNT(*) FILTER (WHERE bc.component_role = 'tube') as tube_count,
  COUNT(*) FILTER (WHERE bc.component_role = 'bottom_rail_profile') as bottom_rail_profile_count,
  COUNT(*) FILTER (WHERE bc.component_role = 'bottom_rail_end_cap') as bottom_rail_end_cap_count,
  COUNT(*) FILTER (WHERE bc.component_role = 'side_channel_profile') as side_channel_profile_count,
  COUNT(*) FILTER (WHERE bc.component_role IS NULL AND bc.block_type = 'side_channel') as side_channel_cover_count,
  COUNT(*) FILTER (WHERE bc.component_role = 'bracket') as bracket_count,
  COUNT(*) FILTER (WHERE bc.component_role IS NULL AND bc.block_type IS NULL) as accessory_count,
  COUNT(*) as total_components
FROM "BOMTemplates" bt
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.organization_id = (
  SELECT id FROM "Organizations" WHERE deleted = false ORDER BY created_at ASC LIMIT 1
)
  AND bt.deleted = false
GROUP BY bt.id, bt.name
ORDER BY bt.name;








