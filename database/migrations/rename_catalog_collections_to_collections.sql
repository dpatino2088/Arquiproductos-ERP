-- ====================================================
-- Migration: Rename CatalogCollections to Collections
-- ====================================================
-- Simplifies the table name from CatalogCollections to Collections
-- ====================================================

-- Rename the table
ALTER TABLE IF EXISTS "CatalogCollections" RENAME TO "Collections";

-- Rename indexes
ALTER INDEX IF EXISTS idx_catalog_collections_organization_id 
    RENAME TO idx_collections_organization_id;

ALTER INDEX IF EXISTS idx_catalog_collections_organization_active 
    RENAME TO idx_collections_organization_active;

ALTER INDEX IF EXISTS idx_catalog_collections_organization_deleted 
    RENAME TO idx_collections_organization_deleted;

-- Rename trigger
DROP TRIGGER IF EXISTS set_catalog_collections_updated_at ON "Collections";
CREATE TRIGGER set_collections_updated_at
    BEFORE UPDATE ON "Collections"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- Update foreign key references in other tables
-- Note: CatalogVariants has collection_id FK
DO $$
BEGIN
    -- Check if CatalogVariants exists and has collection_id
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'CatalogVariants' 
        AND column_name = 'collection_id'
    ) THEN
        -- Drop old FK constraint
        ALTER TABLE "CatalogVariants" 
        DROP CONSTRAINT IF EXISTS catalog_variants_collection_id_fkey;
        
        -- Add new FK constraint pointing to renamed table
        ALTER TABLE "CatalogVariants" 
        ADD CONSTRAINT catalog_variants_collection_id_fkey 
        FOREIGN KEY (collection_id) REFERENCES "Collections"(id) ON DELETE CASCADE;
        
        RAISE NOTICE '✅ Updated CatalogVariants FK to point to Collections';
    END IF;
    
    -- Check if CollectionsCatalog exists and needs FK update
    -- (CollectionsCatalog uses collection as text, not FK, so no change needed)
    
    -- Check if CatalogItems has collection_id FK
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'CatalogItems' 
        AND column_name = 'collection_id'
    ) THEN
        -- Drop old FK constraint if it exists
        ALTER TABLE "CatalogItems" 
        DROP CONSTRAINT IF EXISTS catalog_items_collection_id_fkey;
        
        -- Add new FK constraint pointing to renamed table
        ALTER TABLE "CatalogItems" 
        ADD CONSTRAINT catalog_items_collection_id_fkey 
        FOREIGN KEY (collection_id) REFERENCES "Collections"(id) ON DELETE SET NULL;
        
        RAISE NOTICE '✅ Updated CatalogItems FK to point to Collections';
    END IF;
END $$;

-- Update comments
COMMENT ON TABLE "Collections" IS 'Product collections (e.g., BLOCK, FIJI, HONEY). Renamed from CatalogCollections.';
COMMENT ON COLUMN "Collections".name IS 'Collection name (e.g., BLOCK, FIJI, HONEY)';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Successfully renamed CatalogCollections to Collections';
    RAISE NOTICE '⚠️  Update all code references from CatalogCollections to Collections';
END $$;













