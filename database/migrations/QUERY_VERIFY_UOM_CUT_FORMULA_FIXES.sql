-- ====================================================
-- Verification Queries: UOM, Cut, and Formula Fixes
-- ====================================================
-- Run these queries after regenerating BOM to verify the fixes
-- ====================================================

-- ====================================================
-- Query 1: Check UOM distribution (should show m, m2, ea, not set/pcs)
-- ====================================================
-- Replace <BOM_INSTANCE_ID> with the actual bom_instance_id
-- ====================================================
SELECT 
    part_role,
    uom,
    COUNT(*) as line_count,
    SUM(qty) as total_qty
FROM "BomInstanceLines"
WHERE bom_instance_id = '<BOM_INSTANCE_ID>'::uuid
  AND deleted = false
GROUP BY part_role, uom
ORDER BY part_role, uom;

-- Expected results:
-- - tube, bottom_bar, bottom_rail, bottom_rail_profile should have uom='m' (not 'ft', 'set', 'pcs')
-- - fabric should have uom='m2'
-- - bracket, hardware, chain should have uom='ea' or 'm' (not 'set', 'pcs')
-- ====================================================

-- ====================================================
-- Query 2: Check cut_l_mm for linear components (should NOT be NULL)
-- ====================================================
SELECT 
    part_role,
    uom,
    qty,
    cut_l_mm,
    CASE 
        WHEN cut_l_mm IS NULL THEN '❌ MISSING'
        WHEN cut_l_mm = (qty * 1000) THEN '✅ CORRECT'
        ELSE '⚠️ MISMATCH'
    END as cut_status
FROM "BomInstanceLines"
WHERE bom_instance_id = '<BOM_INSTANCE_ID>'::uuid
  AND deleted = false
  AND part_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile')
ORDER BY part_role;

-- Expected results:
-- - cut_l_mm should NOT be NULL for linear components
-- - cut_l_mm should equal qty * 1000 (conversion from meters to millimeters)
-- ====================================================

-- ====================================================
-- Query 3: Check chain formula result (CHAIN_HEIGHT_FACTOR)
-- ====================================================
-- This query checks if the chain qty matches the expected formula:
-- qty = height_m * height_factor * mult
-- ====================================================
SELECT 
    bil.part_role,
    bil.qty as calculated_qty,
    bil.uom,
    ql.height_m,
    bc.qty_formula_code,
    bc.qty_formula_params,
    -- Calculate expected qty based on formula
    (ql.height_m * 
     COALESCE((bc.qty_formula_params->>'height_factor')::numeric, 0.75) * 
     COALESCE((bc.qty_formula_params->>'mult')::numeric, 2)) as expected_qty,
    -- Check if calculated matches expected
    CASE 
        WHEN ABS(bil.qty - (ql.height_m * 
                           COALESCE((bc.qty_formula_params->>'height_factor')::numeric, 0.75) * 
                           COALESCE((bc.qty_formula_params->>'mult')::numeric, 2))) < 0.01 
        THEN '✅ CORRECT'
        ELSE '❌ MISMATCH'
    END as formula_status
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "QuoteLines" ql ON ql.id = bi.quote_line_id
INNER JOIN "BOMComponents" bc ON bc.component_role = bil.part_role 
    AND bc.bom_template_id = bi.bom_template_id
    AND bc.qty_formula_code = 'CHAIN_HEIGHT_FACTOR'
    AND bc.deleted = false
WHERE bil.bom_instance_id = '<BOM_INSTANCE_ID>'::uuid
  AND bil.part_role = 'chain'
  AND bil.deleted = false
  AND bi.deleted = false
ORDER BY bil.created_at DESC
LIMIT 5;

-- Expected results:
-- - calculated_qty should match expected_qty (within 0.01 tolerance)
-- - formula_status should be '✅ CORRECT'
-- - If mult=2, the qty should be height_m * 0.75 * 2 = height_m * 1.5
-- ====================================================

-- ====================================================
-- Query 4: Summary check - All fixes applied correctly
-- ====================================================
SELECT 
    'UOM Normalization' as fix_type,
    COUNT(*) FILTER (WHERE uom IN ('set', 'pcs') AND part_role IN ('bracket', 'hardware', 'tube', 'bottom_bar', 'bottom_rail')) as issues_count,
    CASE 
        WHEN COUNT(*) FILTER (WHERE uom IN ('set', 'pcs') AND part_role IN ('bracket', 'hardware', 'tube', 'bottom_bar', 'bottom_rail')) = 0 
        THEN '✅ PASS'
        ELSE '❌ FAIL'
    END as status
FROM "BomInstanceLines"
WHERE bom_instance_id = '<BOM_INSTANCE_ID>'::uuid
  AND deleted = false

UNION ALL

SELECT 
    'Cut L for Linear Components' as fix_type,
    COUNT(*) FILTER (WHERE part_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile') AND cut_l_mm IS NULL) as issues_count,
    CASE 
        WHEN COUNT(*) FILTER (WHERE part_role IN ('tube','bottom_bar','bottom_rail','bottom_rail_profile') AND cut_l_mm IS NULL) = 0 
        THEN '✅ PASS'
        ELSE '❌ FAIL'
    END as status
FROM "BomInstanceLines"
WHERE bom_instance_id = '<BOM_INSTANCE_ID>'::uuid
  AND deleted = false

UNION ALL

SELECT 
    'Chain Formula (mult applied)' as fix_type,
    COUNT(*) FILTER (
        WHERE part_role = 'chain' 
        AND ABS(qty - (ql.height_m * 0.75 * 2)) > 0.01
    ) as issues_count,
    CASE 
        WHEN COUNT(*) FILTER (
            WHERE part_role = 'chain' 
            AND ABS(qty - (ql.height_m * 0.75 * 2)) > 0.01
        ) = 0 
        THEN '✅ PASS'
        ELSE '❌ FAIL'
    END as status
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
INNER JOIN "QuoteLines" ql ON ql.id = bi.quote_line_id
WHERE bil.bom_instance_id = '<BOM_INSTANCE_ID>'::uuid
  AND bil.part_role = 'chain'
  AND bil.deleted = false
  AND bi.deleted = false;

-- Expected results:
-- - All three fixes should show '✅ PASS'
-- ====================================================


