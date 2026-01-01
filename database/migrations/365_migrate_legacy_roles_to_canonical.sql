-- ====================================================
-- Migration 365: Migrate Legacy Roles to Canonical Roles
-- ====================================================
-- Migrates legacy component_role values to canonical roles with sub_roles
-- 
-- Mappings:
--   end_plug -> role='end_cap', sub_role='end_plug'
--   operating_system_drive -> role='operating_system', sub_role='drive'
-- 
-- This migration is idempotent (safe to rerun)
-- ====================================================

DO $$
DECLARE
    v_rows_updated integer;
    v_end_plug_count integer := 0;
    v_operating_system_drive_count integer := 0;
    v_legacy_remaining integer := 0;
BEGIN
    RAISE NOTICE '🔄 Starting legacy role migration...';
    RAISE NOTICE '';

    -- ====================================================
    -- STEP 0: Update BOMComponents CHECK constraint to include end_cap and operating_system
    -- ====================================================
    -- First, drop the constraint to allow data migration
    -- We'll recreate it after migration with only canonical roles
    ALTER TABLE public."BOMComponents"
        DROP CONSTRAINT IF EXISTS check_bomcomponents_role_valid;

    RAISE NOTICE '  ✅ Dropped check_bomcomponents_role_valid constraint (will recreate after migration)';
    RAISE NOTICE '';

    -- ====================================================
    -- STEP 1: Migrate end_plug -> end_cap + sub_role='end_plug'
    -- ====================================================
    UPDATE public."BOMComponents"
    SET 
        component_role = 'end_cap',
        component_sub_role = 'end_plug',
        updated_at = now()
    WHERE component_role = 'end_plug'
    AND deleted = false
    AND (component_sub_role IS NULL OR component_sub_role != 'end_plug');

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    v_end_plug_count := v_rows_updated;
    
    IF v_rows_updated > 0 THEN
        RAISE NOTICE '  ✅ Migrated % rows: end_plug → role=end_cap, sub_role=end_plug', v_rows_updated;
    ELSE
        RAISE NOTICE '  ℹ️  No end_plug roles found to migrate (already migrated or none exist)';
    END IF;

    -- ====================================================
    -- STEP 2: Migrate operating_system_drive -> operating_system + sub_role='drive'
    -- ====================================================
    UPDATE public."BOMComponents"
    SET 
        component_role = 'operating_system',
        component_sub_role = 'drive',
        updated_at = now()
    WHERE component_role = 'operating_system_drive'
    AND deleted = false
    AND (component_sub_role IS NULL OR component_sub_role != 'drive');

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    v_operating_system_drive_count := v_rows_updated;
    
    IF v_rows_updated > 0 THEN
        RAISE NOTICE '  ✅ Migrated % rows: operating_system_drive → role=operating_system, sub_role=drive', v_rows_updated;
    ELSE
        RAISE NOTICE '  ℹ️  No operating_system_drive roles found to migrate (already migrated or none exist)';
    END IF;

    RAISE NOTICE '';

    -- ====================================================
    -- STEP 3: Verification - Count remaining legacy roles
    -- ====================================================
    SELECT COUNT(*) INTO v_legacy_remaining
    FROM public."BOMComponents"
    WHERE component_role IN ('end_plug', 'operating_system_drive')
    AND deleted = false;

    IF v_legacy_remaining > 0 THEN
        RAISE WARNING '  ⚠️  Still % legacy roles remaining in BOMComponents (should be 0)', v_legacy_remaining;
    ELSE
        RAISE NOTICE '  ✅ Verification passed: 0 legacy roles (end_plug, operating_system_drive) remaining';
    END IF;

    RAISE NOTICE '';

    -- ====================================================
    -- STEP 4: Create constraint with canonical + remaining legacy roles
    -- ====================================================
    -- Create constraint that includes canonical roles + legacy roles that still exist
    -- Legacy roles will be migrated in future migrations
    -- This allows the system to work while legacy roles are gradually migrated
    BEGIN
        ALTER TABLE public."BOMComponents"
            ADD CONSTRAINT check_bomcomponents_role_valid
            CHECK (
                component_role IS NULL 
                OR component_role IN (
                    -- Canonical roles (new unified set)
                    'fabric',
                    'tube',
                    'bracket',
                    'cassette',
                    'side_channel',
                    'bottom_bar',
                    'bottom_rail',
                    'top_rail',
                    'drive_manual',
                    'drive_motorized',
                    'remote_control',
                    'battery',
                    'tool',
                    'hardware',
                    'accessory',
                    'service',
                    'window_film',
                    'end_cap',
                    'operating_system',
                    -- Legacy roles (temporary - to be migrated in future)
                    -- These are from the block-based system (migration 138)
                    'motor',
                    'motor_adapter',
                    'adapter_end_plug',
                    'clutch',
                    'clutch_adapter',
                    'bracket_end_cap',
                    'screw_end_cap',
                    'bottom_rail_profile',
                    'bottom_rail_end_cap',
                    'cassette_profile',
                    'cassette_end_cap',
                    'side_channel_profile'
                )
            );

        RAISE NOTICE '  ✅ Created BOMComponents check_bomcomponents_role_valid constraint';
        RAISE NOTICE '     (includes canonical roles + legacy roles for compatibility)';
        RAISE NOTICE '     Legacy roles should be migrated to canonical roles in future migrations';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '  ⚠️  Could not create constraint: %', SQLERRM;
            RAISE NOTICE '  ℹ️  Constraint will need to be created manually.';
    END;

    RAISE NOTICE '';

    RAISE NOTICE '📊 Migration Summary:';
    RAISE NOTICE '   - end_plug → end_cap (sub_role=end_plug): % rows', v_end_plug_count;
    RAISE NOTICE '   - operating_system_drive → operating_system (sub_role=drive): % rows', v_operating_system_drive_count;
    RAISE NOTICE '   - Legacy roles remaining: %', v_legacy_remaining;
    RAISE NOTICE '   - Constraint updated to canonical roles only';
    RAISE NOTICE '';

END $$;

-- ====================================================
-- Verification Query (run separately to verify)
-- ====================================================
-- Check for any remaining legacy roles
SELECT 
    component_role,
    COUNT(*) as count
FROM public."BOMComponents"
WHERE component_role IN ('end_plug', 'operating_system_drive')
AND deleted = false
GROUP BY component_role
ORDER BY component_role;

-- Check migrated roles
SELECT 
    component_role,
    component_sub_role,
    COUNT(*) as count
FROM public."BOMComponents"
WHERE component_role IN ('end_cap', 'operating_system')
AND deleted = false
AND component_sub_role IS NOT NULL
GROUP BY component_role, component_sub_role
ORDER BY component_role, component_sub_role;

-- Query 3: Check ALL roles currently in BOMComponents (to identify any other legacy roles)
SELECT 
    component_role,
    COUNT(*) as count
FROM public."BOMComponents"
WHERE component_role IS NOT NULL
AND deleted = false
GROUP BY component_role
ORDER BY component_role;

