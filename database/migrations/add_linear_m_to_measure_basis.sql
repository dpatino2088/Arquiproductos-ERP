-- ====================================================
-- Migration: Add linear_m to measure_basis ENUM
-- ====================================================
-- IMPORTANT: Run this in TWO separate steps!
-- Step 1: Add the enum value (commit)
-- Step 2: Migrate data (commit)
-- ====================================================

-- ====================================================
-- STEP 1: Add linear_m to the enum
-- ====================================================
-- Run this FIRST and commit before running Step 2
-- ====================================================

-- Check if linear_m already exists, if not, add it
DO $$ 
BEGIN
    -- Check if linear_m already exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum 
        WHERE enumlabel = 'linear_m' 
        AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'measure_basis')
    ) THEN
        -- Add linear_m to the enum
        ALTER TYPE measure_basis ADD VALUE 'linear_m';
        RAISE NOTICE '✅ Added linear_m to measure_basis enum';
        RAISE NOTICE '⚠️  IMPORTANT: Commit this transaction before running Step 2!';
    ELSE
        RAISE NOTICE '⏭️  linear_m already exists in measure_basis enum';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️  Error adding linear_m: %', SQLERRM;
END $$;

-- ====================================================
-- STEP 2: Migrate existing data
-- ====================================================
-- Run this AFTER Step 1 has been committed
-- ====================================================

-- Migrate existing data in CatalogItems
-- Convert width_linear and height_linear to linear_m
UPDATE "CatalogItems" 
SET measure_basis = 'linear_m'::measure_basis
WHERE measure_basis::text IN ('width_linear', 'height_linear');

-- Migrate existing data in QuoteLines
UPDATE "QuoteLines" 
SET measure_basis_snapshot = 'linear_m'::measure_basis
WHERE measure_basis_snapshot::text IN ('width_linear', 'height_linear');

-- ====================================================
-- Summary
-- ====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed!';
    RAISE NOTICE '📋 Changes:';
    RAISE NOTICE '   - Added linear_m to measure_basis enum';
    RAISE NOTICE '   - Migrated width_linear and height_linear to linear_m';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  Note: width_linear and height_linear still exist in the enum';
    RAISE NOTICE '   but are no longer used. You can remove them later if needed.';
END $$;

