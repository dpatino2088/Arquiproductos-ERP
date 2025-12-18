-- ====================================================
-- Check CatalogCollections data and structure
-- ====================================================
-- This script helps diagnose why CatalogCollections might be empty
-- ====================================================

DO $$
DECLARE
    org_count integer;
    collection_count integer;
    table_exists boolean;
    column_exists boolean;
    rec RECORD;
    rec2 RECORD;
BEGIN
    -- Check if table exists
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogCollections'
    ) INTO table_exists;
    
    IF NOT table_exists THEN
        RAISE NOTICE '❌ Table CatalogCollections does not exist!';
        RAISE NOTICE '   Run create_catalog_entities_tables.sql first';
        RETURN;
    ELSE
        RAISE NOTICE '✅ Table CatalogCollections exists';
    END IF;
    
    -- Check if sort_order column exists
    SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogCollections' 
        AND column_name = 'sort_order'
    ) INTO column_exists;
    
    IF column_exists THEN
        RAISE NOTICE '✅ Column sort_order exists';
    ELSE
        RAISE NOTICE '⚠️  Column sort_order does NOT exist';
        RAISE NOTICE '   Run ensure_catalog_collections_sort_order.sql';
    END IF;
    
    -- Count total organizations
    SELECT COUNT(*) INTO org_count FROM "Organizations" WHERE deleted = false;
    RAISE NOTICE '📊 Total Organizations: %', org_count;
    
    -- Count total collections (all organizations)
    SELECT COUNT(*) INTO collection_count FROM "CatalogCollections" WHERE deleted = false;
    RAISE NOTICE '📊 Total Collections (all orgs): %', collection_count;
    
    -- Show collections per organization
    RAISE NOTICE '';
    RAISE NOTICE '📋 Collections by Organization:';
    FOR rec IN 
        SELECT 
            o.id as org_id,
            o.organization_name,
            COUNT(c.id) as collection_count
        FROM "Organizations" o
        LEFT JOIN "CatalogCollections" c ON c.organization_id = o.id AND c.deleted = false
        WHERE o.deleted = false
        GROUP BY o.id, o.organization_name
        ORDER BY o.organization_name
    LOOP
        RAISE NOTICE '   Organization: % (ID: %) - Collections: %', 
            rec.organization_name, 
            rec.org_id, 
            rec.collection_count;
    END LOOP;
    
    -- Show sample collections if any exist
    IF collection_count > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '📋 Sample Collections (first 5):';
        FOR rec2 IN 
            SELECT id, organization_id, name, code, active, deleted
            FROM "CatalogCollections"
            WHERE deleted = false
            ORDER BY created_at DESC
            LIMIT 5
        LOOP
            RAISE NOTICE '   - % (ID: %, Org: %, Active: %, Deleted: %)', 
                rec2.name, 
                rec2.id, 
                rec2.organization_id, 
                rec2.active, 
                rec2.deleted;
        END LOOP;
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '⚠️  No collections found in CatalogCollections table';
        RAISE NOTICE '   You need to create collections using the UI or SQL';
    END IF;
    
    -- Check RLS policies
    RAISE NOTICE '';
    RAISE NOTICE '🔒 RLS Status:';
    IF EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'CatalogCollections'
        AND rowsecurity = true
    ) THEN
        RAISE NOTICE '   RLS is ENABLED on CatalogCollections';
        RAISE NOTICE '   Make sure RLS policies allow SELECT for your organization';
    ELSE
        RAISE NOTICE '   RLS is DISABLED on CatalogCollections';
    END IF;
    
END $$;

