-- ============================================================================
-- Add opening_direction and drive_side to BOMTemplates
-- These columns allow template filtering based on curtain opening configuration.
-- opening_direction: 'left', 'right', 'center', or NULL (applies to all)
-- drive_side: 'left', 'right', or NULL (applies to both)
-- ============================================================================

ALTER TABLE "public"."BOMTemplates"
  ADD COLUMN IF NOT EXISTS "opening_direction" text,
  ADD COLUMN IF NOT EXISTS "drive_side" text;

-- Validate opening_direction values
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

-- Validate drive_side values
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

NOTIFY pgrst, 'reload schema';
