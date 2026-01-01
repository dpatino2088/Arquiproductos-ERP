-- ====================================================
-- Check SalesOrders RLS and data availability
-- ====================================================
-- Run these queries to diagnose why Sales Orders are not showing
-- ====================================================

-- 1. Check if SalesOrders table exists and has RLS enabled
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'SalesOrders';

-- 2. Check RLS policies on SalesOrders
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'SalesOrders'
ORDER BY policyname;

-- 3. Check if SalesOrders has any data (run as postgres/admin)
SELECT 
    COUNT(*) as total_orders,
    COUNT(*) FILTER (WHERE deleted = false) as active_orders,
    COUNT(DISTINCT organization_id) as unique_organizations
FROM "SalesOrders";

-- 4. Check SalesOrders for a specific organization (replace with your org ID)
-- First, get your organization_id:
SELECT id, name FROM "Organizations" WHERE deleted = false LIMIT 5;

-- Then check SalesOrders for that org (replace 'YOUR-ORG-ID' with actual ID):
SELECT 
    id,
    sale_order_no,
    organization_id,
    status,
    deleted,
    created_at
FROM "SalesOrders"
WHERE organization_id = 'YOUR-ORG-ID-HERE'::uuid
AND deleted = false
ORDER BY created_at DESC
LIMIT 10;

-- 5. Test the exact query the frontend uses (replace 'YOUR-ORG-ID' with actual ID):
SELECT *
FROM "SalesOrders"
WHERE organization_id = 'YOUR-ORG-ID-HERE'::uuid
AND deleted = false
ORDER BY created_at DESC;



