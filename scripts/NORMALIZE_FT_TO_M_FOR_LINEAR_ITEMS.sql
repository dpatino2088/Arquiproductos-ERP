-- ====================================================
-- Script: Normalize FT (feet) to M (meters) for linear_m items
-- ====================================================
-- ⚠️  OPTIONAL: Normalize UOM from FT to m for consistency
-- ⚠️  WARNING: This is NOT required (FT is valid), but improves consistency
-- ⚠️  DO NOT execute unless you have confirmed cost_exw is per meter (not per foot)
-- ====================================================

-- ====================================================
-- STEP 1: Analysis - Check current state
-- ====================================================

DO $$
DECLARE
    v_has_cost_uom boolean;
    v_ft_count integer;
    v_ft_with_ft_cost integer;
    v_m_count integer;
    v_sample_cost numeric;
BEGIN
    -- Check if cost_uom column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'cost_uom'
    ) INTO v_has_cost_uom;
    
    SELECT COUNT(*) INTO v_ft_count
    FROM "CatalogItems"
    WHERE measure_basis = 'linear_m'
    AND UPPER(TRIM(COALESCE(uom, ''))) = 'FT'
    AND deleted = false;
    
    SELECT COUNT(*) INTO v_m_count
    FROM "CatalogItems"
    WHERE measure_basis = 'linear_m'
    AND UPPER(TRIM(COALESCE(uom, ''))) = 'M'
    AND deleted = false;
    
    -- Get sample cost for analysis
    SELECT AVG(cost_exw) INTO v_sample_cost
    FROM "CatalogItems"
    WHERE measure_basis = 'linear_m'
    AND UPPER(TRIM(COALESCE(uom, ''))) = 'FT'
    AND cost_exw IS NOT NULL
    AND cost_exw > 0
    AND deleted = false;
    
    IF v_has_cost_uom THEN
        SELECT COUNT(*) INTO v_ft_with_ft_cost
        FROM "CatalogItems"
        WHERE measure_basis = 'linear_m'
        AND UPPER(TRIM(COALESCE(uom, ''))) = 'FT'
        AND UPPER(TRIM(COALESCE(cost_uom, ''))) IN ('FT', 'FEET', 'FOOT')
        AND deleted = false;
        
        RAISE NOTICE '';
        RAISE NOTICE '📊 Current state:';
        RAISE NOTICE '   Items with measure_basis=linear_m and uom=FT: %', v_ft_count;
        RAISE NOTICE '   Items with measure_basis=linear_m and uom=M: %', v_m_count;
        RAISE NOTICE '   Items with uom=FT and cost_uom=FT: %', v_ft_with_ft_cost;
        RAISE NOTICE '   Average cost_exw for FT items: %', ROUND(COALESCE(v_sample_cost, 0), 4);
        RAISE NOTICE '';
        RAISE NOTICE '💡 Recommendation:';
        IF v_ft_with_ft_cost > 0 THEN
            RAISE NOTICE '   ⚠️  Use Option B (convert cost from per foot to per meter)';
            RAISE NOTICE '   ⚠️  % items have cost_uom=FT, so cost_exw is per foot', v_ft_with_ft_cost;
        ELSE
            RAISE NOTICE '   ✅ Use Option A (simple UOM change, cost already per meter)';
            RAISE NOTICE '   ✅ No items have cost_uom=FT, assuming cost_exw is per meter';
        END IF;
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '📊 Current state:';
        RAISE NOTICE '   Items with measure_basis=linear_m and uom=FT: %', v_ft_count;
        RAISE NOTICE '   Items with measure_basis=linear_m and uom=M: %', v_m_count;
        RAISE NOTICE '   Average cost_exw for FT items: %', ROUND(COALESCE(v_sample_cost, 0), 4);
        RAISE NOTICE '   cost_uom column does not exist';
        RAISE NOTICE '';
        RAISE NOTICE '⚠️  WARNING:';
        RAISE NOTICE '   You must manually verify if cost_exw is per meter or per foot!';
        RAISE NOTICE '   - If per meter: Use Option A';
        RAISE NOTICE '   - If per foot: Use Option B';
    END IF;
    RAISE NOTICE '';
    RAISE NOTICE 'ℹ️  Note: FT is VALID for linear_m (no error), but m is more consistent.';
    RAISE NOTICE '   This normalization is OPTIONAL and should only be done after';
    RAISE NOTICE '   confirming the cost_exw UOM.';
    RAISE NOTICE '';
END $$;

-- ====================================================
-- STEP 2: Preview what will change (run this first!)
-- ====================================================

SELECT 
    id,
    sku,
    item_name,
    uom as current_uom,
    cost_exw as current_cost_exw,
    cost_uom as current_cost_uom,
    'm' as new_uom,
    CASE 
        WHEN UPPER(TRIM(COALESCE(cost_uom, ''))) IN ('FT', 'FEET', 'FOOT') 
        THEN cost_exw / 3.28084
        ELSE cost_exw
    END as new_cost_exw,
    CASE 
        WHEN UPPER(TRIM(COALESCE(cost_uom, ''))) IN ('FT', 'FEET', 'FOOT')
        THEN 'm'
        ELSE cost_uom
    END as new_cost_uom
FROM "CatalogItems"
WHERE measure_basis = 'linear_m'
AND UPPER(TRIM(COALESCE(uom, ''))) = 'FT'
AND deleted = false
ORDER BY sku
LIMIT 20;  -- Preview first 20

-- ====================================================
-- OPTION A: Simple UOM change (if cost_exw is already per meter)
-- ====================================================
-- ⚠️  WARNING: Only use if cost_exw is already in "per meter"
-- ⚠️  DO NOT execute if cost_exw is in "per foot" (use Option B instead)
-- 
-- Uncomment to execute:
/*
UPDATE "CatalogItems"
SET uom = 'm'
WHERE measure_basis = 'linear_m'
AND UPPER(TRIM(COALESCE(uom, ''))) = 'FT'
AND deleted = false;
*/

-- ====================================================
-- OPTION B: UOM change + cost conversion (if cost_exw is per foot)
-- ====================================================
-- ⚠️  WARNING: Only use if cost_exw is in "per foot"
-- ⚠️  This converts: cost_per_meter = cost_per_foot / 3.28084
-- 
-- Uncomment to execute:
/*
UPDATE "CatalogItems"
SET 
    uom = 'm',
    cost_exw = CASE 
        WHEN cost_exw IS NOT NULL AND cost_exw > 0 
        THEN cost_exw / 3.28084  -- Convert cost from per foot to per meter
        ELSE cost_exw
    END,
    cost_uom = CASE 
        WHEN cost_uom IS NOT NULL AND UPPER(TRIM(cost_uom)) IN ('FT', 'FEET', 'FOOT')
        THEN 'm'
        ELSE cost_uom
    END
WHERE measure_basis = 'linear_m'
AND UPPER(TRIM(COALESCE(uom, ''))) = 'FT'
AND deleted = false;
*/

-- ====================================================
-- Verification after normalization (run after Option A or B)
-- ====================================================
/*
SELECT 
    COUNT(*) as total_linear_m_items,
    COUNT(CASE WHEN UPPER(TRIM(COALESCE(uom, ''))) = 'M' THEN 1 END) as uom_m_count,
    COUNT(CASE WHEN UPPER(TRIM(COALESCE(uom, ''))) = 'FT' THEN 1 END) as uom_ft_count,
    COUNT(CASE WHEN UPPER(TRIM(COALESCE(uom, ''))) = 'YD' THEN 1 END) as uom_yd_count
FROM "CatalogItems"
WHERE measure_basis = 'linear_m'
AND deleted = false;
*/





