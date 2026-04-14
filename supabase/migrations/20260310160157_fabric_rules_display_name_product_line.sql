ALTER TABLE "public"."FabricRules"
  ADD COLUMN IF NOT EXISTS "display_name" text,
  ADD COLUMN IF NOT EXISTS "image_url" text,
  ADD COLUMN IF NOT EXISTS "product_line" text;

COMMENT ON COLUMN "public"."FabricRules"."display_name" IS 'Human-readable label shown in configurator cards (e.g. Wave 2.3, Ripple Fold 1 7/8)';
COMMENT ON COLUMN "public"."FabricRules"."image_url" IS 'Optional image URL for configurator card display';
COMMENT ON COLUMN "public"."FabricRules"."product_line" IS 'Groups style variants under a product line (e.g. wave, ripple_fold, pinch_pleat)';

UPDATE "public"."FabricRules"
SET display_name = CASE style_code
  WHEN 'wave_2.3' THEN 'Wave 2.3'
  WHEN 'wave_2.8' THEN 'Wave 2.8'
  WHEN 'pinch_pleat' THEN 'Pinch Pleat'
  ELSE style_code
END,
product_line = CASE
  WHEN style_code LIKE 'wave%' THEN 'wave'
  WHEN style_code LIKE 'ripple%' THEN 'ripple_fold'
  WHEN style_code = 'pinch_pleat' THEN 'pinch_pleat'
  ELSE NULL
END
WHERE style_code IS NOT NULL
  AND display_name IS NULL;

NOTIFY pgrst, 'reload schema';;
