-- ====================================================
-- Check Collections and Variants Data
-- ====================================================
-- This script helps diagnose why Collections and Variants are not showing

-- 1. Check if tables exist
SELECT 
    table_name,
    table_schema
FROM information_schema.tables
WHERE table_name IN ('CatalogCollections', 'CatalogVariants')
ORDER BY table_name;

-- 2. Check Collections count
SELECT 
    COUNT(*) as total_collections,
    COUNT(*) FILTER (WHERE deleted = false) as active_collections,
    COUNT(*) FILTER (WHERE deleted = true) as deleted_collections
FROM "CatalogCollections";

-- 3. Check Collections by organization
SELECT 
    organization_id,
    COUNT(*) as collection_count
FROM "CatalogCollections"
WHERE deleted = false
GROUP BY organization_id
ORDER BY collection_count DESC;

-- 4. Check Variants count
SELECT 
    COUNT(*) as total_variants,
    COUNT(*) FILTER (WHERE deleted = false) as active_variants,
    COUNT(*) FILTER (WHERE deleted = true) as deleted_variants
FROM "CatalogVariants";

-- 5. Check Variants by organization
SELECT 
    organization_id,
    COUNT(*) as variant_count
FROM "CatalogVariants"
WHERE deleted = false
GROUP BY organization_id
ORDER BY variant_count DESC;

-- 6. Sample Collections data
SELECT 
    id,
    organization_id,
    name,
    code,
    active,
    deleted,
    created_at
FROM "CatalogCollections"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 10;

-- 7. Sample Variants data
SELECT 
    id,
    organization_id,
    collection_id,
    name,
    code,
    color_name,
    active,
    deleted,
    created_at
FROM "CatalogVariants"
WHERE deleted = false
ORDER BY created_at DESC
LIMIT 10;

-- 8. Check RLS policies
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
WHERE tablename IN ('CatalogCollections', 'CatalogVariants')
ORDER BY tablename, policyname;













