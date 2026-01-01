-- ====================================================
-- Migration 189: Update component_role constraint in QuoteLineComponents
-- ====================================================
-- This migration updates the check_component_role_valid constraint
-- to include all the new component_role values used in BOMComponents:
-- - bottom_rail_profile
-- - bottom_rail_end_cap
-- - side_channel_profile
-- - side_channel_cover
-- - motor_crown
-- - motor_drive
-- - operating_system_drive (already exists)
-- - cassette_profile
-- - cassette_end_cap
-- - etc.
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '🔧 Updating component_role constraint in QuoteLineComponents...';
    
    -- Drop existing constraint
    ALTER TABLE public."QuoteLineComponents"
        DROP CONSTRAINT IF EXISTS check_component_role_valid;
    
    RAISE NOTICE '  ✅ Dropped existing constraint';
    
    -- Add updated constraint with all valid component roles
    ALTER TABLE public."QuoteLineComponents"
        ADD CONSTRAINT check_component_role_valid 
        CHECK (
            component_role IS NULL 
            OR component_role IN (
                -- Original values
                'fabric',                    -- Fabric/tela
                'tube',                      -- Tube/tubo
                'bracket',                   -- Bracket/soporte
                'cassette',                  -- Cassette (legacy)
                'bottom_bar',                -- Bottom bar/barra inferior (legacy)
                'operating_system_drive',    -- Operating system drive (motor/manual)
                
                -- Bottom Rail components
                'bottom_rail_profile',       -- Bottom rail profile
                'bottom_rail_end_cap',       -- Bottom rail end cap
                'bottom_channel',             -- Bottom channel (alias)
                
                -- Side Channel components
                'side_channel_profile',      -- Side channel profile
                'side_channel_cover',        -- Side channel cover
                'side_channel',              -- Side channel (generic)
                
                -- Motor/Drive components
                'motor_crown',               -- Motor crown
                'motor_drive',               -- Motor drive
                
                -- Cassette components
                'cassette_profile',          -- Cassette profile
                'cassette_end_cap',          -- Cassette end cap
                
                -- Accessories
                'accessory',                 -- Generic accessory
                'insert',                    -- Insert/gasket
                'gasket'                     -- Gasket
            )
        );
    
    RAISE NOTICE '  ✅ Added updated constraint with all valid component_role values';
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 189 completed successfully!';
    RAISE NOTICE '📝 QuoteLineComponents now supports all BOM component_role values.';
    
END $$;








