BEGIN;

-- =============================================================================
-- Bottom Hem: single-path architecture
--   1. FabricRules.bottom_hem_options defines available options for configurator
--   2. User selects one → stored in config_snapshot.bottom_hem_cm
--   3. compute_fabric uses ONLY the user-selected value (p_bottom_hem_cm)
--   4. FabricRules.bottom_hem_cm remains as default pre-selection in UI only
-- =============================================================================

-- Add bottom_hem_options column
ALTER TABLE public."FabricRules"
  ADD COLUMN IF NOT EXISTS bottom_hem_options numeric[] DEFAULT '{0,5,10,15}';

UPDATE public."FabricRules"
SET bottom_hem_options = ARRAY[0, 5, 10, 15]::numeric[]
WHERE formula_code = 'DRAPERY_PANELS'
  AND (bottom_hem_options IS NULL OR bottom_hem_options = '{}');

-- Drop old function signatures to allow param rename
DROP FUNCTION IF EXISTS public.compute_fabric_pricing_from_rule(uuid,uuid,text,numeric,numeric,numeric,numeric,jsonb,boolean,boolean,boolean,numeric);
DROP FUNCTION IF EXISTS public.compute_fabric_pricing_from_rule(uuid,uuid,text,numeric,numeric,numeric,numeric,jsonb,boolean,boolean,boolean);

-- Recreate with p_bottom_hem_cm: single source, no fallback to rule
-- (full function body in separate migration file for readability)

COMMIT;
