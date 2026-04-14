ALTER TABLE "public"."BOMTemplates" ADD COLUMN IF NOT EXISTS "system_size" text;

COMMENT ON COLUMN "public"."BOMTemplates"."system_size" IS 'Track/rail profile size (48mm, 60mm, etc.). NULL = applies to all sizes.';

UPDATE "public"."BOMTemplates" SET system_size = '48mm' WHERE system_size IS NULL AND code LIKE '%48MM%';

UPDATE "public"."BOMTemplates" SET system_size = '60mm' WHERE system_size IS NULL AND code LIKE '%60MM%';

NOTIFY pgrst, 'reload schema';;
