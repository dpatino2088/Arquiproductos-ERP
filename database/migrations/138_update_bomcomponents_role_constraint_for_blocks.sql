-- ====================================================
-- Migration: Update BOMComponents role constraint for block-based system
-- ====================================================
-- This updates the check_bomcomponents_role_valid constraint to include
-- all the new component roles needed for the block-based BOM system
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '🔧 Updating BOMComponents role constraint for block-based system...';
  RAISE NOTICE '';

  -- STEP 1: Drop existing constraint
  ALTER TABLE public."BOMComponents"
    DROP CONSTRAINT IF EXISTS check_bomcomponents_role_valid;

  RAISE NOTICE '  ✅ Dropped existing check_bomcomponents_role_valid constraint';

  -- STEP 2: Create new constraint with all block-based roles
  ALTER TABLE public."BOMComponents"
    ADD CONSTRAINT check_bomcomponents_role_valid 
    CHECK (
      component_role IS NULL 
      OR component_role IN (
        -- Legacy roles
        'fabric',                    -- Fabric/tela
        'tube',                      -- Tube/tubo
        'bracket',                   -- Bracket/soporte
        'cassette',                  -- Cassette
        'bottom_bar',                -- Bottom bar/barra inferior
        'operating_system_drive',    -- Operating system drive (motor/manual)
        
        -- Block-based Drive roles (Motor)
        'motor',                     -- Motor SKU
        'motor_adapter',             -- Motor Adapter SKU
        'adapter_end_plug',          -- Adapter End Plug SKU
        'end_plug',                  -- End Plug SKU
        
        -- Block-based Drive roles (Manual)
        'clutch',                    -- Clutch SKU
        'clutch_adapter',            -- Clutch Adapter SKU
        
        -- Block-based Brackets roles
        'bracket_end_cap',           -- Bracket End Cap SKU
        'screw_end_cap',             -- Screw End Cap SKU
        
        -- Block-based Bottom Rail roles
        'bottom_rail_profile',       -- Bottom Rail Profile SKU
        'bottom_rail_end_cap',       -- Bottom Rail End Cap SKU
        
        -- Block-based Cassette roles
        'cassette_profile',          -- Cassette Profile SKU
        'cassette_end_cap',           -- Cassette End Cap SKU
        
        -- Block-based Side Channel roles
        'side_channel_profile'        -- Side Channel Profile SKU
      )
    );

  RAISE NOTICE '  ✅ Added updated check_bomcomponents_role_valid constraint';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Constraint now includes:';
  RAISE NOTICE '   - Legacy roles: fabric, tube, bracket, cassette, bottom_bar, operating_system_drive';
  RAISE NOTICE '   - Drive block roles: motor, motor_adapter, adapter_end_plug, end_plug, clutch, clutch_adapter';
  RAISE NOTICE '   - Brackets block roles: bracket_end_cap, screw_end_cap';
  RAISE NOTICE '   - Bottom Rail block roles: bottom_rail_profile, bottom_rail_end_cap';
  RAISE NOTICE '   - Cassette block roles: cassette_profile, cassette_end_cap';
  RAISE NOTICE '   - Side Channel block roles: side_channel_profile';

END $$;

