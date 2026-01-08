-- ====================================================
-- BOM Instance Validation Queries
-- ====================================================
-- These queries can be run directly to validate BOM instances.
-- Expected results: 0 rows in a healthy system.
-- ====================================================

-- ====================================================
-- Query A: Validate that no assembly_child exists without parent
-- ====================================================
-- Expected result: 0 rows (all assembly_child should have parent_part_id)
SELECT *
FROM vw_bom_instance_flat
WHERE source = 'assembly_child'
  AND parent_part_id IS NULL;

-- ====================================================
-- Query B: Detect dangerous duplicates (same item + same parent in same BOM instance)
-- ====================================================
-- Expected result: 0 rows (no duplicates should exist)
SELECT
    bom_instance_id,
    parent_part_id,
    catalog_item_id,
    resolved_sku,
    part_role,
    uom,
    COUNT(*) AS duplicate_count
FROM vw_bom_instance_flat
GROUP BY bom_instance_id, parent_part_id, catalog_item_id, resolved_sku, part_role, uom
HAVING COUNT(*) > 1;

-- ====================================================
-- Query C: Detect lines without qty or uom
-- ====================================================
-- Expected result: 0 rows (all lines should have qty and uom)
SELECT *
FROM vw_bom_instance_flat
WHERE qty IS NULL
   OR uom IS NULL
   OR TRIM(uom) = '';

-- ====================================================
-- Query D: Detect assembly_child lines where parent doesn't exist in same BOM
-- ====================================================
-- Expected result: 0 rows (all assembly_child should have parent in same BOM)
SELECT 
    vf.bom_instance_id,
    vf.catalog_item_id AS child_item_id,
    vf.parent_part_id,
    vf.resolved_sku AS child_sku,
    vf.source
FROM vw_bom_instance_flat vf
WHERE vf.source = 'assembly_child'
  AND vf.parent_part_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM vw_bom_instance_flat vf_parent
    WHERE vf_parent.bom_instance_id = vf.bom_instance_id
      AND vf_parent.catalog_item_id = vf.parent_part_id
      AND vf_parent.source IN ('bom_component', 'quote_line_component')
  );

-- ====================================================
-- Query E: Summary statistics per BOM instance
-- ====================================================
-- This query shows summary stats for all BOM instances
SELECT 
    bom_instance_id,
    organization_id,
    bom_template_id,
    bom_created_at,
    COUNT(*) AS total_lines,
    COUNT(DISTINCT catalog_item_id) AS unique_items,
    COUNT(*) FILTER (WHERE source = 'bom_component') AS bom_component_lines,
    COUNT(*) FILTER (WHERE source = 'quote_line_component') AS quote_line_component_lines,
    COUNT(*) FILTER (WHERE source = 'assembly_child') AS assembly_child_lines,
    SUM(qty) AS total_qty,
    SUM(total_cost_exw) AS total_cost_exw,
    SUM(total_msrp_sale_out) AS total_msrp_sale_out
FROM vw_bom_instance_flat
GROUP BY 
    bom_instance_id,
    organization_id,
    bom_template_id,
    bom_created_at
ORDER BY bom_created_at DESC;


