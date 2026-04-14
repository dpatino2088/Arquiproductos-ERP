ALTER TABLE "public"."FabricRules"
  ADD COLUMN IF NOT EXISTS fabric_width_source text NOT NULL DEFAULT 'finished_width',
  ADD COLUMN IF NOT EXISTS tube_wrap_mm numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bottom_wrap_mm numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS safety_margin_mm numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS panel_multiplier numeric NOT NULL DEFAULT 1;

COMMENT ON COLUMN "public"."FabricRules".fabric_width_source IS
  'Source for fabric cut width: tube_width, bottom_bar_width, finished_width, finished_width_x_fullness';
COMMENT ON COLUMN "public"."FabricRules".tube_wrap_mm IS
  'Extra mm added for fabric wrap around tube';
COMMENT ON COLUMN "public"."FabricRules".bottom_wrap_mm IS
  'Extra mm added for fabric wrap around bottom bar';
COMMENT ON COLUMN "public"."FabricRules".safety_margin_mm IS
  'Extra mm safety margin on fabric height';
COMMENT ON COLUMN "public"."FabricRules".panel_multiplier IS
  'Height multiplier for multi-layer products (Dual=2, Triple=3)';

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'fabric_rules_width_source_check'
  ) THEN
    ALTER TABLE "public"."FabricRules"
      ADD CONSTRAINT fabric_rules_width_source_check
      CHECK (fabric_width_source IN (
        'finished_width', 'tube_width', 'bottom_bar_width',
        'finished_width_x_fullness', 'track_width'
      ));
  END IF;
END $$;

-- Backfill existing Roller rules
UPDATE "public"."FabricRules"
SET fabric_width_source = 'tube_width',
    tube_wrap_mm = 35,
    bottom_wrap_mm = 50,
    safety_margin_mm = 20,
    panel_multiplier = 1
WHERE formula_code = 'ROLLER_DROPS'
  AND fabric_width_source = 'finished_width'
  AND tube_wrap_mm = 0;

-- Backfill Dual rules
UPDATE "public"."FabricRules"
SET fabric_width_source = 'tube_width',
    panel_multiplier = 2,
    tube_wrap_mm = 35,
    bottom_wrap_mm = 0,
    safety_margin_mm = 20,
    width_multiplier = 1
WHERE formula_code = 'ROLLER_DROPS'
  AND width_multiplier = 2;

-- Backfill Triple rules
UPDATE "public"."FabricRules"
SET fabric_width_source = 'tube_width',
    panel_multiplier = 3,
    tube_wrap_mm = 35,
    bottom_wrap_mm = 0,
    safety_margin_mm = 20,
    width_multiplier = 1
WHERE formula_code = 'ROLLER_DROPS'
  AND width_multiplier = 3;

-- Backfill Drapery rules
UPDATE "public"."FabricRules"
SET fabric_width_source = 'finished_width_x_fullness'
WHERE formula_code = 'DRAPERY_PANELS'
  AND fabric_width_source = 'finished_width';

-- dimension_outputs on ConfiguredProducts
ALTER TABLE "public"."ConfiguredProducts"
  ADD COLUMN IF NOT EXISTS dimension_outputs jsonb DEFAULT '{}'::jsonb;

COMMENT ON COLUMN "public"."ConfiguredProducts".dimension_outputs IS
  'System geometry outputs: tube_width_mm, bottom_bar_width_mm, fabric_cut_width_mm, etc.';;
