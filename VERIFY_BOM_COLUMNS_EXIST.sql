-- ====================================================
-- VERIFY: Check if dimensional columns exist in BomInstanceLines
-- ====================================================

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
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

-- If this returns 0 rows, the columns don't exist and need to be added






