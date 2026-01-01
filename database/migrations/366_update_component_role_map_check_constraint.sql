-- ====================================================
-- Migration 366: Update ComponentRoleMap CHECK constraint
-- ====================================================
-- Updates the CHECK constraint to include 'end_cap' and 'operating_system'
-- This is needed for migration 365 to work correctly
-- ====================================================

DO $$
BEGIN
    -- Drop existing constraint if it exists
    ALTER TABLE public."ComponentRoleMap"
        DROP CONSTRAINT IF EXISTS check_role_canonical;

    -- Recreate constraint with all canonical roles including end_cap and operating_system
    ALTER TABLE public."ComponentRoleMap"
        ADD CONSTRAINT check_role_canonical
        CHECK (role IN (
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
        ));

    RAISE NOTICE '✅ Updated ComponentRoleMap check_role_canonical constraint to include end_cap and operating_system';
END $$;

