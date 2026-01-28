-- Migration: Add missing columns to BOMTemplates
-- Date: 2026-01-24
-- Description: Adds description and metadata columns to BOMTemplates table

-- Add description column (nullable text)
ALTER TABLE "public"."BOMTemplates"
ADD COLUMN IF NOT EXISTS "description" TEXT;

-- Add metadata column (nullable jsonb, default empty object)
ALTER TABLE "public"."BOMTemplates"
ADD COLUMN IF NOT EXISTS "metadata" JSONB DEFAULT '{}'::jsonb;

-- Comments
COMMENT ON COLUMN "public"."BOMTemplates"."description" IS 'Optional description for the BOM template.';
COMMENT ON COLUMN "public"."BOMTemplates"."metadata" IS 'Additional metadata for the BOM template (rules, priority, etc).';
