-- Add fabric_group column to FabricRules for filtering by product-line-agnostic groups.
-- Wave Drapery and Ripple Fold share the same fabric rules (wave group),
-- while Pinch Pleat has its own fabric rules (pinch_pleat group).

ALTER TABLE "public"."FabricRules"
  ADD COLUMN IF NOT EXISTS "fabric_group" text;

-- Rename the old ripple_fold FabricRule to wave_2.0 (it's fullness 2.0, same wave concept)
UPDATE "public"."FabricRules"
SET style_code   = 'wave_2.0',
    display_name = 'Wave 2.0'
WHERE style_code = 'ripple_fold'
  AND formula_code = 'DRAPERY_PANELS';

-- Set fabric_group for all wave-type rules (shared by Wave Drapery and Ripple Fold)
UPDATE "public"."FabricRules"
SET fabric_group = 'wave'
WHERE style_code IN ('wave_2.0', 'wave_2.3', 'wave_2.8')
  AND formula_code = 'DRAPERY_PANELS';

-- Set fabric_group for pinch pleat rules
UPDATE "public"."FabricRules"
SET fabric_group = 'pinch_pleat'
WHERE style_code = 'pinch_pleat'
  AND formula_code = 'DRAPERY_PANELS';

-- Clear product_line from wave rules since they're shared across product lines
UPDATE "public"."FabricRules"
SET product_line = NULL
WHERE fabric_group = 'wave'
  AND formula_code = 'DRAPERY_PANELS';

-- Rename BOMTemplates product_line from ripple_fold to wave_drapery... NO.
-- User will create wave_drapery BOMTemplates separately. Keep ripple_fold as is.

NOTIFY pgrst, 'reload schema';
