-- ====================================================
-- Migration: Simplify measure_basis ENUM (Safe Version)
-- ====================================================
-- Replaces 'width_linear' and 'height_linear' with 'linear_m'
-- This migration is idempotent and safe to run multiple times
-- ====================================================

-- Step 1: Check if we need to migrate
DO $$ 
DECLARE
    enum_exists boolean;
    has_linear_m boolean;
BEGIN
    -- Check if measure_basis enum exists
    SELECT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'measure_basis'
    ) INTO enum_exists;
    
    IF enum_exists THEN
        -- Check if linear_m already exists in the enum
        SELECT EXISTS (
            SELECT 1 FROM pg_enum 
            WHERE enumlabel = 'linear_m' 
            AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'measure_basis')
        ) INTO has_linear_m;
        
        IF NOT has_linear_m THEN
            -- Add linear_m to existing enum
            ALTER TYPE measure_basis ADD VALUE IF NOT EXISTS 'linear_m';
            RAISE NOTICE '✅ Added linear_m to measure_basis enum';
        ELSE
            RAISE NOTICE '⏭️  linear_m already exists in measure_basis enum';
        END IF;
    ELSE
        RAISE NOTICE '⚠️  measure_basis enum does not exist. Run create_catalog_and_quotes_tables.sql first.';
    END IF;
END $$;

-- Step 2: Migrate existing data in CatalogItems
-- Convert width_linear and height_linear to linear_m
UPDATE "CatalogItems" 
SET measure_basis = 'linear_m'::measure_basis
WHERE measure_basis::text IN ('width_linear', 'height_linear')
  AND measure_basis::text != 'linear_m';

-- Step 3: Migrate existing data in QuoteLines
UPDATE "QuoteLines" 
SET measure_basis_snapshot = 'linear_m'::measure_basis
WHERE measure_basis_snapshot::text IN ('width_linear', 'height_linear')
  AND measure_basis_snapshot::text != 'linear_m';

-- Step 4: Create a new clean enum (we'll use this approach)
-- First, create the new enum if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'measure_basis_clean') THEN
        CREATE TYPE measure_basis_clean AS ENUM (
            'unit',
            'linear_m',
            'area',
            'fabric'
        );
        RAISE NOTICE '✅ Created measure_basis_clean enum';
    END IF;
END $$;

-- Step 5: Add temporary columns with new enum type
ALTER TABLE "CatalogItems" 
ADD COLUMN IF NOT EXISTS measure_basis_temp measure_basis_clean;

ALTER TABLE "QuoteLines" 
ADD COLUMN IF NOT EXISTS measure_basis_snapshot_temp measure_basis_clean;

-- Step 6: Migrate data to temporary columns
UPDATE "CatalogItems" 
SET measure_basis_temp = CASE 
    WHEN measure_basis::text = 'unit' THEN 'unit'::measure_basis_clean
    WHEN measure_basis::text IN ('width_linear', 'height_linear', 'linear_m') THEN 'linear_m'::measure_basis_clean
    WHEN measure_basis::text = 'area' THEN 'area'::measure_basis_clean
    WHEN measure_basis::text = 'fabric' THEN 'fabric'::measure_basis_clean
    ELSE 'unit'::measure_basis_clean
END
WHERE measure_basis_temp IS NULL;

UPDATE "QuoteLines" 
SET measure_basis_snapshot_temp = CASE 
    WHEN measure_basis_snapshot::text = 'unit' THEN 'unit'::measure_basis_clean
    WHEN measure_basis_snapshot::text IN ('width_linear', 'height_linear', 'linear_m') THEN 'linear_m'::measure_basis_clean
    WHEN measure_basis_snapshot::text = 'area' THEN 'area'::measure_basis_clean
    WHEN measure_basis_snapshot::text = 'fabric' THEN 'fabric'::measure_basis_clean
    ELSE 'unit'::measure_basis_clean
END
WHERE measure_basis_snapshot_temp IS NULL;

-- Step 7: Make temporary columns NOT NULL
ALTER TABLE "CatalogItems" 
ALTER COLUMN measure_basis_temp SET NOT NULL;

ALTER TABLE "QuoteLines" 
ALTER COLUMN measure_basis_snapshot_temp SET NOT NULL;

-- Step 8: Drop old columns and rename temporary ones
ALTER TABLE "CatalogItems" DROP COLUMN IF EXISTS measure_basis;
ALTER TABLE "CatalogItems" RENAME COLUMN measure_basis_temp TO measure_basis;

ALTER TABLE "QuoteLines" DROP COLUMN IF EXISTS measure_basis_snapshot;
ALTER TABLE "QuoteLines" RENAME COLUMN measure_basis_snapshot_temp TO measure_basis_snapshot;

-- Step 9: Drop old enum and rename new one
-- First, drop any remaining dependencies
DROP TYPE IF EXISTS measure_basis CASCADE;
ALTER TYPE measure_basis_clean RENAME TO measure_basis;

-- ====================================================
-- Summary
-- ====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Changes:';
    RAISE NOTICE '   - Replaced width_linear and height_linear with linear_m';
    RAISE NOTICE '   - Updated CatalogItems.measure_basis';
    RAISE NOTICE '   - Updated QuoteLines.measure_basis_snapshot';
    RAISE NOTICE '   - New enum values: unit, linear_m, area, fabric';
END $$;

