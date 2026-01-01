-- ====================================================
-- VERIFICAR RESULTADOS DE MIGRACIÓN 216
-- ====================================================
-- Verificar si hay BomInstances que aún tienen cut_length_mm NULL
-- y si la migración funcionó correctamente
-- ====================================================

-- 1. Contar BomInstances que aún tienen cut_length_mm NULL
SELECT 
    COUNT(DISTINCT bi.id) as bom_instances_with_null_cuts,
    COUNT(DISTINCT bil.id) as bom_lines_with_null_cuts
FROM "BomInstances" bi
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE bi.deleted = false
AND bil.deleted = false
AND bil.part_role IN ('tube', 'bottom_rail_profile')
AND bil.cut_length_mm IS NULL;

-- 2. Ver algunos ejemplos de BomInstanceLines con cut_length_mm NULL (si los hay)
SELECT 
    bi.id as bom_instance_id,
    bil.id as bom_line_id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.cut_length_mm,
    bil.calc_notes
FROM "BomInstances" bi
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE bi.deleted = false
AND bil.deleted = false
AND bil.part_role IN ('tube', 'bottom_rail_profile')
AND bil.cut_length_mm IS NULL
ORDER BY bi.created_at DESC
LIMIT 10;

-- 3. Ver algunos ejemplos de BomInstanceLines con cut_length_mm calculado (éxito)
SELECT 
    bi.id as bom_instance_id,
    bil.id as bom_line_id,
    bil.resolved_sku,
    bil.part_role,
    bil.qty,
    bil.uom,
    bil.cut_length_mm,
    bil.calc_notes
FROM "BomInstances" bi
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE bi.deleted = false
AND bil.deleted = false
AND bil.part_role IN ('tube', 'bottom_rail_profile')
AND bil.cut_length_mm IS NOT NULL
ORDER BY bi.created_at DESC
LIMIT 10;

-- 4. Resumen por rol
SELECT
    bil.part_role,
    COUNT(*) as total_lines,
    COUNT(*) FILTER (WHERE bil.cut_length_mm IS NULL) as null_count,
    COUNT(*) FILTER (WHERE bil.cut_length_mm IS NOT NULL) as calculated_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE bil.cut_length_mm IS NOT NULL) / COUNT(*), 2) as percentage_calculated
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bi.deleted = false
AND bil.deleted = false
AND bil.part_role IN ('tube', 'bottom_rail_profile')
GROUP BY bil.part_role
ORDER BY bil.part_role;




