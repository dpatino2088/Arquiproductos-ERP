-- ====================================================
-- Quick Verification Script
-- ====================================================
-- Run this to verify that SaleOrders and SaleOrderLines tables exist
-- ====================================================

-- Check if tables exist
SELECT 
    'SaleOrders' as table_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'SaleOrders'
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status,
    (SELECT COUNT(*) FROM "SaleOrders" WHERE deleted = false) as active_records
UNION ALL
SELECT 
    'SaleOrderLines' as table_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' 
            AND table_name = 'SaleOrderLines'
        ) THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status,
    (SELECT COUNT(*) FROM "SaleOrderLines" WHERE deleted = false) as active_records;

-- Check RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE tablename IN ('SaleOrders', 'SaleOrderLines')
ORDER BY tablename, policyname;

-- Check indexes
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename IN ('SaleOrders', 'SaleOrderLines')
ORDER BY tablename, indexname;








