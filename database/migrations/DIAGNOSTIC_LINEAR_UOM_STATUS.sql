-- ====================================================
-- Diagnostic Queries for Linear UOM Migration Status
-- ====================================================
-- Run these queries to understand the current state
-- ====================================================

-- 1. Check if there are any tube lines at all
SELECT 
    COUNT(*) as total_tube_lines,
    COUNT(*) FILTER (WHERE uom = 'ea') as tube_with_ea,
    COUNT(*) FILTER (WHERE uom = 'm') as tube_with_m,
    COUNT(*) FILTER (WHERE cut_length_mm IS NULL) as tube_null_cuts,
    COUNT(*) FILTER (WHERE cut_length_mm IS NOT NULL) as tube_with_cuts
FROM "BomInstanceLines"
WHERE deleted = false
AND part_role = 'tube';

-- 2. Check bottom_rail_profile lines
SELECT 
    COUNT(*) as total_bottom_rail_lines,
    COUNT(*) FILTER (WHERE uom = 'ea') as bottom_rail_with_ea,
    COUNT(*) FILTER (WHERE uom = 'm') as bottom_rail_with_m,
    COUNT(*) FILTER (WHERE cut_length_mm IS NULL) as bottom_rail_null_cuts,
    COUNT(*) FILTER (WHERE cut_length_mm IS NOT NULL) as bottom_rail_with_cuts
FROM "BomInstanceLines"
WHERE deleted = false
AND part_role = 'bottom_rail_profile';

-- 3. Show sample tube lines with their current state
SELECT 
    resolved_sku,
    part_role,
    qty,
    uom,
    cut_length_mm,
    calc_notes
FROM "BomInstanceLines"
WHERE deleted = false
AND part_role = 'tube'
ORDER BY created_at DESC
LIMIT 10;

-- 4. Check if there are any BomInstances with tube lines
SELECT 
    COUNT(DISTINCT bil.bom_instance_id) as bom_instances_with_tubes
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bil.deleted = false
AND bi.deleted = false
AND bil.part_role = 'tube';

-- 5. Check if migration functions exist
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) IS NOT NULL as exists
FROM pg_proc p
INNER JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
AND p.proname IN (
    'is_linear_role',
    'convert_linear_roles_to_meters',
    'fix_null_part_roles',
    'apply_engineering_rules_and_convert_linear_uom',
    'backfill_linear_uom_and_cut_lengths'
)
ORDER BY p.proname;

-- 6. Check a specific BomInstance to see if it has dimensions
SELECT 
    bi.id as bom_instance_id,
    sol.width_m,
    sol.height_m,
    COUNT(bil.id) as total_lines,
    COUNT(bil.id) FILTER (WHERE bil.part_role = 'tube') as tube_lines,
    COUNT(bil.id) FILTER (WHERE bil.part_role = 'tube' AND bil.cut_length_mm IS NOT NULL) as tube_with_cuts
FROM "BomInstances" bi
INNER JOIN "SalesOrderLines" sol ON sol.id = bi.sale_order_line_id
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE bi.deleted = false
GROUP BY bi.id, sol.width_m, sol.height_m
HAVING COUNT(bil.id) FILTER (WHERE bil.part_role = 'tube') > 0
ORDER BY bi.created_at DESC
LIMIT 5;



