-- ====================================================
-- Verify Diagnostic Results
-- ====================================================
-- This script helps verify the diagnostic function results
-- and identify any remaining issues
-- ====================================================

-- Step 1: Check total items vs invalid items
SELECT 
    COUNT(*) as total_items,
    COUNT(*) FILTER (WHERE is_valid = true) as valid_items,
    COUNT(*) FILTER (WHERE is_valid = false) as invalid_items
FROM diagnostic_invalid_uom_measure_basis();

-- Step 2: Show invalid items only (if any)
-- Note: cost_uom may not exist if migration 188 hasn't run yet
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
ORDER BY measure_basis, uom;

-- Step 3: Show items with measure_basis=linear_m and uom=PCS/EA (should be 0 after fix)
-- Note: cost_uom may not exist if migration 188 hasn't run yet
SELECT 
    id,
    sku,
    item_name,
    measure_basis,
    uom,
    public.validate_uom_measure_basis(measure_basis, uom) as is_valid
FROM "CatalogItems"
WHERE measure_basis = 'linear_m'
AND UPPER(TRIM(COALESCE(uom, ''))) IN ('PCS', 'PIECE', 'PIECES', 'EA', 'EACH')
AND deleted = false
ORDER BY sku;

-- Step 4: Distribution of UOM for linear_m items
SELECT 
    uom,
    COUNT(*) as count,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as percentage
FROM "CatalogItems"
WHERE measure_basis = 'linear_m'
AND deleted = false
GROUP BY uom
ORDER BY count DESC;

-- Step 5: Items with NULL measure_basis or uom (should be handled)
SELECT 
    COUNT(*) as items_with_null_measure_basis,
    COUNT(*) FILTER (WHERE uom IS NULL) as items_with_null_uom,
    COUNT(*) FILTER (WHERE measure_basis IS NULL AND uom IS NULL) as items_with_both_null
FROM "CatalogItems"
WHERE deleted = false;

-- Summary
DO $$
DECLARE
    v_total_items integer;
    v_valid_items integer;
    v_invalid_items integer;
    v_pcs_items integer;
BEGIN
    SELECT COUNT(*) INTO v_total_items FROM diagnostic_invalid_uom_measure_basis();
    SELECT COUNT(*) INTO v_valid_items FROM diagnostic_invalid_uom_measure_basis() WHERE is_valid = true;
    SELECT COUNT(*) INTO v_invalid_items FROM diagnostic_invalid_uom_measure_basis() WHERE is_valid = false;
    
    SELECT COUNT(*) INTO v_pcs_items
    FROM "CatalogItems"
    WHERE measure_basis = 'linear_m'
    AND UPPER(TRIM(COALESCE(uom, ''))) IN ('PCS', 'PIECE', 'PIECES', 'EA', 'EACH')
    AND deleted = false;
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 Diagnostic Summary:';
    RAISE NOTICE '   Total items checked: %', v_total_items;
    RAISE NOTICE '   Valid items: %', v_valid_items;
    RAISE NOTICE '   Invalid items: %', v_invalid_items;
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Items with measure_basis=linear_m and uom=PCS/EA: %', v_pcs_items;
    RAISE NOTICE '';
    
    IF v_invalid_items = 0 AND v_pcs_items = 0 THEN
        RAISE NOTICE '✅ All items are valid! No fixes needed.';
    ELSIF v_pcs_items > 0 THEN
        RAISE NOTICE '⚠️  Found % items with linear_m/PCS that need fixing.', v_pcs_items;
        RAISE NOTICE '   Run: \i scripts/FIX_INVALID_UOM_MEASURE_BASIS.sql';
    ELSIF v_invalid_items > 0 THEN
        RAISE NOTICE '⚠️  Found % invalid items. Review the invalid items query above.', v_invalid_items;
    END IF;
    RAISE NOTICE '';
END $$;

