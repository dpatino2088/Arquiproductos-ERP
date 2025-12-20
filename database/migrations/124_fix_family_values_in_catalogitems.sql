-- ====================================================
-- Migration 124: Fix family values in CatalogItems to match ProductTypes.name
-- ====================================================
-- This script corrects family values in CatalogItems to match exactly
-- with ProductTypes.name (e.g., "Roller Shades" -> "Roller Shade")
-- ====================================================

DO $$
DECLARE
    v_org_id UUID;
    v_updated_count INTEGER;
    v_family_mapping RECORD;
BEGIN
    RAISE NOTICE '🚀 Starting Migration 124: Fix family values in CatalogItems';
    RAISE NOTICE '====================================================';
    
    -- Get the first organization (or use a specific one)
    SELECT id INTO v_org_id
    FROM "Organizations"
    WHERE deleted = false
    LIMIT 1;
    
    IF v_org_id IS NULL THEN
        RAISE NOTICE '⚠️  No organization found. Skipping migration.';
        RETURN;
    END IF;
    
    RAISE NOTICE '📋 Organization ID: %', v_org_id;
    RAISE NOTICE '';
    
    -- Show current family values before update
    RAISE NOTICE 'STEP 1: Current family values in CatalogItems:';
    FOR v_family_mapping IN
        SELECT 
            family,
            COUNT(*) as count
        FROM "CatalogItems"
        WHERE organization_id = v_org_id
          AND deleted = false
          AND family IS NOT NULL
        GROUP BY family
        ORDER BY count DESC
    LOOP
        RAISE NOTICE '   - "%": % items', v_family_mapping.family, v_family_mapping.count;
    END LOOP;
    RAISE NOTICE '';
    
    -- Show ProductTypes names for reference
    RAISE NOTICE 'STEP 2: ProductTypes.name values (target values):';
    FOR v_family_mapping IN
        SELECT name
        FROM "ProductTypes"
        WHERE organization_id = v_org_id
          AND deleted = false
        ORDER BY name
    LOOP
        RAISE NOTICE '   - "%"', v_family_mapping.name;
    END LOOP;
    RAISE NOTICE '';
    
    -- Fix 1: "Roller Shades" -> "Roller Shade"
    RAISE NOTICE 'STEP 3: Fixing "Roller Shades" -> "Roller Shade"...';
    UPDATE "CatalogItems"
    SET family = 'Roller Shade',
        updated_at = NOW()
    WHERE organization_id = v_org_id
      AND deleted = false
      AND family IN ('Roller Shades', 'RollerShade', 'roller-shade', 'Roller shades');
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Updated % rows', v_updated_count;
    
    -- Fix 2: "Dual Shades" -> "Dual Shade"
    RAISE NOTICE 'STEP 4: Fixing "Dual Shades" -> "Dual Shade"...';
    UPDATE "CatalogItems"
    SET family = 'Dual Shade',
        updated_at = NOW()
    WHERE organization_id = v_org_id
      AND deleted = false
      AND family IN ('Dual Shades', 'DualShade', 'dual-shade', 'Dual shades');
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Updated % rows', v_updated_count;
    
    -- Fix 3: "Triple Shades" -> "Triple Shade"
    RAISE NOTICE 'STEP 5: Fixing "Triple Shades" -> "Triple Shade"...';
    UPDATE "CatalogItems"
    SET family = 'Triple Shade',
        updated_at = NOW()
    WHERE organization_id = v_org_id
      AND deleted = false
      AND family IN ('Triple Shades', 'TripleShade', 'triple-shade', 'Triple shades');
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Updated % rows', v_updated_count;
    
    -- Fix 4: Ensure all family values match ProductTypes.name exactly
    RAISE NOTICE 'STEP 6: Syncing all family values with ProductTypes.name...';
    
    -- Update family to match ProductTypes.name where there's a close match
    UPDATE "CatalogItems" ci
    SET family = pt.name,
        updated_at = NOW()
    FROM "ProductTypes" pt
    WHERE ci.organization_id = v_org_id
      AND ci.deleted = false
      AND pt.organization_id = v_org_id
      AND pt.deleted = false
      AND ci.family IS NOT NULL
      AND (
          -- Exact case-insensitive match
          LOWER(TRIM(ci.family)) = LOWER(TRIM(pt.name))
          OR
          -- Handle common variations
          (LOWER(TRIM(ci.family)) = LOWER(TRIM(pt.name)) || 's')
          OR
          (LOWER(TRIM(ci.family)) = REPLACE(LOWER(TRIM(pt.name)), ' ', ''))
          OR
          (LOWER(TRIM(ci.family)) = REPLACE(LOWER(TRIM(pt.name)), ' ', '-'))
      )
      AND ci.family != pt.name; -- Only update if different
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RAISE NOTICE '   ✅ Updated % rows to match ProductTypes.name', v_updated_count;
    RAISE NOTICE '';
    
    -- Show final family values after update
    RAISE NOTICE 'STEP 7: Final family values in CatalogItems:';
    FOR v_family_mapping IN
        SELECT 
            family,
            COUNT(*) as count
        FROM "CatalogItems"
        WHERE organization_id = v_org_id
          AND deleted = false
          AND family IS NOT NULL
        GROUP BY family
        ORDER BY count DESC
    LOOP
        RAISE NOTICE '   - "%": % items', v_family_mapping.family, v_family_mapping.count;
    END LOOP;
    RAISE NOTICE '';
    
    -- Verify that all family values now match ProductTypes.name
    RAISE NOTICE 'STEP 8: Verifying family values match ProductTypes.name...';
    SELECT COUNT(*) INTO v_updated_count
    FROM "CatalogItems" ci
    WHERE ci.organization_id = v_org_id
      AND ci.deleted = false
      AND ci.family IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM "ProductTypes" pt
          WHERE pt.organization_id = v_org_id
            AND pt.deleted = false
            AND pt.name = ci.family
      );
    
    IF v_updated_count > 0 THEN
        RAISE NOTICE '   ⚠️  Warning: % items have family values that do not match any ProductTypes.name', v_updated_count;
        RAISE NOTICE '   These items will need manual review:';
        
        FOR v_family_mapping IN
            SELECT DISTINCT family
            FROM "CatalogItems"
            WHERE organization_id = v_org_id
              AND deleted = false
              AND family IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1
                  FROM "ProductTypes" pt
                  WHERE pt.organization_id = v_org_id
                    AND pt.deleted = false
                    AND pt.name = "CatalogItems".family
              )
        LOOP
            RAISE NOTICE '      - "%"', v_family_mapping.family;
        END LOOP;
    ELSE
        RAISE NOTICE '   ✅ All family values match ProductTypes.name!';
    END IF;
    RAISE NOTICE '';
    
    RAISE NOTICE '✅ Migration 124 completed successfully!';
    RAISE NOTICE '====================================================';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Error in Migration 124: %', SQLERRM;
        RAISE;
END $$;


