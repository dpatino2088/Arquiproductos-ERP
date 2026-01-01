-- ============================================================================
-- FIX UOM FOR ALL PRODUCTS - Comprehensive Review and Correction
-- ============================================================================
-- This script reviews and corrects UOM (Unit of Measure) for all products
-- based on established rules:
--   - Tubes (RTU-*, TUBE-*): Should be in linear units (mts, yd, ft), NOT "ea"
--   - Fabrics (is_fabric = true): Should be in area/linear units (m2, mts, yd2, yd, ft2, ft), NEVER "ea"
--   - Profiles/Rails (RCA-*, RC-*): Should be in linear units (mts, yd, ft), NOT "ea"
--   - Accessories/Components: Can be "ea", "pcs", "set", "pack"
-- ============================================================================

DO $$
DECLARE
    v_updated_count INTEGER := 0;
    v_tube_count INTEGER := 0;
    v_fabric_count INTEGER := 0;
    v_profile_count INTEGER := 0;
    v_other_count INTEGER := 0;
    v_total_reviewed INTEGER := 0;
    rec RECORD;
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '🔍 REVIEWING AND FIXING UOM FOR ALL PRODUCTS';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '';

    -- Step 1: Review and fix TUBES (should be linear units, NOT "ea")
    RAISE NOTICE '📊 Step 1: Reviewing TUBES (RTU-*, TUBE-*)...';
    
    FOR rec IN
        SELECT 
            id,
            sku,
            item_name,
            uom,
            is_fabric,
            measure_basis,
            CASE 
                WHEN sku ILIKE '%RTU%' OR sku ILIKE '%TUBE%' OR item_name ILIKE '%tube%' OR item_name ILIKE '%tubo%'
                THEN 'mts'  -- Tubes should be in meters
                ELSE NULL
            END AS correct_uom
        FROM "CatalogItems"
        WHERE deleted = false
            AND (
                sku ILIKE '%RTU%' 
                OR sku ILIKE '%TUBE%'
                OR item_name ILIKE '%tube%'
                OR item_name ILIKE '%tubo%'
            )
            AND (uom IS NULL OR uom = 'ea' OR uom NOT IN ('mts', 'yd', 'ft'))
    LOOP
        v_tube_count := v_tube_count + 1;
        RAISE NOTICE '   🔧 Tube: % (SKU: %) - Current UOM: % → Correcting to: %', 
            rec.item_name, rec.sku, COALESCE(rec.uom, 'NULL'), rec.correct_uom;
        
        UPDATE "CatalogItems"
        SET uom = rec.correct_uom,
            updated_at = NOW()
        WHERE id = rec.id;
        
        v_updated_count := v_updated_count + 1;
    END LOOP;
    
    RAISE NOTICE '   ✅ Fixed % tube(s)', v_tube_count;
    RAISE NOTICE '';

    -- Step 2: Review and fix FABRICS (should be area/linear, NEVER "ea")
    RAISE NOTICE '📊 Step 2: Reviewing FABRICS (is_fabric = true)...';
    
    FOR rec IN
        SELECT 
            id,
            sku,
            item_name,
            uom,
            fabric_pricing_mode,
            measure_basis,
            CASE 
                WHEN fabric_pricing_mode = 'per_sqm' THEN 'm2'
                WHEN fabric_pricing_mode = 'per_linear_m' THEN 'mts'
                WHEN uom IN ('m2', 'yd2', 'ft2', 'mts', 'yd', 'ft') THEN uom  -- Already correct
                WHEN measure_basis = 'fabric' AND uom IS NULL THEN 'm2'  -- Default to m2 for fabric
                ELSE 'm2'  -- Default fallback
            END AS correct_uom
        FROM "CatalogItems"
        WHERE deleted = false
            AND is_fabric = true
            AND (uom IS NULL OR uom = 'ea' OR uom NOT IN ('m2', 'yd2', 'ft2', 'mts', 'yd', 'ft'))
    LOOP
        v_fabric_count := v_fabric_count + 1;
        RAISE NOTICE '   🔧 Fabric: % (SKU: %) - Current UOM: % → Correcting to: %', 
            rec.item_name, rec.sku, COALESCE(rec.uom, 'NULL'), rec.correct_uom;
        
        UPDATE "CatalogItems"
        SET uom = rec.correct_uom,
            updated_at = NOW()
        WHERE id = rec.id;
        
        v_updated_count := v_updated_count + 1;
    END LOOP;
    
    RAISE NOTICE '   ✅ Fixed % fabric(s)', v_fabric_count;
    RAISE NOTICE '';

    -- Step 3: Review and fix PROFILES/RAILS (should be linear units, NOT "ea")
    RAISE NOTICE '📊 Step 3: Reviewing PROFILES/RAILS (RCA-*, RC-*, RCAS-*)...';
    
    FOR rec IN
        SELECT 
            id,
            sku,
            item_name,
            uom,
            CASE 
                WHEN sku ILIKE '%RCA-%' OR sku ILIKE '%RC-%' OR sku ILIKE '%RCAS-%'
                     OR item_name ILIKE '%rail%' OR item_name ILIKE '%profile%'
                     OR item_name ILIKE '%perfil%' OR item_name ILIKE '%barra%'
                THEN 'mts'  -- Profiles/rails should be in meters
                ELSE NULL
            END AS correct_uom
        FROM "CatalogItems"
        WHERE deleted = false
            AND (
                sku ILIKE '%RCA-%'
                OR sku ILIKE '%RC-%'
                OR sku ILIKE '%RCAS-%'
                OR item_name ILIKE '%rail%'
                OR item_name ILIKE '%profile%'
                OR item_name ILIKE '%perfil%'
                OR item_name ILIKE '%barra%'
            )
            AND is_fabric = false  -- Exclude fabrics
            AND (uom IS NULL OR uom = 'ea' OR uom NOT IN ('mts', 'yd', 'ft'))
    LOOP
        v_profile_count := v_profile_count + 1;
        RAISE NOTICE '   🔧 Profile/Rail: % (SKU: %) - Current UOM: % → Correcting to: %', 
            rec.item_name, rec.sku, COALESCE(rec.uom, 'NULL'), rec.correct_uom;
        
        UPDATE "CatalogItems"
        SET uom = rec.correct_uom,
            updated_at = NOW()
        WHERE id = rec.id;
        
        v_updated_count := v_updated_count + 1;
    END LOOP;
    
    RAISE NOTICE '   ✅ Fixed % profile(s)/rail(s)', v_profile_count;
    RAISE NOTICE '';

    -- Step 4: Review other products with NULL or invalid UOM
    RAISE NOTICE '📊 Step 4: Reviewing other products with NULL or invalid UOM...';
    
    FOR rec IN
        SELECT 
            id,
            sku,
            item_name,
            uom,
            is_fabric,
            measure_basis,
            CASE 
                WHEN is_fabric = true THEN 'm2'  -- Default fabric to m2
                WHEN measure_basis = 'linear_m' THEN 'mts'
                WHEN measure_basis = 'fabric' THEN 'm2'
                WHEN measure_basis = 'unit' THEN 'ea'
                ELSE 'ea'  -- Default to "ea" for other items
            END AS correct_uom
        FROM "CatalogItems"
        WHERE deleted = false
            AND uom IS NULL
            AND is_fabric = false  -- Fabrics already handled
            AND (
                sku NOT ILIKE '%RTU%' 
                AND sku NOT ILIKE '%TUBE%'
                AND sku NOT ILIKE '%RCA-%'
                AND sku NOT ILIKE '%RC-%'
                AND sku NOT ILIKE '%RCAS-%'
            )
    LOOP
        v_other_count := v_other_count + 1;
        RAISE NOTICE '   🔧 Other: % (SKU: %) - Current UOM: NULL → Setting to: %', 
            rec.item_name, rec.sku, rec.correct_uom;
        
        UPDATE "CatalogItems"
        SET uom = rec.correct_uom,
            updated_at = NOW()
        WHERE id = rec.id;
        
        v_updated_count := v_updated_count + 1;
    END LOOP;
    
    RAISE NOTICE '   ✅ Fixed % other product(s)', v_other_count;
    RAISE NOTICE '';

    -- Step 5: Summary Report
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '📊 SUMMARY REPORT';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '   Tubes corrected:     %', v_tube_count;
    RAISE NOTICE '   Fabrics corrected:    %', v_fabric_count;
    RAISE NOTICE '   Profiles/Rails corrected: %', v_profile_count;
    RAISE NOTICE '   Other products fixed: %', v_other_count;
    RAISE NOTICE '   ─────────────────────────────';
    RAISE NOTICE '   TOTAL UPDATED:        %', v_updated_count;
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '';

    -- Step 6: Verification - Show products that still have "ea" but should be linear
    RAISE NOTICE '🔍 VERIFICATION: Products with "ea" that might need review...';
    
    SELECT COUNT(*) INTO v_total_reviewed
    FROM "CatalogItems"
    WHERE deleted = false
        AND uom = 'ea'
        AND (
            sku ILIKE '%RTU%' 
            OR sku ILIKE '%TUBE%'
            OR sku ILIKE '%RCA-%'
            OR sku ILIKE '%RC-%'
            OR sku ILIKE '%RCAS-%'
            OR item_name ILIKE '%tube%'
            OR item_name ILIKE '%tubo%'
            OR item_name ILIKE '%rail%'
            OR item_name ILIKE '%profile%'
            OR item_name ILIKE '%perfil%'
        );
    
    IF v_total_reviewed > 0 THEN
        RAISE WARNING '   ⚠️  Found % product(s) with "ea" that might need linear UOM. Review manually:', v_total_reviewed;
        
        FOR rec IN
            SELECT sku, item_name, uom, is_fabric
            FROM "CatalogItems"
            WHERE deleted = false
                AND uom = 'ea'
                AND (
                    sku ILIKE '%RTU%' 
                    OR sku ILIKE '%TUBE%'
                    OR sku ILIKE '%RCA-%'
                    OR sku ILIKE '%RC-%'
                    OR sku ILIKE '%RCAS-%'
                    OR item_name ILIKE '%tube%'
                    OR item_name ILIKE '%tubo%'
                    OR item_name ILIKE '%rail%'
                    OR item_name ILIKE '%profile%'
                    OR item_name ILIKE '%perfil%'
                )
            ORDER BY sku
            LIMIT 20
        LOOP
            RAISE NOTICE '      - % (%) - UOM: %', rec.sku, rec.item_name, rec.uom;
        END LOOP;
    ELSE
        RAISE NOTICE '   ✅ No products found with incorrect "ea" UOM for linear items';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ UOM correction complete!';
    RAISE NOTICE '';

END $$;








