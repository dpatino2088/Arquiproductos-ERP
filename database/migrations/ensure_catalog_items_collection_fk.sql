-- ====================================================
-- Migration: Ensure CatalogItems -> CatalogCollections FK
-- ====================================================
-- Ensures the foreign key relationship exists and is correct
-- ====================================================

DO $$
BEGIN
    -- Check if collection_id column exists in CatalogItems
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'collection_id'
    ) THEN
        -- Add the column if it doesn't exist
        ALTER TABLE "CatalogItems"
            ADD COLUMN collection_id uuid;
        
        RAISE NOTICE '✅ Added collection_id column to CatalogItems';
    ELSE
        RAISE NOTICE 'ℹ️  collection_id column already exists in CatalogItems';
    END IF;
    
    -- Check if FK constraint exists
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu 
            ON tc.constraint_name = kcu.constraint_name
        WHERE tc.table_schema = 'public'
            AND tc.table_name = 'CatalogItems'
            AND tc.constraint_type = 'FOREIGN KEY'
            AND kcu.column_name = 'collection_id'
    ) THEN
        -- Drop any existing constraint with different name
        ALTER TABLE "CatalogItems"
            DROP CONSTRAINT IF EXISTS catalog_items_collection_id_fkey;
        
        -- Add the FK constraint
        ALTER TABLE "CatalogItems"
            ADD CONSTRAINT catalog_items_collection_id_fkey 
            FOREIGN KEY (collection_id) 
            REFERENCES "CatalogCollections"(id) 
            ON DELETE SET NULL;
        
        RAISE NOTICE '✅ Added FK constraint catalog_items_collection_id_fkey';
    ELSE
        RAISE NOTICE 'ℹ️  FK constraint already exists';
    END IF;
    
    -- Ensure index exists for performance
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_indexes 
        WHERE schemaname = 'public' 
        AND tablename = 'CatalogItems' 
        AND indexname = 'idx_catalog_items_collection_id'
    ) THEN
        CREATE INDEX idx_catalog_items_collection_id 
            ON "CatalogItems"(collection_id);
        
        RAISE NOTICE '✅ Added index idx_catalog_items_collection_id';
    ELSE
        RAISE NOTICE 'ℹ️  Index already exists';
    END IF;
END $$;

-- Add comment
COMMENT ON COLUMN "CatalogItems".collection_id IS 'Foreign key to CatalogCollections. Used to group related items, especially fabrics by collection.';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ CatalogItems -> CatalogCollections FK relationship ensured';
END $$;

