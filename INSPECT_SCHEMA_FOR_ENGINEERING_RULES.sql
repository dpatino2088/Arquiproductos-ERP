-- ====================================================
-- STEP 1: Inspect existing schema
-- ====================================================
-- Run these queries to understand the current schema
-- ====================================================

-- 1. List all tables
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- 2. Check EngineeringRules table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'EngineeringRules'
ORDER BY ordinal_position;

-- 3. Check CatalogItems table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'CatalogItems'
ORDER BY ordinal_position;

-- 4. Check QuoteLineComponents table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'QuoteLineComponents'
ORDER BY ordinal_position;

-- 5. Check BomInstanceLines table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'BomInstanceLines'
ORDER BY ordinal_position;

-- 6. Check ProductTypes table (if exists)
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'ProductTypes'
ORDER BY ordinal_position;

-- 7. Check QuoteLines for dimension fields
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'QuoteLines'
ORDER BY ordinal_position;

-- 8. Check SalesOrderLines for dimension fields
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
AND table_name = 'SalesOrderLines'
ORDER BY ordinal_position;






