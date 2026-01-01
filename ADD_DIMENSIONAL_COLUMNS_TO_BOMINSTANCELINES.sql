-- ====================================================
-- ADD: Dimensional columns to BomInstanceLines
-- ====================================================
-- This script adds the missing columns for Engineering Rules dimensions
-- Run this if VERIFY_BOM_COLUMNS_EXIST.sql returns 0 rows
-- ====================================================

-- Add cut_length_mm if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_length_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN cut_length_mm integer;
        
        RAISE NOTICE '✅ Added column cut_length_mm';
    ELSE
        RAISE NOTICE '⚠️ Column cut_length_mm already exists';
    END IF;
END $$;

-- Add cut_width_mm if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_width_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN cut_width_mm integer;
        
        RAISE NOTICE '✅ Added column cut_width_mm';
    ELSE
        RAISE NOTICE '⚠️ Column cut_width_mm already exists';
    END IF;
END $$;

-- Add cut_height_mm if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'cut_height_mm'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN cut_height_mm integer;
        
        RAISE NOTICE '✅ Added column cut_height_mm';
    ELSE
        RAISE NOTICE '⚠️ Column cut_height_mm already exists';
    END IF;
END $$;

-- Add calc_notes if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'BomInstanceLines' 
        AND column_name = 'calc_notes'
    ) THEN
        ALTER TABLE "BomInstanceLines" 
        ADD COLUMN calc_notes text;
        
        RAISE NOTICE '✅ Added column calc_notes';
    ELSE
        RAISE NOTICE '⚠️ Column calc_notes already exists';
    END IF;
END $$;

-- Add comments
COMMENT ON COLUMN "BomInstanceLines".cut_length_mm IS 'Cut length in millimeters (from Engineering Rules)';
COMMENT ON COLUMN "BomInstanceLines".cut_width_mm IS 'Cut width in millimeters (from Engineering Rules)';
COMMENT ON COLUMN "BomInstanceLines".cut_height_mm IS 'Cut height in millimeters (from Engineering Rules)';
COMMENT ON COLUMN "BomInstanceLines".calc_notes IS 'Calculation notes from Engineering Rules adjustments';

-- Verify columns were added
SELECT 
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






