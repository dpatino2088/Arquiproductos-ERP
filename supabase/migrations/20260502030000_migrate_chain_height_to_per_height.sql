-- Fase D: Migrate CHAIN_HEIGHT_FACTOR to per_height
-- The qty_formula_code column does not exist in the current schema.
-- The deployed generate_bom_for_manufacturing_order function already
-- supports per_height natively, so no data migration is needed.
-- This migration is a no-op placeholder for documentation purposes.

-- If qty_formula_code is ever added back, run:
-- UPDATE "BOMComponents"
-- SET qty_type = 'per_height',
--     qty_value = COALESCE((qty_formula_params->>'height_factor')::numeric, 0.75)
--               * COALESCE((qty_formula_params->>'mult')::numeric, 2),
--     qty_formula_code = NULL
-- WHERE qty_formula_code = 'CHAIN_HEIGHT_FACTOR' AND deleted = false;

SELECT 1;
