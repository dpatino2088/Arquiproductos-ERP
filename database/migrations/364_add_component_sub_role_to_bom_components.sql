-- ====================================================
-- Migration 364: Add component_sub_role to BOMComponents
-- ====================================================
-- Adds component_sub_role column to BOMComponents table
-- This column is optional and provides granularity for roles that support sub-roles
-- (e.g., hardware: fastener, end_cap, adapter)
-- ====================================================

DO $$
BEGIN
  -- Add component_sub_role column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'BOMComponents' 
    AND column_name = 'component_sub_role'
  ) THEN
    ALTER TABLE public."BOMComponents"
      ADD COLUMN component_sub_role text NULL;

    COMMENT ON COLUMN public."BOMComponents".component_sub_role IS 
      'Optional sub-role for granularity within a role (e.g., hardware: fastener, end_cap, adapter). Used with component_role for 2-level classification.';

    RAISE NOTICE '✅ Added component_sub_role column to BOMComponents';
  ELSE
    RAISE NOTICE '⚠️  component_sub_role column already exists in BOMComponents, skipping';
  END IF;
END $$;

