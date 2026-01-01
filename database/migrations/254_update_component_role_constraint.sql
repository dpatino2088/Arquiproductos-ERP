-- ====================================================
-- Migration 254: Update Component Role Constraint
-- ====================================================
-- Updates check_component_role_valid to include all roles used by
-- generate_configured_bom_for_quote_line()
-- ====================================================

DO $$
BEGIN
    -- Drop existing constraint
    ALTER TABLE "QuoteLineComponents"
    DROP CONSTRAINT IF EXISTS check_component_role_valid;
    
    -- Add updated constraint with all valid roles
    ALTER TABLE "QuoteLineComponents"
    ADD CONSTRAINT check_component_role_valid 
    CHECK (
        component_role IS NULL 
        OR component_role IN (
            -- Core roles
            'fabric',                    -- Fabric/tela
            'tube',                      -- Tube/tubo
            'bracket',                   -- Bracket/soporte
            'cassette',                  -- Cassette
            'bottom_bar',                -- Bottom bar/barra inferior (legacy)
            'operating_system_drive',    -- Operating system drive (motor/manual)
            -- Bottom rail roles
            'bottom_rail_profile',       -- Bottom rail profile (linear)
            'bottom_rail_end_cap',      -- Bottom rail end cap
            -- Side channel roles
            'side_channel_profile',     -- Side channel profile (linear)
            'side_channel_end_cap',     -- Side channel end cap
            -- Motor roles
            'motor',                     -- Motor
            'motor_adapter'             -- Motor adapter
        )
    );
    
    RAISE NOTICE '✅ Updated check_component_role_valid constraint to include all BOM roles';
END $$;


