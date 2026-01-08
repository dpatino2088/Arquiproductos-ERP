-- ====================================================
-- Diagnostic Query: Check BOM Components Issue
-- ====================================================
-- This query helps diagnose why BOM components are incorrect
-- ====================================================

-- Query 1: Check the most recent BOM instance and its lines
SELECT 
    bi.id as bom_instance_id,
    bi.created_at,
    bi.generated_at,
    bi.bom_template_id,
    COUNT(bil.id) as line_count,
    COUNT(DISTINCT bil.part_role) as unique_roles,
    COUNT(DISTINCT bil.uom) as unique_uoms,
    STRING_AGG(DISTINCT bil.uom, ', ') as all_uoms,
    STRING_AGG(DISTINCT bil.part_role, ', ') as all_roles
FROM "BomInstances" bi
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE bi.deleted = false
GROUP BY bi.id, bi.created_at, bi.generated_at, bi.bom_template_id
ORDER BY COALESCE(bi.generated_at, bi.created_at) DESC
LIMIT 5;

-- Query 2: Check UOM distribution in recent BOM lines
SELECT 
    bil.part_role,
    bil.uom,
    COUNT(*) as count,
    SUM(bil.qty) as total_qty,
    STRING_AGG(DISTINCT bil.resolved_sku, ', ') as sample_skus
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bil.deleted = false
  AND bi.deleted = false
  AND bi.created_at >= NOW() - INTERVAL '1 day'
GROUP BY bil.part_role, bil.uom
ORDER BY bil.part_role, bil.uom;

-- Query 3: Check if BOMComponents have correct UOM values
SELECT 
    bc.component_role,
    bc.auto_select,
    bc.uom as bom_component_uom,
    bc.qty_type,
    bc.sku_resolution_rule,
    COUNT(*) as component_count
FROM "BOMComponents" bc
INNER JOIN "BOMTemplates" bt ON bt.id = bc.bom_template_id
WHERE bc.deleted = false
  AND bt.deleted = false
GROUP BY bc.component_role, bc.auto_select, bc.uom, bc.qty_type, bc.sku_resolution_rule
ORDER BY bc.component_role, bc.auto_select;

-- Query 4: Compare BOMComponent.uom vs BomInstanceLine.uom for auto-select components
SELECT 
    bc.component_role,
    bc.uom as template_uom,
    bil.uom as instance_uom,
    COUNT(*) as mismatch_count,
    STRING_AGG(DISTINCT bil.resolved_sku, ', ') as sample_skus
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "BOMComponents" bc ON bc.component_role = bil.part_role 
    AND bc.bom_template_id = bi.bom_template_id
    AND bc.auto_select = true
    AND bc.deleted = false
WHERE bil.deleted = false
  AND bi.deleted = false
  AND bc.uom IS NOT NULL
  AND bc.uom != bil.uom
GROUP BY bc.component_role, bc.uom, bil.uom
ORDER BY mismatch_count DESC;

-- Query 5: Check cut_l_mm values for linear components
SELECT 
    bil.part_role,
    bil.uom,
    bil.qty,
    bil.cut_l_mm,
    CASE 
        WHEN bil.part_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile')
             AND bil.cut_l_mm IS NULL 
        THEN 'MISSING'
        WHEN bil.part_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile')
             AND bil.cut_l_mm IS NOT NULL
        THEN 'OK'
        ELSE 'N/A'
    END as cut_status
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bil.deleted = false
  AND bi.deleted = false
  AND bi.created_at >= NOW() - INTERVAL '1 day'
  AND bil.part_role IN ('tube', 'bottom_bar', 'bottom_rail', 'bottom_rail_profile', 'fabric')
ORDER BY bil.part_role, bil.created_at DESC
LIMIT 20;


