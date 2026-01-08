-- ====================================================
-- Migration: Create BOM Instance Flat View
-- ====================================================
-- Objective: Create a read-only view for auditing and UI consumption
-- of BOM instances and their lines, without modifying any data.
-- ====================================================

-- ====================================================
-- STEP 1: Create vw_bom_instance_flat View
-- ====================================================

-- Drop existing view first (to allow column changes)
DROP VIEW IF EXISTS public.vw_bom_instance_flat CASCADE;

CREATE VIEW public.vw_bom_instance_flat AS
SELECT 
    -- BomInstance fields
    bi.id AS bom_instance_id,
    bi.organization_id,
    sol.sale_order_id, -- Obtained via JOIN with SalesOrderLines
    bi.sale_order_line_id,
    bi.quote_line_id,
    bi.bom_template_id,
    bi.labor_cost,
    bi.total_cost_with_labor,
    bi.total_msrp_sale_out_with_labor,
    bi.created_at AS bom_created_at,
    bi.updated_at AS bom_updated_at,
    
    -- BomInstanceLines fields
    bil.id AS bom_line_id,
    bil.resolved_part_id AS catalog_item_id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    -- ✅ FIX: Add canonical UOM (normalized: ft->m, pcs->ea, set->ea)
    public.normalize_uom_to_canonical(bil.uom) AS uom_canonical,
    bil.description AS line_description,
    bil.category_code,
    bil.unit_cost_exw,
    bil.total_cost_exw,
    bil.unit_msrp_sale_out,
    bil.total_msrp_sale_out,
    bil.source,
    bil.parent_part_id,
    bil.created_at AS line_created_at,
    bil.updated_at AS line_updated_at,
    
    -- Additional useful fields for debugging/auditing
    bi.deleted AS bom_deleted,
    bil.deleted AS line_deleted
    
FROM "BomInstances" bi
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
LEFT JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
WHERE bi.deleted = false
  AND bil.deleted = false;

COMMENT ON VIEW public.vw_bom_instance_flat IS 
    'Read-only flattened view of BOM instances and their lines. Use for auditing, UI consumption, and validation queries. Filters out deleted records.';

-- ====================================================
-- STEP 2: Grant Permissions
-- ====================================================

GRANT SELECT ON public.vw_bom_instance_flat TO authenticated;

-- ====================================================
-- STEP 3: Validation Queries (for sanity checks)
-- ====================================================

-- Query A: Validate that no assembly_child exists without parent
-- Expected result: 0 rows (all assembly_child should have parent_part_id)
CREATE OR REPLACE VIEW public.vw_bom_validation_orphan_assembly_children AS
SELECT *
FROM public.vw_bom_instance_flat
WHERE source = 'assembly_child'
  AND parent_part_id IS NULL;

COMMENT ON VIEW public.vw_bom_validation_orphan_assembly_children IS 
    'Detects assembly_child lines without a parent_part_id. Should return 0 rows in a healthy system.';

GRANT SELECT ON public.vw_bom_validation_orphan_assembly_children TO authenticated;

-- Query B: Detect dangerous duplicates (same item + same parent in same BOM instance)
-- Expected result: 0 rows (no duplicates should exist)
CREATE OR REPLACE VIEW public.vw_bom_validation_duplicate_items AS
SELECT
    bom_instance_id,
    parent_part_id,
    catalog_item_id,
    resolved_sku,
    part_role,
    uom,
    COUNT(*) AS duplicate_count
FROM public.vw_bom_instance_flat
GROUP BY bom_instance_id, parent_part_id, catalog_item_id, resolved_sku, part_role, uom
HAVING COUNT(*) > 1;

COMMENT ON VIEW public.vw_bom_validation_duplicate_items IS 
    'Detects duplicate items in the same BOM instance (same catalog_item_id, same parent_part_id, same role, same uom). Should return 0 rows in a healthy system.';

GRANT SELECT ON public.vw_bom_validation_duplicate_items TO authenticated;

-- Query C: Detect lines without qty or uom
-- Expected result: 0 rows (all lines should have qty and uom)
CREATE OR REPLACE VIEW public.vw_bom_validation_missing_qty_uom AS
SELECT *
FROM public.vw_bom_instance_flat
WHERE qty IS NULL
   OR uom IS NULL
   OR TRIM(uom) = '';

COMMENT ON VIEW public.vw_bom_validation_missing_qty_uom IS 
    'Detects BOM lines missing qty or uom. Should return 0 rows in a healthy system.';

GRANT SELECT ON public.vw_bom_validation_missing_qty_uom TO authenticated;

-- ====================================================
-- STEP 4: Additional Useful Validation Queries
-- ====================================================

-- Query D: Detect assembly_child lines where parent doesn't exist in same BOM
CREATE OR REPLACE VIEW public.vw_bom_validation_missing_parent AS
SELECT 
    vf.bom_instance_id,
    vf.catalog_item_id AS child_item_id,
    vf.parent_part_id,
    vf.resolved_sku AS child_sku,
    vf.source
FROM public.vw_bom_instance_flat vf
WHERE vf.source = 'assembly_child'
  AND vf.parent_part_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM public.vw_bom_instance_flat vf_parent
    WHERE vf_parent.bom_instance_id = vf.bom_instance_id
      AND vf_parent.catalog_item_id = vf.parent_part_id
      AND vf_parent.source IN ('bom_component', 'quote_line_component')
  );

COMMENT ON VIEW public.vw_bom_validation_missing_parent IS 
    'Detects assembly_child lines where the parent item is not present in the same BOM instance. Should return 0 rows in a healthy system.';

GRANT SELECT ON public.vw_bom_validation_missing_parent TO authenticated;

-- Query E: Summary statistics per BOM instance
CREATE OR REPLACE VIEW public.vw_bom_instance_summary AS
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
FROM public.vw_bom_instance_flat
GROUP BY 
    bom_instance_id,
    organization_id,
    bom_template_id,
    bom_created_at;

COMMENT ON VIEW public.vw_bom_instance_summary IS 
    'Summary statistics per BOM instance: line counts, unique items, totals by source, and cost/MSRP totals.';

GRANT SELECT ON public.vw_bom_instance_summary TO authenticated;

