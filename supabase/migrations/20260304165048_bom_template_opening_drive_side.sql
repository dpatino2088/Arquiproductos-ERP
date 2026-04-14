ALTER TABLE "public"."BOMTemplates" ADD COLUMN IF NOT EXISTS "opening_direction" text, ADD COLUMN IF NOT EXISTS "drive_side" text;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bom_templates_opening_direction_check'
  ) THEN
    ALTER TABLE "public"."BOMTemplates"
      ADD CONSTRAINT bom_templates_opening_direction_check
      CHECK (opening_direction IS NULL OR opening_direction IN ('left', 'right', 'center'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'bom_templates_drive_side_check'
  ) THEN
    ALTER TABLE "public"."BOMTemplates"
      ADD CONSTRAINT bom_templates_drive_side_check
      CHECK (drive_side IS NULL OR drive_side IN ('left', 'right'));
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';;
