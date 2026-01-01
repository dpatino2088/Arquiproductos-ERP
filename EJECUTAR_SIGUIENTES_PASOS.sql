-- ====================================================
-- Siguientes Pasos: Verificación y Fixes
-- ====================================================
-- Ejecuta estos pasos en orden después de la migración 188
-- ====================================================

-- ====================================================
-- PASO 1: Verificar estado actual
-- ====================================================
-- Verifica si hay items inválidos y el estado general
SELECT 
    COUNT(*) as total_items,
    COUNT(*) FILTER (WHERE is_valid = true) as valid_items,
    COUNT(*) FILTER (WHERE is_valid = false) as invalid_items
FROM diagnostic_invalid_uom_measure_basis();

-- Ver items inválidos (si hay)
SELECT 
    catalog_item_id,
    sku,
    item_name,
    measure_basis,
    uom,
    is_valid,
    validation_note
FROM diagnostic_invalid_uom_measure_basis()
WHERE is_valid = false
ORDER BY measure_basis, uom
LIMIT 20;

-- Verificar items con measure_basis=linear_m y uom=PCS/EA (deberían ser 0 después del fix)
SELECT 
    COUNT(*) as items_with_pcs_ea
FROM "CatalogItems"
WHERE measure_basis = 'linear_m'
AND UPPER(TRIM(COALESCE(uom, ''))) IN ('PCS', 'PIECE', 'PIECES', 'EA', 'EACH')
AND deleted = false;

-- ====================================================
-- PASO 2: Si hay items inválidos, ejecutar fix
-- ====================================================
-- Si el query anterior muestra items inválidos, ejecuta:
-- \i scripts/FIX_INVALID_UOM_MEASURE_BASIS.sql

-- ====================================================
-- PASO 3: Verificar que cost_uom fue creado y backfilled
-- ====================================================
SELECT 
    COUNT(*) as total_items,
    COUNT(cost_uom) as items_with_cost_uom,
    COUNT(*) - COUNT(cost_uom) as items_without_cost_uom
FROM "CatalogItems"
WHERE deleted = false;

-- Ver algunos ejemplos
SELECT 
    sku,
    item_name,
    uom,
    cost_uom,
    cost_exw
FROM "CatalogItems"
WHERE deleted = false
AND cost_uom IS NOT NULL
LIMIT 10;

-- ====================================================
-- PASO 4: Ejecutar migración 189 (fix formato)
-- ====================================================
-- Ejecuta: \i database/migrations/189_fix_bom_backfill_format_error.sql

-- ====================================================
-- PASO 5: Re-ejecutar backfill (después de migración 189)
-- ====================================================
-- Ejecuta: SELECT * FROM backfill_bom_lines_base_pricing();

-- Verificar resultados del backfill
SELECT 
    COUNT(*) FILTER (WHERE updated = true) as success_count,
    COUNT(*) FILTER (WHERE updated = false) as error_count,
    COUNT(*) as total_lines
FROM backfill_bom_lines_base_pricing();

-- ====================================================
-- PASO 6: Verificación final
-- ====================================================
-- Verificar que no queden items inválidos
SELECT COUNT(*) as remaining_invalid
FROM diagnostic_invalid_uom_measure_basis() 
WHERE is_valid = false;

-- Verificar distribución de UOM en BOMs
SELECT * FROM diagnostic_bom_uom_summary()
ORDER BY category_code, uom_base
LIMIT 20;

-- Resumen final
DO $$
DECLARE
    v_invalid_count integer;
    v_backfill_success integer;
    v_backfill_errors integer;
BEGIN
    SELECT COUNT(*) INTO v_invalid_count
    FROM diagnostic_invalid_uom_measure_basis() 
    WHERE is_valid = false;
    
    SELECT 
        COUNT(*) FILTER (WHERE updated = true),
        COUNT(*) FILTER (WHERE updated = false)
    INTO v_backfill_success, v_backfill_errors
    FROM backfill_bom_lines_base_pricing();
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Estado Final:';
    RAISE NOTICE '   Items inválidos: %', v_invalid_count;
    RAISE NOTICE '   Backfill exitoso: %', v_backfill_success;
    RAISE NOTICE '   Backfill con errores: %', v_backfill_errors;
    RAISE NOTICE '';
    
    IF v_invalid_count = 0 AND v_backfill_errors = 0 THEN
        RAISE NOTICE '✅ ¡Todo listo! Sistema de UOM validado y funcionando.';
    ELSIF v_invalid_count > 0 THEN
        RAISE NOTICE '⚠️  Aún hay % items inválidos. Ejecuta: \i scripts/FIX_INVALID_UOM_MEASURE_BASIS.sql', v_invalid_count;
    ELSIF v_backfill_errors > 0 THEN
        RAISE NOTICE '⚠️  Backfill tiene % errores. Revisa los logs.', v_backfill_errors;
    END IF;
    RAISE NOTICE '';
END $$;





