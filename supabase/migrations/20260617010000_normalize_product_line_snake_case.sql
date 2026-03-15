-- Normalize product_line to snake_case across all tables
-- Previously BOMTemplates had 'Ripple Fold' / 'Pinch Pleat' (title case)
-- while FabricRules used 'wave' / 'pinch_pleat' (snake_case).
-- This migration aligns everything to snake_case.

-- 1. Normalize BOMTemplates product_line values
UPDATE "public"."BOMTemplates"
SET product_line = 'ripple_fold'
WHERE product_line = 'Ripple Fold';

UPDATE "public"."BOMTemplates"
SET product_line = 'pinch_pleat'
WHERE product_line = 'Pinch Pleat';

UPDATE "public"."BOMTemplates"
SET product_line = 'wave'
WHERE product_line = 'Wave';

-- 2. Add display_name, image_url, product_line to FabricRules if not present
ALTER TABLE "public"."FabricRules"
  ADD COLUMN IF NOT EXISTS "display_name" text,
  ADD COLUMN IF NOT EXISTS "image_url" text,
  ADD COLUMN IF NOT EXISTS "product_line" text;

-- 3. Backfill display_name and product_line for existing rows
UPDATE "public"."FabricRules"
SET display_name = CASE style_code
      WHEN 'wave_2.3'    THEN 'Wave 2.3'
      WHEN 'wave_2.8'    THEN 'Wave 2.8'
      WHEN 'pinch_pleat'  THEN 'Pinch Pleat'
      WHEN 'ripple_fold'  THEN 'Ripple Fold'
      ELSE style_code
    END,
    product_line = CASE
      WHEN style_code LIKE 'wave%'   THEN 'wave'
      WHEN style_code LIKE 'ripple%' THEN 'ripple_fold'
      WHEN style_code = 'pinch_pleat' THEN 'pinch_pleat'
      ELSE NULL
    END
WHERE style_code IS NOT NULL
  AND (display_name IS NULL OR product_line IS NULL);

-- 4. Insert ripple_fold FabricRule if not already present
INSERT INTO "public"."FabricRules" (
  organization_id, product_type_id, style_code, display_name, product_line,
  formula_code, fullness_factor, height_multiplier, width_multiplier,
  extra_height_m, extra_width_m, pricing_output_uom, waste_pct,
  round_to_increment, min_qty, is_active,
  top_hem_cm, bottom_hem_cm, side_hem_cm,
  fabric_orientation, fabric_width_source,
  tube_wrap_mm, bottom_wrap_mm, safety_margin_mm, panel_multiplier
)
SELECT
  organization_id, product_type_id,
  'ripple_fold', 'Ripple Fold', 'ripple_fold',
  'DRAPERY_PANELS', 2.0, height_multiplier, width_multiplier,
  extra_height_m, extra_width_m, pricing_output_uom, waste_pct,
  round_to_increment, min_qty, true,
  top_hem_cm, bottom_hem_cm, side_hem_cm,
  fabric_orientation, fabric_width_source,
  tube_wrap_mm, bottom_wrap_mm, safety_margin_mm, panel_multiplier
FROM "public"."FabricRules"
WHERE style_code = 'wave_2.3'
  AND NOT EXISTS (
    SELECT 1 FROM "public"."FabricRules" WHERE style_code = 'ripple_fold'
  )
LIMIT 1;

NOTIFY pgrst, 'reload schema';
