-- Add condition_key / condition_value to BOMComponents
-- Allows conditional inclusion of components based on config_snapshot values

ALTER TABLE "public"."BOMComponents"
  ADD COLUMN IF NOT EXISTS "condition_key"   text,
  ADD COLUMN IF NOT EXISTS "condition_value" text;

COMMENT ON COLUMN "public"."BOMComponents"."condition_key"
  IS 'config_snapshot key that must match for this component to be included (null = always include)';
COMMENT ON COLUMN "public"."BOMComponents"."condition_value"
  IS 'Expected value of condition_key in config_snapshot';
