-- ====================================================
-- Migration: Add idle_end and pin roles to BOMComponents constraint
-- ====================================================
-- Adds 'idle_end' and 'pin' roles to the check_bomcomponents_role_valid constraint
-- These roles are used for idle end components (RC3085, RC3005) and pins (RC2003)
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '🔧 Adding idle_end and pin roles to check_bomcomponents_role_valid constraint...';
  RAISE NOTICE '';

  -- STEP 1: Drop existing constraint
  ALTER TABLE public."BOMComponents"
    DROP CONSTRAINT IF EXISTS check_bomcomponents_role_valid;

  RAISE NOTICE '  ✅ Dropped existing check_bomcomponents_role_valid constraint';

  -- STEP 2: Create new constraint with ALL roles including idle_end and pin
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
        'cassette_end_cap',          -- Cassette End Cap SKU
        
        -- Block-based Side Channel roles
        'side_channel_profile',      -- Side Channel Profile SKU
        
        -- Idle End roles (for roller shade idle side)
        'idle_end',                  -- Idle End (RC3085 or RC3005)
        'pin'                        -- Pin between idle end and bracket (RC2003)
      )
    );

  RAISE NOTICE '  ✅ Recreated check_bomcomponents_role_valid constraint with idle_end and pin';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Constraint now includes:';
  RAISE NOTICE '   - idle_end: For RC3085 (Heavy Duty) or RC3005 (standard idle end)';
  RAISE NOTICE '   - pin: For RC2003 (pin between idle end and bracket)';
  RAISE NOTICE '';
  RAISE NOTICE 'Note: RC3085 replaces RC3005 + RC2003, so templates should only include one or the other';

END $$;




