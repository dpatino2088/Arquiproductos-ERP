-- ====================================================
-- Migration: Ensure CatalogCollections has sort_order column
-- ====================================================
-- Adds sort_order column if it doesn't exist
-- ====================================================

DO $$
BEGIN
    -- Check if sort_order column exists in CatalogCollections
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogCollections' 
        AND column_name = 'sort_order'
    ) THEN
        -- Add the column if it doesn't exist
        ALTER TABLE "CatalogCollections"
            ADD COLUMN sort_order int NOT NULL DEFAULT 0;
        
        RAISE NOTICE '✅ Added sort_order column to CatalogCollections';
    ELSE
        RAISE NOTICE 'ℹ️  sort_order column already exists in CatalogCollections';
    END IF;
END $$;

-- Add comment
COMMENT ON COLUMN "CatalogCollections".sort_order IS 'Sort order for displaying collections in a specific sequence. Lower numbers appear first.';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ CatalogCollections sort_order column ensured';
END $$;













