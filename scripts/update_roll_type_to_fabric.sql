-- ====================================================
-- Update roll_type to 'fabric' for all rolls
-- Date: 2026-02-03
-- ====================================================

BEGIN;

UPDATE public."CatalogItems"
SET roll_type = 'fabric'
WHERE is_roll = true
  AND (roll_type IS NULL OR roll_type != 'fabric');

-- Verify
SELECT
  count(*) as total_rolls,
  count(*) filter (where roll_type = 'fabric') as fabric_rolls,
  count(*) filter (where roll_type IS NULL) as null_roll_type
FROM public."CatalogItems"
WHERE is_roll = true;

COMMIT;
