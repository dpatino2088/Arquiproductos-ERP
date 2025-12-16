-- ====================================================
-- Migration Step 2: Migrate data to linear_m
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
    RAISE NOTICE '✅ Data migration completed!';
    RAISE NOTICE '📋 Migrated width_linear and height_linear to linear_m';
END $$;

