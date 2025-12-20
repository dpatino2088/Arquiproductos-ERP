-- ====================================================
-- Migration: Check Collections/CatalogCollections table structure
-- ====================================================
-- Verifies which table exists and what columns it has
-- ====================================================

DO $$
DECLARE
    v_table_name TEXT;
    v_has_active BOOLEAN;
    v_has_sort_order BOOLEAN;
    v_collection_count INTEGER;
BEGIN
    -- Check if Collections table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'Collections'
    ) THEN
        v_table_name := 'Collections';
        RAISE NOTICE '✅ Table "Collections" exists';
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogCollections'
    ) THEN
        v_table_name := 'CatalogCollections';
        RAISE NOTICE '✅ Table "CatalogCollections" exists';
    ELSE
        RAISE NOTICE '❌ Neither "Collections" nor "CatalogCollections" table exists!';
        RETURN;
    END IF;

    -- Check if 'active' column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = v_table_name
        AND column_name = 'active'
    ) INTO v_has_active;

    -- Check if 'sort_order' column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = v_table_name
        AND column_name = 'sort_order'
    ) INTO v_has_sort_order;

    -- Show column info
    RAISE NOTICE '📋 Table: %', v_table_name;
    RAISE NOTICE '   - Has "active" column: %', v_has_active;
    RAISE NOTICE '   - Has "sort_order" column: %', v_has_sort_order;

    -- Show all columns
    RAISE NOTICE '📋 Columns in %:', v_table_name;
    FOR v_table_name IN
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = v_table_name
        ORDER BY ordinal_position
    LOOP
        RAISE NOTICE '   - %', v_table_name;
    END LOOP;

    -- Count collections
    EXECUTE format('SELECT COUNT(*) FROM "%s" WHERE deleted = false', v_table_name) INTO v_collection_count;
    RAISE NOTICE '📊 Total collections (not deleted): %', v_collection_count;

    -- Show sample data
    IF v_collection_count > 0 THEN
        RAISE NOTICE '📋 Sample collections:';
        EXECUTE format('
            SELECT id, name, code, active, sort_order, deleted
            FROM "%s"
            WHERE deleted = false
            ORDER BY sort_order NULLS LAST, name
            LIMIT 5
        ', v_table_name);
    END IF;

END $$;



