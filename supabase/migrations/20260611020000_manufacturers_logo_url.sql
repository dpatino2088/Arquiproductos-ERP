-- Add logo_url to Manufacturers for brand image support
ALTER TABLE "public"."Manufacturers"
  ADD COLUMN IF NOT EXISTS "logo_url" text;

COMMENT ON COLUMN "public"."Manufacturers"."logo_url"
  IS 'URL of manufacturer brand logo image (stored in catalog-images bucket)';
