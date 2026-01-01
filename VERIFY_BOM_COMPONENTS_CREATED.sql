-- ====================================================
-- VERIFY: BOM Components Created
-- ====================================================
-- This script shows all BOMComponents created for each BOMTemplate
-- ====================================================

SELECT 
  'BOMComponents Details' as check_name,
  bt.name as template_name,
  bc.component_role,
  bc.block_type,
  bc.block_condition,
  bc.applies_color,
  bc.auto_select,
  bc.sku_resolution_rule,
  ci.sku,
  ci.item_name,
  bc.qty_per_unit,
  bc.uom,
  bc.sequence_order,
  CASE 
    WHEN bc.component_item_id IS NULL AND bc.auto_select = false THEN '❌ MISSING component_item_id'
    WHEN bc.component_item_id IS NULL AND bc.auto_select = true THEN '✅ Auto-select (will resolve by rule)'
    WHEN bc.component_item_id IS NOT NULL THEN '✅ Has component_item_id'
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

-- Summary by Template
SELECT 
  'Summary by Template' as check_name,
  bt.name as template_name,
  COUNT(bc.id) as total_components,
  COUNT(CASE WHEN bc.component_item_id IS NOT NULL THEN 1 END) as components_with_item_id,
  COUNT(CASE WHEN bc.component_item_id IS NULL AND bc.auto_select = true THEN 1 END) as auto_select_components,
  COUNT(CASE WHEN bc.component_item_id IS NULL AND bc.auto_select = false THEN 1 END) as missing_item_id,
  STRING_AGG(DISTINCT bc.component_role, ', ' ORDER BY bc.component_role) FILTER (WHERE bc.component_role IS NOT NULL) as component_roles,
  STRING_AGG(DISTINCT bc.block_type, ', ' ORDER BY bc.block_type) FILTER (WHERE bc.block_type IS NOT NULL) as block_types
FROM "BOMTemplates" bt
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.organization_id = (
  SELECT id FROM "Organizations" WHERE deleted = false ORDER BY created_at ASC LIMIT 1
)
  AND bt.deleted = false
GROUP BY bt.id, bt.name
ORDER BY bt.name;








