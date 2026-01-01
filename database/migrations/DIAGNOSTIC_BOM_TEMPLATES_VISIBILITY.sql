-- ====================================================
-- Diagnostic: BOM Templates Visibility Issue
-- ====================================================
-- Run these queries to diagnose why BOM templates are not showing
-- ====================================================

-- 1. Check if BOMTemplates table exists and has data
SELECT 
    COUNT(*) as total_templates,
    COUNT(*) FILTER (WHERE deleted = false) as active_templates,
    COUNT(*) FILTER (WHERE deleted = false AND active = true) as active_and_not_deleted,
    COUNT(DISTINCT organization_id) as unique_organizations
FROM "BOMTemplates";

-- 2. Show all BOM templates with their organization_id
-- Note: Check actual columns first
SELECT 
    id,
    organization_id,
    product_type_id,
    name,
    active,
    deleted,
    created_at
FROM "BOMTemplates"
ORDER BY created_at DESC
LIMIT 20;

-- 3. Check RLS policies on BOMTemplates
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
WHERE tablename = 'BOMTemplates'
ORDER BY policyname;

-- 4. Check if RLS is enabled on BOMTemplates
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'BOMTemplates';

-- 5. Test query that matches what the frontend does
-- Replace 'YOUR_ORG_ID' with an actual organization_id from query 2
SELECT 
    id,
    organization_id,
    product_type_id,
    name,
    description,
    active,
    deleted
FROM "BOMTemplates"
WHERE organization_id = (SELECT organization_id FROM "BOMTemplates" LIMIT 1)
AND deleted = false
ORDER BY created_at DESC;

-- 6. Check ProductTypes to see if they exist
SELECT 
    COUNT(*) as total_product_types,
    COUNT(DISTINCT organization_id) as unique_orgs
FROM "ProductTypes"
WHERE deleted = false;

