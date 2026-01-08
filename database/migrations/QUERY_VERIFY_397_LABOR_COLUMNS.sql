-- ====================================================
-- Query de Verificación: Migración 397 - Columnas de Labor
-- ====================================================
-- Verifica que las columnas de labor se hayan creado correctamente
-- ====================================================

-- 1. Verificar columnas en BomInstances
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'BomInstances'
AND column_name IN ('labor_cost', 'total_cost_with_labor', 'total_msrp_sale_out_with_labor')
ORDER BY column_name;

-- 2. Verificar columnas en BomInstanceLines
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'BomInstanceLines'
AND column_name IN ('unit_msrp_sale_out', 'total_msrp_sale_out')
ORDER BY column_name;

-- 3. Verificar que la función generate_bom_for_manufacturing_order existe y tiene los parámetros correctos
SELECT 
    p.proname AS function_name,
    pg_get_function_arguments(p.oid) AS arguments,
    pg_get_functiondef(p.oid) LIKE '%labor_percentage%' AS has_labor_logic
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.proname = 'generate_bom_for_manufacturing_order';

-- 4. Verificar que CostSettings tiene la columna labor_percentage
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'CostSettings'
AND column_name = 'labor_percentage';

-- 5. Mostrar un ejemplo de BomInstance con labor (si existe)
SELECT 
    id,
    labor_cost,
    total_cost_with_labor,
    total_msrp_sale_out_with_labor,
    created_at
FROM "BomInstances"
WHERE labor_cost IS NOT NULL
OR total_cost_with_labor IS NOT NULL
OR total_msrp_sale_out_with_labor IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;


