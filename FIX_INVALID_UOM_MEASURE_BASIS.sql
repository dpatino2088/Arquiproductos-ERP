-- ====================================================
-- Fix Invalid UOM/Measure Basis Pairs
-- ====================================================
-- This script fixes CatalogItems with invalid UOM/measure_basis combinations
-- Based on CSV analysis showing items with measure_basis=linear_m but uom=PCS
-- ====================================================

-- Fix: Items with measure_basis=linear_m but uom=PCS
-- These should have uom='m' (meters) instead of 'PCS'
UPDATE "CatalogItems"
SET uom = 'm'
WHERE measure_basis = 'linear_m'
AND UPPER(TRIM(COALESCE(uom, ''))) IN ('PCS', 'PIECE', 'PIECES', 'EA', 'EACH')
AND deleted = false;

-- Verify the fix
SELECT 
    id,
    sku,
    item_name,
    measure_basis,
    uom,
    public.validate_uom_measure_basis(measure_basis, uom) as is_valid
FROM "CatalogItems"
WHERE measure_basis = 'linear_m'
AND deleted = false
ORDER BY is_valid, sku;

-- Summary
DO $$
DECLARE
    v_fixed_count integer;
    v_remaining_invalid integer;
BEGIN
    SELECT COUNT(*) INTO v_fixed_count
    FROM "CatalogItems"
    WHERE measure_basis = 'linear_m'
    AND UPPER(TRIM(COALESCE(uom, ''))) = 'M'
    AND deleted = false;
    
    SELECT COUNT(*) INTO v_remaining_invalid
    FROM "CatalogItems"
    WHERE deleted = false
    AND measure_basis IS NOT NULL
    AND uom IS NOT NULL
    AND NOT public.validate_uom_measure_basis(measure_basis, uom);
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Fixed items with measure_basis=linear_m: % items now have uom=m', v_fixed_count;
    RAISE NOTICE '⚠️  Remaining invalid UOM/measure_basis pairs: %', v_remaining_invalid;
    RAISE NOTICE '';
    RAISE NOTICE 'Run diagnostic query to see remaining issues:';
    RAISE NOTICE 'SELECT * FROM diagnostic_invalid_uom_measure_basis() WHERE is_valid = false;';
    RAISE NOTICE '';
END $$;





