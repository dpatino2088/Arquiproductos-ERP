-- ====================================================
-- Check the actual table name in PostgreSQL
-- ====================================================
-- PostgreSQL is case-sensitive with quoted identifiers
-- ====================================================

-- Check if table exists with different name variations
SELECT 
    tablename,
    schemaname
FROM pg_tables
WHERE schemaname = 'public'
AND (
    tablename = 'SalesOrders' 
    OR tablename = 'SaleOrders'
    OR LOWER(tablename) = 'salesorders'
    OR LOWER(tablename) = 'saleorders'
)
ORDER BY tablename;

-- Check column names to confirm
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
AND (
    table_name = 'SalesOrders' 
    OR table_name = 'SaleOrders'
)
ORDER BY ordinal_position
LIMIT 10;



