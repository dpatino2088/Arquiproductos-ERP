-- ====================================================
-- BOM Instance Views - Test and Validation Queries
-- ====================================================
-- These queries test the newly created views and validate BOM data integrity.
-- Run these queries to verify your BOM instances are healthy.
-- ====================================================

-- ====================================================
-- QUERY 1: Basic View Test - Show All BOM Instances
-- ====================================================
-- This query shows all BOM instances with their lines in a flat format.
-- Use this to verify the view is working correctly.
SELECT 
    bom_instance_id,
    organization_id,
    sale_order_id,
    sale_order_line_id,
    quote_line_id,
    bom_template_id,
    bom_created_at,
    COUNT(*) AS total_lines,
    SUM(total_cost_exw) AS total_cost,
    SUM(total_msrp_sale_out) AS total_msrp
FROM vw_bom_instance_flat
GROUP BY 
    bom_instance_id,
    organization_id,
    sale_order_id,
    sale_order_line_id,
    quote_line_id,
    bom_template_id,
    bom_created_at
ORDER BY bom_created_at DESC
LIMIT 10;

-- ====================================================
-- QUERY 2: View All BOM Lines (Detailed)
-- ====================================================
-- Shows all BOM lines with full details
SELECT 
    bom_instance_id,
    resolved_sku,
    part_role,
    qty,
    uom,
    category_code,
    source,
    parent_part_id,
    unit_cost_exw,
    total_cost_exw,
    unit_msrp_sale_out,
    total_msrp_sale_out,
    line_created_at
FROM vw_bom_instance_flat
ORDER BY bom_instance_id, part_role, resolved_sku
LIMIT 50;

-- ====================================================
-- QUERY 3: Validation A - Orphan Assembly Children
-- ====================================================
-- Expected result: 0 rows (all assembly_child should have parent_part_id)
-- If this returns rows, there's a data integrity issue.
SELECT 
    bom_instance_id,
    catalog_item_id,
    resolved_sku,
    part_role,
    source,
    parent_part_id
FROM vw_bom_validation_orphan_assembly_children;

-- ====================================================
-- QUERY 4: Validation B - Duplicate Items
-- ====================================================
-- Expected result: 0 rows (no duplicates should exist)
-- If this returns rows, the same item appears multiple times in the same BOM.
SELECT 
    bom_instance_id,
    parent_part_id,
    catalog_item_id,
    resolved_sku,
    part_role,
    uom,
    duplicate_count
FROM vw_bom_validation_duplicate_items
ORDER BY bom_instance_id, duplicate_count DESC;

-- ====================================================
-- QUERY 5: Validation C - Missing Qty or UOM
-- ====================================================
-- Expected result: 0 rows (all lines should have qty and uom)
-- If this returns rows, some BOM lines are incomplete.
SELECT 
    bom_instance_id,
    catalog_item_id,
    resolved_sku,
    part_role,
    qty,
    uom,
    source
FROM vw_bom_validation_missing_qty_uom;

-- ====================================================
-- QUERY 6: Validation D - Missing Parent in Same BOM
-- ====================================================
-- Expected result: 0 rows (all assembly_child should have parent in same BOM)
-- If this returns rows, an assembly child references a parent that doesn't exist.
SELECT 
    bom_instance_id,
    child_item_id,
    parent_part_id,
    child_sku,
    source
FROM vw_bom_validation_missing_parent;

-- ====================================================
-- QUERY 7: Summary Statistics (Using View)
-- ====================================================
-- Shows summary statistics for all BOM instances
SELECT 
    bom_instance_id,
    organization_id,
    bom_template_id,
    bom_created_at,
    total_lines,
    unique_items,
    bom_component_lines,
    quote_line_component_lines,
    assembly_child_lines,
    total_qty,
    total_cost_exw,
    total_msrp_sale_out
FROM vw_bom_instance_summary
ORDER BY bom_created_at DESC;

-- ====================================================
-- QUERY 8: BOM Lines by Source
-- ====================================================
-- Shows breakdown of BOM lines by their source
SELECT 
    bom_instance_id,
    source,
    COUNT(*) AS line_count,
    COUNT(DISTINCT catalog_item_id) AS unique_items,
    SUM(qty) AS total_qty,
    SUM(total_cost_exw) AS total_cost,
    SUM(total_msrp_sale_out) AS total_msrp
FROM vw_bom_instance_flat
GROUP BY bom_instance_id, source
ORDER BY bom_instance_id, source;

-- ====================================================
-- QUERY 9: BOM Lines by Category/Role
-- ====================================================
-- Shows breakdown by category_code and part_role
SELECT 
    bom_instance_id,
    category_code,
    part_role,
    COUNT(*) AS line_count,
    SUM(qty) AS total_qty,
    SUM(total_cost_exw) AS total_cost
FROM vw_bom_instance_flat
WHERE category_code IS NOT NULL
GROUP BY bom_instance_id, category_code, part_role
ORDER BY bom_instance_id, category_code, part_role;

-- ====================================================
-- QUERY 10: Assembly Children with Parent Details
-- ====================================================
-- Shows assembly children and their parent information
SELECT 
    child.bom_instance_id,
    child.resolved_sku AS child_sku,
    child.part_role AS child_role,
    child.qty AS child_qty,
    child.uom AS child_uom,
    child.total_cost_exw AS child_cost,
    parent.resolved_sku AS parent_sku,
    parent.part_role AS parent_role,
    parent.qty AS parent_qty
FROM vw_bom_instance_flat child
LEFT JOIN vw_bom_instance_flat parent 
    ON parent.bom_instance_id = child.bom_instance_id
    AND parent.catalog_item_id = child.parent_part_id
WHERE child.source = 'assembly_child'
ORDER BY child.bom_instance_id, child.resolved_sku;

-- ====================================================
-- QUERY 11: Cost Breakdown by BOM Instance
-- ====================================================
-- Shows cost breakdown including labor costs
SELECT DISTINCT
    bom_instance_id,
    organization_id,
    sale_order_id,
    bom_template_id,
    bom_created_at,
    labor_cost,
    total_cost_with_labor,
    total_msrp_sale_out_with_labor,
    SUM(total_cost_exw) OVER (PARTITION BY bom_instance_id) AS material_cost,
    SUM(total_msrp_sale_out) OVER (PARTITION BY bom_instance_id) AS material_msrp,
    COUNT(*) OVER (PARTITION BY bom_instance_id) AS total_lines
FROM vw_bom_instance_flat
ORDER BY bom_created_at DESC;

-- ====================================================
-- QUERY 12: Find BOMs with Issues (Combined Validation)
-- ====================================================
-- Shows all BOM instances that have any validation issues
SELECT DISTINCT
    bi.bom_instance_id,
    bi.organization_id,
    bi.bom_template_id,
    bi.bom_created_at,
    CASE 
        WHEN EXISTS (SELECT 1 FROM vw_bom_validation_orphan_assembly_children v WHERE v.bom_instance_id = bi.bom_instance_id) 
        THEN 'HAS_ORPHAN_CHILDREN'
        ELSE NULL
    END AS issue_1,
    CASE 
        WHEN EXISTS (SELECT 1 FROM vw_bom_validation_duplicate_items v WHERE v.bom_instance_id = bi.bom_instance_id) 
        THEN 'HAS_DUPLICATES'
        ELSE NULL
    END AS issue_2,
    CASE 
        WHEN EXISTS (SELECT 1 FROM vw_bom_validation_missing_qty_uom v WHERE v.bom_instance_id = bi.bom_instance_id) 
        THEN 'MISSING_QTY_UOM'
        ELSE NULL
    END AS issue_3,
    CASE 
        WHEN EXISTS (SELECT 1 FROM vw_bom_validation_missing_parent v WHERE v.bom_instance_id = bi.bom_instance_id) 
        THEN 'MISSING_PARENT'
        ELSE NULL
    END AS issue_4
FROM vw_bom_instance_flat bi
WHERE 
    EXISTS (SELECT 1 FROM vw_bom_validation_orphan_assembly_children v WHERE v.bom_instance_id = bi.bom_instance_id)
    OR EXISTS (SELECT 1 FROM vw_bom_validation_duplicate_items v WHERE v.bom_instance_id = bi.bom_instance_id)
    OR EXISTS (SELECT 1 FROM vw_bom_validation_missing_qty_uom v WHERE v.bom_instance_id = bi.bom_instance_id)
    OR EXISTS (SELECT 1 FROM vw_bom_validation_missing_parent v WHERE v.bom_instance_id = bi.bom_instance_id)
ORDER BY bi.bom_created_at DESC;

-- ====================================================
-- QUERY 13: Recent BOM Activity
-- ====================================================
-- Shows recently created BOM instances with line counts
WITH bom_stats AS (
    SELECT 
        bom_instance_id,
        organization_id,
        sale_order_id,
        bom_template_id,
        bom_created_at,
        COUNT(*) AS total_lines,
        COUNT(DISTINCT catalog_item_id) AS unique_items,
        COUNT(*) FILTER (WHERE source = 'bom_component') AS bom_component_lines,
        COUNT(*) FILTER (WHERE source = 'quote_line_component') AS quote_line_component_lines,
        COUNT(*) FILTER (WHERE source = 'assembly_child') AS assembly_child_lines,
        SUM(total_cost_exw) AS total_cost_exw,
        SUM(total_msrp_sale_out) AS total_msrp_sale_out
    FROM vw_bom_instance_flat
    WHERE bom_created_at >= NOW() - INTERVAL '30 days'
    GROUP BY 
        bom_instance_id,
        organization_id,
        sale_order_id,
        bom_template_id,
        bom_created_at
)
SELECT 
    bom_instance_id,
    organization_id,
    sale_order_id,
    bom_template_id,
    bom_created_at,
    total_lines,
    unique_items,
    bom_component_lines,
    quote_line_component_lines,
    assembly_child_lines,
    ROUND(total_cost_exw::numeric, 2) AS total_cost,
    ROUND(total_msrp_sale_out::numeric, 2) AS total_msrp
FROM bom_stats
ORDER BY bom_created_at DESC;

-- ====================================================
-- QUERY 14: BOM Health Check (All Validations in One)
-- ====================================================
-- Comprehensive health check - should return 0 rows if all is well
SELECT 
    'ORPHAN_ASSEMBLY_CHILDREN' AS validation_type,
    COUNT(*) AS issue_count
FROM vw_bom_validation_orphan_assembly_children
UNION ALL
SELECT 
    'DUPLICATE_ITEMS' AS validation_type,
    COUNT(*) AS issue_count
FROM vw_bom_validation_duplicate_items
UNION ALL
SELECT 
    'MISSING_QTY_UOM' AS validation_type,
    COUNT(*) AS issue_count
FROM vw_bom_validation_missing_qty_uom
UNION ALL
SELECT 
    'MISSING_PARENT' AS validation_type,
    COUNT(*) AS issue_count
FROM vw_bom_validation_missing_parent
ORDER BY issue_count DESC, validation_type;

