-- Verificar esquema REAL actual de QuoteLines
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'QuoteLines'
ORDER BY ordinal_position;
