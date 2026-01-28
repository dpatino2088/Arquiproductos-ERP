-- Add metadata column to BOMComponents if it doesn't exist
-- This column is used for storing additional JSON metadata

BEGIN;

DO $$
DECLARE
  v_col_exists boolean;
BEGIN
  -- Check if metadata column exists
  SELECT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'BOMComponents'
      AND column_name = 'metadata'
  ) INTO v_col_exists;

  IF NOT v_col_exists THEN
    ALTER TABLE public."BOMComponents" 
      ADD COLUMN metadata jsonb;
    
    COMMENT ON COLUMN public."BOMComponents".metadata IS 
      'Additional JSON metadata for component configuration';
    
    RAISE NOTICE '✅ Added metadata column to BOMComponents';
  ELSE
    RAISE NOTICE 'ℹ️  metadata column already exists in BOMComponents';
  END IF;
END $$;

COMMIT;
