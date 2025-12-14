-- ====================================================
-- QUICK FIX: Verify and Fix Organizations Column
-- ====================================================
-- This script quickly checks and fixes the Organizations table
-- to ensure organization_name column exists
-- ====================================================

-- Step 1: Check current state
SELECT 
  'Current state' as info,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'Organizations'
  AND column_name IN ('name', 'organization_name')
ORDER BY column_name;

-- Step 2: Fix if needed
DO $$ 
BEGIN
    -- If name exists and organization_name doesn't, rename it
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'Organizations' 
        AND column_name = 'name'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'Organizations' 
        AND column_name = 'organization_name'
    ) THEN
        ALTER TABLE "Organizations" 
        RENAME COLUMN name TO organization_name;
        
        RAISE NOTICE '✅ Fixed: Renamed name to organization_name';
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'Organizations' 
        AND column_name = 'organization_name'
    ) THEN
        RAISE NOTICE '✅ OK: organization_name already exists';
    ELSE
        RAISE NOTICE '⚠️ Warning: Neither name nor organization_name found';
    END IF;
END $$;

-- Step 3: Verify final state
SELECT 
  'Final state' as info,
  column_name,
  data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'Organizations'
  AND column_name IN ('name', 'organization_name')
ORDER BY column_name;

