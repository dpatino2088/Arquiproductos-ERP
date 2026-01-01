-- ====================================================
-- Check: Can we write 'Approved' to quote_status enum?
-- ====================================================

-- Query 1: Check enum values
SELECT 
    t.typname as enum_name,
    e.enumlabel as enum_value
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
WHERE t.typname = 'quote_status'
ORDER BY e.enumsortorder;

-- Query 2: Test if 'Approved' can be cast to quote_status
-- This will fail if enum is case-sensitive and only has 'approved'
SELECT 'Approved'::quote_status as test_approved;
SELECT 'approved'::quote_status as test_approved_lowercase;

-- Query 3: Check current status values in Quotes table
SELECT 
    status,
    status::text as status_text,
    COUNT(*) as count
FROM "Quotes"
WHERE deleted = false
GROUP BY status, status::text
ORDER BY count DESC;


