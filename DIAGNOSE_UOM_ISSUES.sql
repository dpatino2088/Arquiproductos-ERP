-- ============================================================================
-- DIAGNOSE UOM ISSUES - Review Current State
-- ============================================================================
-- This script reviews the current UOM state of all products to identify issues
-- ============================================================================

DO $$
DECLARE
    v_total_products INTEGER;
    v_tubes_with_ea INTEGER;
    v_fabrics_with_ea INTEGER;
    v_profiles_with_ea INTEGER;
    v_null_uom INTEGER;
    rec RECORD;
BEGIN
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '🔍 DIAGNOSING UOM ISSUES IN CATALOG ITEMS';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '';

    -- Total products
    SELECT COUNT(*) INTO v_total_products
    FROM "CatalogItems"
    WHERE deleted = false;
    
    RAISE NOTICE '📊 Total active products: %', v_total_products;
    RAISE NOTICE '';

    -- Tubes with "ea" UOM
    SELECT COUNT(*) INTO v_tubes_with_ea
    FROM "CatalogItems"
    WHERE deleted = false
        AND uom = 'ea'
        AND (
            sku ILIKE '%RTU%' 
            OR sku ILIKE '%TUBE%'
            OR item_name ILIKE '%tube%'
            OR item_name ILIKE '%tubo%'
        );
    
    RAISE NOTICE '🔴 TUBES with "ea" UOM (should be linear): %', v_tubes_with_ea;
    
    IF v_tubes_with_ea > 0 THEN
        RAISE NOTICE '   Details:';
        FOR rec IN
            SELECT sku, item_name, uom, measure_basis
            FROM "CatalogItems"
            WHERE deleted = false
                AND uom = 'ea'
                AND (
                    sku ILIKE '%RTU%' 
                    OR sku ILIKE '%TUBE%'
                    OR item_name ILIKE '%tube%'
                    OR item_name ILIKE '%tubo%'
                )
            ORDER BY sku
            LIMIT 20
        LOOP
            RAISE NOTICE '      - % (%) - UOM: %', rec.sku, rec.item_name, rec.uom;
        END LOOP;
    END IF;
    RAISE NOTICE '';

    -- Fabrics with "ea" UOM
    SELECT COUNT(*) INTO v_fabrics_with_ea
    FROM "CatalogItems"
    WHERE deleted = false
        AND is_fabric = true
        AND uom = 'ea';
    
    RAISE NOTICE '🔴 FABRICS with "ea" UOM (should be area/linear): %', v_fabrics_with_ea;
    
    IF v_fabrics_with_ea > 0 THEN
        RAISE NOTICE '   Details:';
        FOR rec IN
            SELECT sku, item_name, uom, fabric_pricing_mode, measure_basis
            FROM "CatalogItems"
            WHERE deleted = false
                AND is_fabric = true
                AND uom = 'ea'
            ORDER BY sku
            LIMIT 20
        LOOP
            RAISE NOTICE '      - % (%) - UOM: %, Pricing Mode: %', 
                rec.sku, rec.item_name, rec.uom, COALESCE(rec.fabric_pricing_mode, 'NULL');
        END LOOP;
    END IF;
    RAISE NOTICE '';

    -- Profiles/Rails with "ea" UOM
    SELECT COUNT(*) INTO v_profiles_with_ea
    FROM "CatalogItems"
    WHERE deleted = false
        AND is_fabric = false
        AND uom = 'ea'
        AND (
            sku ILIKE '%RCA-%'
            OR sku ILIKE '%RC-%'
            OR sku ILIKE '%RCAS-%'
            OR item_name ILIKE '%rail%'
            OR item_name ILIKE '%profile%'
            OR item_name ILIKE '%perfil%'
            OR item_name ILIKE '%barra%'
        );
    
    RAISE NOTICE '🔴 PROFILES/RAILS with "ea" UOM (should be linear): %', v_profiles_with_ea;
    
    IF v_profiles_with_ea > 0 THEN
        RAISE NOTICE '   Details:';
        FOR rec IN
            SELECT sku, item_name, uom, measure_basis
            FROM "CatalogItems"
            WHERE deleted = false
                AND is_fabric = false
                AND uom = 'ea'
                AND (
                    sku ILIKE '%RCA-%'
                    OR sku ILIKE '%RC-%'
                    OR sku ILIKE '%RCAS-%'
                    OR item_name ILIKE '%rail%'
                    OR item_name ILIKE '%profile%'
                    OR item_name ILIKE '%perfil%'
                    OR item_name ILIKE '%barra%'
                )
            ORDER BY sku
            LIMIT 20
        LOOP
            RAISE NOTICE '      - % (%) - UOM: %', rec.sku, rec.item_name, rec.uom;
        END LOOP;
    END IF;
    RAISE NOTICE '';

    -- Products with NULL UOM
    SELECT COUNT(*) INTO v_null_uom
    FROM "CatalogItems"
    WHERE deleted = false
        AND uom IS NULL;
    
    RAISE NOTICE '⚠️  Products with NULL UOM: %', v_null_uom;
    
    IF v_null_uom > 0 THEN
        RAISE NOTICE '   Sample (first 20):';
        FOR rec IN
            SELECT sku, item_name, is_fabric, measure_basis, fabric_pricing_mode
            FROM "CatalogItems"
            WHERE deleted = false
                AND uom IS NULL
            ORDER BY sku
            LIMIT 20
        LOOP
            RAISE NOTICE '      - % (%) - Fabric: %, Measure: %', 
                rec.sku, rec.item_name, rec.is_fabric, COALESCE(rec.measure_basis, 'NULL');
        END LOOP;
    END IF;
    RAISE NOTICE '';

    -- Summary by UOM type
    RAISE NOTICE '📊 UOM Distribution:';
    FOR rec IN
        SELECT 
            COALESCE(uom, 'NULL') AS uom_value,
            COUNT(*) AS count,
            COUNT(*) FILTER (WHERE is_fabric = true) AS fabric_count,
            COUNT(*) FILTER (WHERE sku ILIKE '%RTU%' OR sku ILIKE '%TUBE%') AS tube_count,
            COUNT(*) FILTER (WHERE sku ILIKE '%RCA-%' OR sku ILIKE '%RC-%' OR sku ILIKE '%RCAS-%') AS profile_count
        FROM "CatalogItems"
        WHERE deleted = false
        GROUP BY uom_value
        ORDER BY count DESC
    LOOP
        RAISE NOTICE '   %: % total (Fabrics: %, Tubes: %, Profiles: %)', 
            rec.uom_value, rec.count, rec.fabric_count, rec.tube_count, rec.profile_count;
    END LOOP;
    RAISE NOTICE '';

    -- Summary
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '📊 SUMMARY';
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '   Total products:           %', v_total_products;
    RAISE NOTICE '   Tubes with "ea":          %', v_tubes_with_ea;
    RAISE NOTICE '   Fabrics with "ea":       %', v_fabrics_with_ea;
    RAISE NOTICE '   Profiles/Rails with "ea": %', v_profiles_with_ea;
    RAISE NOTICE '   Products with NULL UOM:   %', v_null_uom;
    RAISE NOTICE '   ─────────────────────────────────────';
    RAISE NOTICE '   Total issues to fix:      %', 
        v_tubes_with_ea + v_fabrics_with_ea + v_profiles_with_ea + v_null_uom;
    RAISE NOTICE '============================================================================';
    RAISE NOTICE '';

END $$;








