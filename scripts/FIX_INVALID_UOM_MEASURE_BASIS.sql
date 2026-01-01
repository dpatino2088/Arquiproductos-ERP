-- ====================================================
-- Script: Fix Invalid UOM/Measure Basis Pairs
-- ====================================================
-- CRITICAL: Fixes CatalogItems with invalid UOM/measure_basis combinations
-- Based on analysis showing items with measure_basis=linear_m but uom=PCS
-- ====================================================

-- Step 1: Preview items that will be fixed
-- Note: cost_uom may not exist if migration 188 hasn't run yet
SELECT 
    id,
    sku,
    item_name,
    measure_basis,
    uom as current_uom,
    'm' as new_uom,
    cost_exw
FROM "CatalogItems"
WHERE measure_basis = 'linear_m'
AND UPPER(TRIM(COALESCE(uom, ''))) IN ('PCS', 'PIECE', 'PIECES', 'EA', 'EACH')
AND deleted = false
ORDER BY sku;

-- Step 2: Fix items with measure_basis=linear_m but uom=PCS/EA
-- These should have uom='m' (meters) instead
UPDATE "CatalogItems"
SET uom = 'm'
WHERE measure_basis = 'linear_m'
AND UPPER(TRIM(COALESCE(uom, ''))) IN ('PCS', 'PIECE', 'PIECES', 'EA', 'EACH')
AND deleted = false;

-- Step 3: Verify the fix
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

-- Step 4: Summary
DO $$
DECLARE
    v_fixed_count integer;
    v_remaining_invalid integer;
    v_total_linear_m integer;
BEGIN
    SELECT COUNT(*) INTO v_total_linear_m
    FROM "CatalogItems"
    WHERE measure_basis = 'linear_m'
    AND deleted = false;
    
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
    RAISE NOTICE '✅ Fix completed';
    RAISE NOTICE '';
    RAISE NOTICE '📊 Results:';
    RAISE NOTICE '   Total items with measure_basis=linear_m: %', v_total_linear_m;
    RAISE NOTICE '   Items with uom=m: %', v_fixed_count;
    RAISE NOTICE '   Remaining invalid UOM/measure_basis pairs: %', v_remaining_invalid;
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Verify remaining issues:';
    RAISE NOTICE '   SELECT * FROM diagnostic_invalid_uom_measure_basis() WHERE is_valid = false;';
    RAISE NOTICE '';
END $$;

