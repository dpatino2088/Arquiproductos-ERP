-- ====================================================
-- Migration 368: Migrate ALL Legacy Roles to Canonical Roles
-- ====================================================
-- Migrates ALL remaining legacy component_role values to canonical roles with sub_roles
-- 
-- This completes the migration started in 365 by handling all legacy roles:
--   motor -> drive_motorized
--   motor_adapter -> hardware (sub_role: adapter)
--   bottom_rail_end_cap -> end_cap (sub_role: bottom_rail_end_cap)
--   bottom_rail_profile -> bottom_rail (sub_role: profile)
--   side_channel_profile -> side_channel (sub_role: profile)
-- 
-- After migration, updates constraint to only allow canonical roles
-- This migration is idempotent (safe to rerun)
-- ====================================================

DO $$
DECLARE
    v_rows_updated integer;
    v_motor_count integer := 0;
    v_motor_adapter_count integer := 0;
    v_bottom_rail_end_cap_count integer := 0;
    v_bottom_rail_profile_count integer := 0;
    v_side_channel_profile_count integer := 0;
    v_legacy_remaining integer := 0;
    v_all_legacy_roles text[] := ARRAY[
        'motor',
        'motor_adapter',
        'bottom_rail_end_cap',
        'bottom_rail_profile',
        'side_channel_profile'
    ];
BEGIN
    RAISE NOTICE '🔄 Starting complete legacy role migration...';
    RAISE NOTICE '';

    -- ====================================================
    -- STEP 1: Migrate motor -> drive_motorized
    -- ====================================================
    UPDATE public."BOMComponents"
    SET 
        component_role = 'drive_motorized',
        component_sub_role = NULL,
        updated_at = now()
    WHERE component_role = 'motor'
    AND deleted = false;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    v_motor_count := v_rows_updated;
    
    IF v_rows_updated > 0 THEN
        RAISE NOTICE '  ✅ Migrated % rows: motor → role=drive_motorized', v_rows_updated;
    ELSE
        RAISE NOTICE '  ℹ️  No motor roles found to migrate (already migrated or none exist)';
    END IF;

    -- ====================================================
    -- STEP 2: Migrate motor_adapter -> hardware (sub_role: adapter)
    -- ====================================================
    UPDATE public."BOMComponents"
    SET 
        component_role = 'hardware',
        component_sub_role = 'adapter',
        updated_at = now()
    WHERE component_role = 'motor_adapter'
    AND deleted = false
    AND (component_sub_role IS NULL OR component_sub_role != 'adapter');

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    v_motor_adapter_count := v_rows_updated;
    
    IF v_rows_updated > 0 THEN
        RAISE NOTICE '  ✅ Migrated % rows: motor_adapter → role=hardware, sub_role=adapter', v_rows_updated;
    ELSE
        RAISE NOTICE '  ℹ️  No motor_adapter roles found to migrate (already migrated or none exist)';
    END IF;

    -- ====================================================
    -- STEP 3: Migrate bottom_rail_end_cap -> end_cap (sub_role: bottom_rail_end_cap)
    -- ====================================================
    UPDATE public."BOMComponents"
    SET 
        component_role = 'end_cap',
        component_sub_role = 'bottom_rail_end_cap',
        updated_at = now()
    WHERE component_role = 'bottom_rail_end_cap'
    AND deleted = false
    AND (component_sub_role IS NULL OR component_sub_role != 'bottom_rail_end_cap');

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    v_bottom_rail_end_cap_count := v_rows_updated;
    
    IF v_rows_updated > 0 THEN
        RAISE NOTICE '  ✅ Migrated % rows: bottom_rail_end_cap → role=end_cap, sub_role=bottom_rail_end_cap', v_rows_updated;
    ELSE
        RAISE NOTICE '  ℹ️  No bottom_rail_end_cap roles found to migrate (already migrated or none exist)';
    END IF;

    -- ====================================================
    -- STEP 4: Migrate bottom_rail_profile -> bottom_rail (sub_role: profile)
    -- ====================================================
    UPDATE public."BOMComponents"
    SET 
        component_role = 'bottom_rail',
        component_sub_role = 'profile',
        updated_at = now()
    WHERE component_role = 'bottom_rail_profile'
    AND deleted = false
    AND (component_sub_role IS NULL OR component_sub_role != 'profile');

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    v_bottom_rail_profile_count := v_rows_updated;
    
    IF v_rows_updated > 0 THEN
        RAISE NOTICE '  ✅ Migrated % rows: bottom_rail_profile → role=bottom_rail, sub_role=profile', v_rows_updated;
    ELSE
        RAISE NOTICE '  ℹ️  No bottom_rail_profile roles found to migrate (already migrated or none exist)';
    END IF;

    -- ====================================================
    -- STEP 5: Migrate side_channel_profile -> side_channel (sub_role: profile)
    -- ====================================================
    UPDATE public."BOMComponents"
    SET 
        component_role = 'side_channel',
        component_sub_role = 'profile',
        updated_at = now()
    WHERE component_role = 'side_channel_profile'
    AND deleted = false
    AND (component_sub_role IS NULL OR component_sub_role != 'profile');

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    v_side_channel_profile_count := v_rows_updated;
    
    IF v_rows_updated > 0 THEN
        RAISE NOTICE '  ✅ Migrated % rows: side_channel_profile → role=side_channel, sub_role=profile', v_rows_updated;
    ELSE
        RAISE NOTICE '  ℹ️  No side_channel_profile roles found to migrate (already migrated or none exist)';
    END IF;

    RAISE NOTICE '';

    -- ====================================================
    -- STEP 6: Verification - Count remaining legacy roles
    -- ====================================================
    SELECT COUNT(*) INTO v_legacy_remaining
    FROM public."BOMComponents"
    WHERE component_role = ANY(v_all_legacy_roles)
    AND deleted = false;

    IF v_legacy_remaining > 0 THEN
        RAISE WARNING '  ⚠️  Still % legacy roles remaining in BOMComponents (should be 0)', v_legacy_remaining;
    ELSE
        RAISE NOTICE '  ✅ Verification passed: 0 legacy roles remaining';
    END IF;

    RAISE NOTICE '';

    -- ====================================================
    -- STEP 7: Update constraint to ONLY canonical roles
    -- ====================================================
    -- Now that all legacy roles are migrated, update constraint to only allow canonical roles
    ALTER TABLE public."BOMComponents"
        DROP CONSTRAINT IF EXISTS check_bomcomponents_role_valid;

    BEGIN
        ALTER TABLE public."BOMComponents"
            ADD CONSTRAINT check_bomcomponents_role_valid
            CHECK (
                component_role IS NULL 
                OR component_role IN (
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
                    'operating_system'
                )
            );

        RAISE NOTICE '  ✅ Created BOMComponents check_bomcomponents_role_valid constraint with canonical roles ONLY';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE WARNING '  ⚠️  Could not create constraint: %', SQLERRM;
            RAISE NOTICE '  ℹ️  Some legacy roles may still exist. Run verification queries.';
    END;

    RAISE NOTICE '';

    RAISE NOTICE '📊 Migration Summary:';
    RAISE NOTICE '   - motor → drive_motorized: % rows', v_motor_count;
    RAISE NOTICE '   - motor_adapter → hardware (sub_role=adapter): % rows', v_motor_adapter_count;
    RAISE NOTICE '   - bottom_rail_end_cap → end_cap (sub_role=bottom_rail_end_cap): % rows', v_bottom_rail_end_cap_count;
    RAISE NOTICE '   - bottom_rail_profile → bottom_rail (sub_role=profile): % rows', v_bottom_rail_profile_count;
    RAISE NOTICE '   - side_channel_profile → side_channel (sub_role=profile): % rows', v_side_channel_profile_count;
    RAISE NOTICE '   - Legacy roles remaining: %', v_legacy_remaining;
    RAISE NOTICE '   - Constraint updated to canonical roles ONLY';
    RAISE NOTICE '';

END $$;

-- ====================================================
-- Verification Queries (run separately to verify)
-- ====================================================
-- Query 1: Check for any remaining legacy roles
SELECT 
    component_role,
    COUNT(*) as count
FROM public."BOMComponents"
WHERE component_role IN (
    'motor',
    'motor_adapter',
    'bottom_rail_end_cap',
    'bottom_rail_profile',
    'side_channel_profile',
    'end_plug',
    'operating_system_drive'
)
AND deleted = false
GROUP BY component_role
ORDER BY component_role;
-- Should return 0 rows

-- Query 2: Check migrated roles with sub_roles
SELECT 
    component_role,
    component_sub_role,
    COUNT(*) as count
FROM public."BOMComponents"
WHERE component_role IN (
    'drive_motorized',
    'hardware',
    'end_cap',
    'bottom_rail',
    'side_channel',
    'operating_system'
)
AND deleted = false
GROUP BY component_role, component_sub_role
ORDER BY component_role, component_sub_role;

-- Query 3: Check ALL roles currently in BOMComponents (final verification)
SELECT 
    component_role,
    COUNT(*) as count
FROM public."BOMComponents"
WHERE component_role IS NOT NULL
AND deleted = false
GROUP BY component_role
ORDER BY component_role;
-- All roles should be canonical

