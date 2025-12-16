-- ====================================================
-- Migration: Simplify measure_basis ENUM
-- ====================================================
-- Replaces 'width_linear' and 'height_linear' with 'linear_m'
-- This simplifies the measure basis options
-- ====================================================

-- Step 1: Create new ENUM with simplified options
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'measure_basis_new') THEN
        CREATE TYPE measure_basis_new AS ENUM (
            'unit',
            'linear_m',
            'area',
            'fabric'
        );
        RAISE NOTICE '✅ Created new measure_basis_new enum';
    ELSE
        RAISE NOTICE '⏭️  Enum measure_basis_new already exists';
    END IF;
END $$;

-- Step 2: Add new column to CatalogItems with new type
ALTER TABLE "CatalogItems" 
ADD COLUMN IF NOT EXISTS measure_basis_new measure_basis_new;

-- Step 3: Migrate existing data from old enum to new enum
UPDATE "CatalogItems" 
SET measure_basis_new = CASE 
    WHEN measure_basis::text = 'unit' THEN 'unit'::measure_basis_new
    WHEN measure_basis::text IN ('width_linear', 'height_linear') THEN 'linear_m'::measure_basis_new
    WHEN measure_basis::text = 'area' THEN 'area'::measure_basis_new
    WHEN measure_basis::text = 'fabric' THEN 'fabric'::measure_basis_new
    ELSE 'unit'::measure_basis_new
END
WHERE measure_basis_new IS NULL;

-- Step 4: Make new column NOT NULL (after migration)
ALTER TABLE "CatalogItems" 
ALTER COLUMN measure_basis_new SET NOT NULL;

-- Step 5: Drop old column and rename new one
ALTER TABLE "CatalogItems" DROP COLUMN IF EXISTS measure_basis;
ALTER TABLE "CatalogItems" RENAME COLUMN measure_basis_new TO measure_basis;

-- Step 6: Do the same for QuoteLines.measure_basis_snapshot
ALTER TABLE "QuoteLines" 
ADD COLUMN IF NOT EXISTS measure_basis_snapshot_new measure_basis_new;

UPDATE "QuoteLines" 
SET measure_basis_snapshot_new = CASE 
    WHEN measure_basis_snapshot::text = 'unit' THEN 'unit'::measure_basis_new
    WHEN measure_basis_snapshot::text IN ('width_linear', 'height_linear') THEN 'linear_m'::measure_basis_new
    WHEN measure_basis_snapshot::text = 'area' THEN 'area'::measure_basis_new
    WHEN measure_basis_snapshot::text = 'fabric' THEN 'fabric'::measure_basis_new
    ELSE 'unit'::measure_basis_new
END
WHERE measure_basis_snapshot_new IS NULL;

ALTER TABLE "QuoteLines" 
ALTER COLUMN measure_basis_snapshot_new SET NOT NULL;

ALTER TABLE "QuoteLines" DROP COLUMN IF EXISTS measure_basis_snapshot;
ALTER TABLE "QuoteLines" RENAME COLUMN measure_basis_snapshot_new TO measure_basis_snapshot;

-- Step 7: Drop old ENUM and rename new one
DROP TYPE IF EXISTS measure_basis;
ALTER TYPE measure_basis_new RENAME TO measure_basis;

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
END $$;

