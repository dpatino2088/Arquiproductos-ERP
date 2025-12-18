-- ====================================================
-- Add collection_id column to CatalogItems
-- ====================================================
-- This allows catalog items (especially fabrics) to be directly linked to a collection

DO $$
BEGIN
    -- Check if column exists, if not add it
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'collection_id'
    ) THEN
        ALTER TABLE "CatalogItems"
            ADD COLUMN collection_id uuid REFERENCES "CatalogCollections"(id) ON DELETE SET NULL;
        
        -- Add index for better query performance
        CREATE INDEX IF NOT EXISTS idx_catalog_items_collection_id 
            ON "CatalogItems"(collection_id);
        
        RAISE NOTICE '✅ Added collection_id column to CatalogItems';
    ELSE
        RAISE NOTICE 'ℹ️  collection_id column already exists in CatalogItems';
    END IF;
END $$;

COMMENT ON COLUMN "CatalogItems".collection_id IS 'Foreign key to CatalogCollections. Used to group related items, especially fabrics by collection.';

