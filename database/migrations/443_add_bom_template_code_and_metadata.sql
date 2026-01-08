-- ====================================================
-- Migration 443: Add code and metadata to BOMTemplates
-- ====================================================
-- OBJETIVO: Agregar columna 'code' (único por organization_id) y 'metadata' (JSONB)
-- para soportar el MVP de BOM Templates explícitos
-- ====================================================

SET search_path = public;

BEGIN;

-- ====================================================
-- STEP 1: Add 'code' column to BOMTemplates (if not exists)
-- ====================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMTemplates' 
    AND column_name = 'code'
  ) THEN
    ALTER TABLE public."BOMTemplates" 
    ADD COLUMN code text;
    
    RAISE NOTICE '✅ Added code column to BOMTemplates';
  ELSE
    RAISE NOTICE 'ℹ️  code column already exists in BOMTemplates';
  END IF;
END $$;

-- ====================================================
-- STEP 2: Add 'metadata' column to BOMTemplates (if not exists)
-- ====================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMTemplates' 
    AND column_name = 'metadata'
  ) THEN
    ALTER TABLE public."BOMTemplates" 
    ADD COLUMN metadata jsonb NOT NULL DEFAULT '{}'::jsonb;
    
    RAISE NOTICE '✅ Added metadata column to BOMTemplates';
  ELSE
    RAISE NOTICE 'ℹ️  metadata column already exists in BOMTemplates';
  END IF;
END $$;

-- ====================================================
-- STEP 3: Create unique index on (organization_id, code)
-- ====================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_bomtemplates_organization_code_unique
  ON public."BOMTemplates"(organization_id, code)
  WHERE deleted = false AND code IS NOT NULL;

-- ====================================================
-- STEP 4: Add comments
-- ====================================================

COMMENT ON COLUMN public."BOMTemplates".code IS 
  'Unique template code within organization (e.g., ROLLER_MANUAL_BASIC_WHITE)';

COMMENT ON COLUMN public."BOMTemplates".metadata IS 
  'Template metadata (JSONB): { "drive": "manual"|"motor", "cassette": true|false, "hardware_color": "white"|"black"|"gray"|..., "system": "roller", "notes": "" }';

COMMIT;

