-- ====================================================
-- FIX: Add missing dimensional columns to BomInstanceLines
-- ====================================================
-- This script safely adds the columns needed for Engineering Rules
-- It checks if columns exist before adding them
-- ====================================================

-- Step 1: Verify current state
SELECT 
    'Current columns in BomInstanceLines:' as info,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'BomInstanceLines'
AND column_name IN (
    'cut_length_mm',
    'cut_width_mm',
    'cut_height_mm',
    'calc_notes'
)
ORDER BY column_name;

-- Step 2: Add columns if they don't exist
DO $$
BEGIN
    -- Add cut_length_mm
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_length_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines" ADD COLUMN cut_length_mm integer;
        RAISE NOTICE '✅ Added cut_length_mm';
    ELSE
        RAISE NOTICE '⚠️ cut_length_mm already exists';
    END IF;

    -- Add cut_width_mm
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_width_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines" ADD COLUMN cut_width_mm integer;
        RAISE NOTICE '✅ Added cut_width_mm';
    ELSE
        RAISE NOTICE '⚠️ cut_width_mm already exists';
    END IF;

    -- Add cut_height_mm
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_height_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines" ADD COLUMN cut_height_mm integer;
        RAISE NOTICE '✅ Added cut_height_mm';
    ELSE
        RAISE NOTICE '⚠️ cut_height_mm already exists';
    END IF;

    -- Add calc_notes
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'calc_notes'
    ) THEN
        ALTER TABLE "BomInstanceLines" ADD COLUMN calc_notes text;
        RAISE NOTICE '✅ Added calc_notes';
    ELSE
        RAISE NOTICE '⚠️ calc_notes already exists';
    END IF;
END $$;

-- Step 3: Add comments
COMMENT ON COLUMN "BomInstanceLines".cut_length_mm IS 'Cut length in millimeters (calculated from Engineering Rules)';
COMMENT ON COLUMN "BomInstanceLines".cut_width_mm IS 'Cut width in millimeters (calculated from Engineering Rules)';
COMMENT ON COLUMN "BomInstanceLines".cut_height_mm IS 'Cut height in millimeters (calculated from Engineering Rules)';
COMMENT ON COLUMN "BomInstanceLines".calc_notes IS 'Calculation notes from Engineering Rules dimensional adjustments';

-- Step 4: Verify columns were added
SELECT 
    'Verification - columns after fix:' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'BomInstanceLines'
AND column_name IN (
    'cut_length_mm',
    'cut_width_mm',
    'cut_height_mm',
    'calc_notes'
)
ORDER BY column_name;

-- Expected result: 4 rows (one for each column)






