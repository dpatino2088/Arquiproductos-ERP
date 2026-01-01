-- ====================================================
-- Script: Verify Profiles Table Structure
-- ====================================================
-- This script checks if the "Profiles" table exists and
-- verifies if it should actually be "ProductOptionValues"
-- ====================================================

-- Step 1: Check if "Profiles" table exists
SELECT 
    'Step 1: Table Existence Check' as check_type,
    table_name,
    table_schema
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('Profiles', 'ProductOptionValues')
ORDER BY table_name;

-- Step 2: Compare structure of Profiles vs ProductOptionValues
SELECT 
    'Step 2: Profiles Table Structure' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'Profiles'
ORDER BY ordinal_position;

SELECT 
    'Step 2: ProductOptionValues Table Structure' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'ProductOptionValues'
ORDER BY ordinal_position;

-- Step 3: Check if Profiles has the same structure as ProductOptionValues
-- (This would indicate they are the same table with different names)
SELECT 
    'Step 3: Structure Comparison' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM information_schema.columns c1
            WHERE c1.table_name = 'Profiles'
            AND NOT EXISTS (
                SELECT 1 
                FROM information_schema.columns c2
                WHERE c2.table_name = 'ProductOptionValues'
                AND c2.column_name = c1.column_name
                AND c2.data_type = c1.data_type
            )
        ) OR EXISTS (
            SELECT 1 
            FROM information_schema.columns c2
            WHERE c2.table_name = 'ProductOptionValues'
            AND NOT EXISTS (
                SELECT 1 
                FROM information_schema.columns c1
                WHERE c1.table_name = 'Profiles'
                AND c1.column_name = c2.column_name
                AND c1.data_type = c2.data_type
            )
        ) THEN 'DIFFERENT STRUCTURES'
        ELSE 'SAME STRUCTURE (possibly same table)'
    END as comparison_result;

-- Step 4: Check foreign key relationships
SELECT 
    'Step 4: Foreign Keys - Profiles' as check_type,
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_name = 'Profiles'
AND tc.table_schema = 'public';

SELECT 
    'Step 4: Foreign Keys - ProductOptionValues' as check_type,
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
AND tc.table_name = 'ProductOptionValues'
AND tc.table_schema = 'public';

-- Step 5: Check sample data to understand purpose
SELECT 
    'Step 5: Sample Data - Profiles' as check_type,
    COUNT(*) as total_rows,
    COUNT(DISTINCT option_id) as distinct_options,
    STRING_AGG(DISTINCT value_code, ', ' ORDER BY value_code) as sample_value_codes
FROM (
    SELECT DISTINCT value_code 
    FROM "Profiles" 
    ORDER BY value_code 
    LIMIT 10
) sub;

-- Step 6: Verify if Profiles should be renamed to ProductOptionValues
SELECT 
    'Step 6: Recommendation' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = 'Profiles'
        ) AND EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = 'ProductOptionValues'
        ) THEN 'Both tables exist - need to check if Profiles is duplicate'
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = 'Profiles'
        ) AND NOT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = 'ProductOptionValues'
        ) THEN 'Profiles exists but ProductOptionValues does not - Profiles might be misnamed'
        ELSE 'ProductOptionValues exists - Profiles might be a view or alias'
    END as recommendation;

