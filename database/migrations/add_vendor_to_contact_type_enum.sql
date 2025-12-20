-- ====================================================
-- Migration: Add 'vendor' to directory_contact_type enum
-- ====================================================
-- This adds 'vendor' as a valid value to the directory_contact_type enum
-- Required for contacts that represent vendors

-- Add 'vendor' to the directory_contact_type enum
-- Note: In PostgreSQL, you can only add values to an enum, not remove them
-- If the value already exists, this will fail gracefully
DO $$
BEGIN
  -- Check if 'vendor' already exists in the enum
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_enum 
    WHERE enumlabel = 'vendor' 
      AND enumtypid = (
        SELECT oid 
        FROM pg_type 
        WHERE typname = 'directory_contact_type'
      )
  ) THEN
    -- Add 'vendor' to the enum
    ALTER TYPE directory_contact_type ADD VALUE 'vendor';
    RAISE NOTICE 'Successfully added ''vendor'' to directory_contact_type enum';
  ELSE
    RAISE NOTICE '''vendor'' already exists in directory_contact_type enum';
  END IF;
END $$;

-- ====================================================
-- Verification
-- ====================================================
-- Run this query to verify all enum values:
-- SELECT enumlabel 
-- FROM pg_enum 
-- WHERE enumtypid = (
--   SELECT oid 
--   FROM pg_type 
--   WHERE typname = 'directory_contact_type'
-- )
-- ORDER BY enumsortorder;
--
-- Expected values:
-- - architect
-- - interior_designer
-- - project_manager
-- - consultant
-- - dealer
-- - reseller
-- - partner
-- - vendor (newly added)





