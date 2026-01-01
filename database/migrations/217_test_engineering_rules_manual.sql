-- ====================================================
-- TEST: Ejecutar engineering rules manualmente en un BomInstance
-- ====================================================
-- Ejecuta esto para probar la función en un BomInstance específico
-- ====================================================

-- Paso 1: Encuentra un BomInstance para probar
SELECT 
    bi.id as bom_instance_id,
    bi.bom_template_id,
    bi.sale_order_line_id,
    COUNT(bil.id) as bom_lines_count,
    COUNT(bil.id) FILTER (WHERE bil.part_role IN ('tube', 'bottom_rail_profile') AND bil.cut_length_mm IS NULL) as null_cuts_count
FROM "BomInstances" bi
LEFT JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id AND bil.deleted = false
WHERE bi.deleted = false
GROUP BY bi.id, bi.bom_template_id, bi.sale_order_line_id
HAVING COUNT(bil.id) FILTER (WHERE bil.part_role IN ('tube', 'bottom_rail_profile') AND bil.cut_length_mm IS NULL) > 0
LIMIT 5;

-- Paso 2: Reemplaza <BOM_INSTANCE_ID> con un ID del paso 1 y ejecuta:
-- SELECT public.apply_engineering_rules_to_bom_instance('<BOM_INSTANCE_ID>');

-- Paso 3: Verifica el resultado
-- SELECT 
--     bil.id,
--     bil.part_role,
--     bil.cut_length_mm,
--     bil.calc_notes
-- FROM "BomInstanceLines" bil
-- WHERE bil.bom_instance_id = '<BOM_INSTANCE_ID>'
-- AND bil.part_role IN ('tube', 'bottom_rail_profile')
-- ORDER BY bil.part_role;




