BEGIN;

-- Add bottom_hem_options column: simple numeric array of available hem sizes (cm)
ALTER TABLE public."FabricRules"
  ADD COLUMN IF NOT EXISTS bottom_hem_options numeric[] DEFAULT '{0,5,10,15}';

-- Populate existing drapery rules: include 0 (serged) plus current bottom_hem_cm
UPDATE public."FabricRules"
SET bottom_hem_options = ARRAY[0, 5, 10, 15]::numeric[]
WHERE formula_code = 'DRAPERY_PANELS'
  AND (bottom_hem_options IS NULL OR bottom_hem_options = '{}');

COMMIT;
