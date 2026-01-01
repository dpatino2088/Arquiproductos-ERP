-- ====================================================
-- Migration 279: Update Component Role Constraint with New Roles
-- ====================================================
-- Adds new roles: chain, chain_stop, motor_crown, motor_accessory, bracket_cover
-- ====================================================

BEGIN;

ALTER TABLE public."QuoteLineComponents"
  DROP CONSTRAINT IF EXISTS check_component_role_valid;

ALTER TABLE public."QuoteLineComponents"
  ADD CONSTRAINT check_component_role_valid 
  CHECK (
    component_role IS NULL 
    OR component_role IN (
      -- Core components
      'fabric', 'tube', 'bracket',
      -- Bottom rail
      'bottom_rail_profile', 'bottom_rail_end_cap',
      -- Side channel
      'side_channel_profile', 'side_channel_end_cap',
      -- Manual drive mechanism
      'operating_system_drive',  -- RC3001, RC3002, RC3003 (manual)
      'chain',                   -- V15DP, RB.., V15M, RB..M (manual chains)
      'chain_stop',              -- Topes de cadena (manual, 2 per curtain)
      -- Motorized components
      'motor',                   -- CM-09, CM-10, etc.
      'motor_adapter',           -- RC3162
      'motor_crown',             -- RC3164 (always with motor)
      'motor_accessory',         -- RC3045 (fixed accessory of motor)
      -- Bracket accessories
      'bracket_cover'            -- RC3007 + RC3008 (decorative covers for RC3006)
    )
  );

COMMENT ON CONSTRAINT check_component_role_valid ON public."QuoteLineComponents" IS 
  'Validates component_role values. Includes manual (operating_system_drive, chain, chain_stop) and motorized (motor, motor_adapter, motor_crown, motor_accessory) roles, plus bracket_cover for both types.';

COMMIT;


