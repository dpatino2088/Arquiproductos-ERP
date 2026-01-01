-- ====================================================
-- VERIFICACIÓN RÁPIDA: Migraciones 214, 215, 216
-- ====================================================
-- Ejecuta esto para confirmar que todo funcionó
-- ====================================================

-- 1. Verificar migración 214: SalesOrders.deleted default
SELECT 
  column_name, 
  column_default, 
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'SalesOrders'
AND column_name = 'deleted';
-- ✅ Expected: column_default contiene 'false'

-- 2. Verificar migración 215: Función de engineering rules existe
SELECT 
  p.proname as function_name,
  CASE 
    WHEN p.proname = 'apply_engineering_rules_to_bom_instance' THEN '✅ Function exists'
    ELSE '❌ Function not found'
  END as status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'apply_engineering_rules_to_bom_instance'
AND n.nspname = 'public';
-- ✅ Expected: 1 row con function_name = 'apply_engineering_rules_to_bom_instance'

-- 3. Verificar migración 216: BomInstances con cut_length_mm NULL
SELECT 
    COUNT(DISTINCT bi.id) as bom_instances_with_null_cuts,
    COUNT(DISTINCT bil.id) as bom_lines_with_null_cuts
FROM "BomInstances" bi
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE bi.deleted = false
AND bil.deleted = false
AND bil.part_role IN ('tube', 'bottom_rail_profile')
AND bil.cut_length_mm IS NULL;
-- ✅ Expected: Si la migración funcionó, esto debería ser 0 o muy bajo

-- 4. Verificar BomInstances con cut_length_mm calculado (éxito)
SELECT 
    COUNT(DISTINCT bi.id) as bom_instances_with_cuts,
    COUNT(DISTINCT bil.id) as bom_lines_with_cuts
FROM "BomInstances" bi
INNER JOIN "BomInstanceLines" bil ON bil.bom_instance_id = bi.id
WHERE bi.deleted = false
AND bil.deleted = false
AND bil.part_role IN ('tube', 'bottom_rail_profile')
AND bil.cut_length_mm IS NOT NULL;
-- ✅ Expected: Debería haber registros aquí si la función funciona

-- 5. Resumen por rol
SELECT
    bil.part_role,
    COUNT(*) as total_lines,
    COUNT(*) FILTER (WHERE bil.cut_length_mm IS NULL) as null_count,
    COUNT(*) FILTER (WHERE bil.cut_length_mm IS NOT NULL) as calculated_count,
    ROUND(100.0 * COUNT(*) FILTER (WHERE bil.cut_length_mm IS NOT NULL) / NULLIF(COUNT(*), 0), 2) as percentage_calculated
FROM "BomInstanceLines" bil
INNER JOIN "BomInstances" bi ON bi.id = bil.bom_instance_id
WHERE bi.deleted = false
AND bil.deleted = false
AND bil.part_role IN ('tube', 'bottom_rail_profile')
GROUP BY bil.part_role
ORDER BY bil.part_role;
-- ✅ Expected: percentage_calculated debería ser > 0% (idealmente 100%)




