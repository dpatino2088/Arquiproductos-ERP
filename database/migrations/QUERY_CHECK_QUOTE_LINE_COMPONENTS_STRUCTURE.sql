-- Quick query to check QuoteLineComponents structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'QuoteLineComponents'
AND column_name LIKE '%cost%'
ORDER BY ordinal_position;


