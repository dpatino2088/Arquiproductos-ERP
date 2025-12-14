-- ====================================================
-- FIX ORGANIZATIONS COLUMN - SIMPLE AND DIRECT
-- ====================================================
-- This script directly fixes the Organizations table
-- Run this FIRST before anything else
-- ====================================================

-- Check what we have
SELECT 
  'BEFORE FIX' as status,
  column_name
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'Organizations'
  AND column_name IN ('name', 'organization_name');

-- Fix: Rename name to organization_name if needed
DO $$ 
BEGIN
    -- Check if name column exists
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'Organizations' 
        AND column_name = 'name'
    ) THEN
        -- Check if organization_name doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'Organizations' 
            AND column_name = 'organization_name'
        ) THEN
            -- Rename it
            ALTER TABLE "Organizations" 
            RENAME COLUMN name TO organization_name;
            
            RAISE NOTICE '✅ SUCCESS: Renamed Organizations.name to organization_name';
        ELSE
            RAISE NOTICE '⚠️ organization_name already exists, but name also exists. Dropping name...';
            -- If both exist, drop the old one
            ALTER TABLE "Organizations" 
            DROP COLUMN IF EXISTS name;
        END IF;
    ELSE
        -- If name doesn't exist, check if organization_name exists
        IF EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'Organizations' 
            AND column_name = 'organization_name'
        ) THEN
            RAISE NOTICE '✅ OK: organization_name already exists';
        ELSE
            RAISE NOTICE '❌ ERROR: Neither name nor organization_name found in Organizations table!';
        END IF;
    END IF;
END $$;

-- Verify what we have now
SELECT 
  'AFTER FIX' as status,
  column_name
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'Organizations'
  AND column_name IN ('name', 'organization_name');

-- Test query
SELECT 
  'TEST QUERY' as info,
  id,
  organization_name
FROM "Organizations"
WHERE deleted = false
LIMIT 3;

