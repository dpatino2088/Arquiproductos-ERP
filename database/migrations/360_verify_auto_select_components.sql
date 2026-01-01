-- ====================================================
-- Migration 360: Verify Auto-Select Components
-- ====================================================
-- Queries to verify auto-select components exist and are configured correctly
-- ====================================================

-- Query 1: List all BOMTemplates with their auto-select component count
SELECT 
    bt.id as bom_template_id,
    bt.name as template_name,
    bt.product_type_id,
    pt.name as product_type_name,
    COUNT(bc.id) FILTER (WHERE bc.auto_select = true OR bc.component_item_id IS NULL) as auto_select_count,
    COUNT(bc.id) as total_components,
    bt.organization_id
FROM "BOMTemplates" bt
LEFT JOIN "ProductTypes" pt ON pt.id = bt.product_type_id
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.deleted = false
GROUP BY bt.id, bt.name, bt.product_type_id, pt.name, bt.organization_id
HAVING COUNT(bc.id) FILTER (WHERE bc.auto_select = true OR bc.component_item_id IS NULL) > 0
ORDER BY bt.name;

-- Query 2: Detailed view of auto-select components for the FIRST template found with auto-select
-- (To use a specific template, uncomment and replace the UUID in the WHERE clause)
SELECT 
    bt.id as bom_template_id,
    bt.name as template_name,
    bc.id as component_id,
    bc.component_role,
    bc.auto_select,
    bc.component_item_id,
    bc.qty_type,
    bc.qty_value,
    bc.qty_per_unit,
    bc.hardware_color,
    bc.sku_resolution_rule,
    bc.block_condition,
    bc.applies_color,
    CASE 
        WHEN bc.component_item_id IS NOT NULL THEN 'Fixed (has component_item_id)'
        WHEN bc.auto_select = true THEN 'Auto-Select (explicit)'
        WHEN bc.component_item_id IS NULL THEN 'Auto-Select (implicit - NULL component_item_id)'
        ELSE 'Unknown'
    END as component_type
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE bt.deleted = false
AND bc.deleted = false
AND (bc.auto_select = true OR bc.component_item_id IS NULL)
AND bc.component_role IS NOT NULL
ORDER BY bt.name, bc.sequence_order, bc.component_role
LIMIT 50;

-- Query 2B: Detailed view for a SPECIFIC template (uncomment and replace UUID)
-- SELECT 
--     bt.id as bom_template_id,
--     bt.name as template_name,
--     bc.id as component_id,
--     bc.component_role,
--     bc.auto_select,
--     bc.component_item_id,
--     bc.qty_type,
--     bc.qty_value,
--     bc.qty_per_unit,
--     bc.hardware_color,
--     bc.sku_resolution_rule,
--     bc.block_condition,
--     bc.applies_color,
--     CASE 
--         WHEN bc.component_item_id IS NOT NULL THEN 'Fixed (has component_item_id)'
--         WHEN bc.auto_select = true THEN 'Auto-Select (explicit)'
--         WHEN bc.component_item_id IS NULL THEN 'Auto-Select (implicit - NULL component_item_id)'
--         ELSE 'Unknown'
--     END as component_type
-- FROM "BOMTemplates" bt
-- INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
-- WHERE bt.id = '00000000-0000-0000-0000-000000000000'::uuid  -- REPLACE WITH ACTUAL UUID FROM Query 1
-- AND bt.deleted = false
-- AND bc.deleted = false
-- AND (bc.auto_select = true OR bc.component_item_id IS NULL)
-- AND bc.component_role IS NOT NULL
-- ORDER BY bc.sequence_order, bc.component_role;

-- Query 3: Find templates with auto-select components (without UUID)
SELECT 
    bt.id as bom_template_id,
    bt.name as template_name,
    bc.id as component_id,
    bc.component_role,
    bc.auto_select,
    bc.component_item_id,
    bc.hardware_color,
    bc.sku_resolution_rule,
    bc.qty_type,
    bc.block_condition
FROM "BOMTemplates" bt
INNER JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id
WHERE bt.deleted = false
AND bc.deleted = false
AND (bc.auto_select = true OR bc.component_item_id IS NULL)
AND bc.component_role IS NOT NULL
ORDER BY bt.name, bc.sequence_order
LIMIT 20;

-- Query 4: Check if CatalogItems have selection_priority set
SELECT 
    COUNT(*) FILTER (WHERE selection_priority IS NULL) as missing_priority_count,
    COUNT(*) FILTER (WHERE selection_priority IS NOT NULL) as has_priority_count,
    COUNT(*) as total_catalog_items,
    MIN(selection_priority) as min_priority,
    MAX(selection_priority) as max_priority,
    AVG(selection_priority) as avg_priority
FROM "CatalogItems"
WHERE deleted = false;

-- Query 5: Check ItemCategories.code values (for category mapping)
-- This shows what category codes exist - should include: fabric, tube, motor, bracket, cassette, side_channel, bottom_channel, accessory
SELECT 
    ic.code,
    ic.name,
    COUNT(ci.id) as catalog_item_count
FROM "ItemCategories" ic
LEFT JOIN "CatalogItems" ci ON ci.item_category_id = ic.id AND ci.deleted = false
WHERE ic.deleted = false
GROUP BY ic.code, ic.name
HAVING ic.code IS NOT NULL
ORDER BY ic.code;

-- Query 6: Verify HardwareColorMapping exists
SELECT 
    COUNT(*) as total_mappings,
    COUNT(DISTINCT hardware_color) as unique_colors,
    COUNT(DISTINCT organization_id) as unique_organizations
FROM "HardwareColorMapping"
WHERE deleted = false;

-- Query 7: Show detailed HardwareColorMapping breakdown by color
SELECT 
    hardware_color,
    COUNT(*) as mapping_count,
    COUNT(DISTINCT base_part_id) as unique_base_parts,
    COUNT(DISTINCT mapped_part_id) as unique_mapped_parts,
    COUNT(DISTINCT organization_id) as organizations
FROM "HardwareColorMapping"
WHERE deleted = false
GROUP BY hardware_color
ORDER BY hardware_color;

-- Query 8: Sample HardwareColorMapping entries (first 10)
SELECT 
    hcm.id,
    hcm.hardware_color,
    hcm.organization_id,
    base_ci.sku as base_sku,
    base_ci.item_name as base_item_name,
    mapped_ci.sku as mapped_sku,
    mapped_ci.item_name as mapped_item_name
FROM "HardwareColorMapping" hcm
INNER JOIN "CatalogItems" base_ci ON base_ci.id = hcm.base_part_id
INNER JOIN "CatalogItems" mapped_ci ON mapped_ci.id = hcm.mapped_part_id
WHERE hcm.deleted = false
ORDER BY hcm.hardware_color, base_ci.sku
LIMIT 10;

-- Query 9: Check what category_code values exist in BomInstanceLines (to see what format is used)
SELECT 
    category_code,
    COUNT(*) as line_count
FROM "BomInstanceLines"
WHERE deleted = false
AND category_code IS NOT NULL
GROUP BY category_code
ORDER BY category_code;

