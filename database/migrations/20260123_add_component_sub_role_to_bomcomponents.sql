-- Add component_sub_role column to BOMComponents if it doesn't exist
-- This column is used for sub-role granularity (e.g., hardware: fastener, end_cap, adapter)

BEGIN;

DO $$
DECLARE
  v_col_exists boolean;
BEGIN
  -- Check if component_sub_role column exists
  SELECT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'BOMComponents'
      AND column_name = 'component_sub_role'
  ) INTO v_col_exists;

  IF NOT v_col_exists THEN
    ALTER TABLE public."BOMComponents" 
      ADD COLUMN component_sub_role text;
    
    COMMENT ON COLUMN public."BOMComponents".component_sub_role IS 
      'Optional sub-role for granularity (e.g., hardware: fastener, end_cap, adapter)';
    
    RAISE NOTICE '✅ Added component_sub_role column to BOMComponents';
  ELSE
    RAISE NOTICE 'ℹ️  component_sub_role column already exists in BOMComponents';
  END IF;
END $$;

COMMIT;
