-- ====================================================
-- VERIFICAR: ¿Existen las columnas cut_length_mm en BomInstanceLines?
-- ====================================================
-- Si esta query devuelve 0 rows, las columnas NO existen
-- Si devuelve 4 rows, las columnas SÍ existen

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'BomInstanceLines'
AND column_name IN ('cut_length_mm', 'cut_width_mm', 'cut_height_mm', 'calc_notes')
ORDER BY column_name;




