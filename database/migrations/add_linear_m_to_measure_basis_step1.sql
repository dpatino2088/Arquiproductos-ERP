-- ====================================================
-- Migration Step 1: Add linear_m to measure_basis ENUM
-- ====================================================
-- Run this FIRST, then commit, then run Step 2
-- ====================================================

-- Add linear_m to the enum (if it doesn't exist)
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
    ELSE
        RAISE NOTICE '⏭️  linear_m already exists in measure_basis enum';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️  Error adding linear_m: %', SQLERRM;
END $$;

