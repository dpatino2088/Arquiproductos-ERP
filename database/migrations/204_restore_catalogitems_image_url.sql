-- ====================================================
-- Migration: Restore CatalogItems image_url Support
-- ====================================================
-- This migration ensures CatalogItems has image_url column
-- and restores UI support for image display/editing
-- ====================================================

-- STEP 1: Add image_url column to CatalogItems (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'CatalogItems' 
        AND column_name = 'image_url'
    ) THEN
        ALTER TABLE "CatalogItems"
        ADD COLUMN image_url text;
        
        COMMENT ON COLUMN "CatalogItems".image_url IS 
            'URL to the item image. Can be a Supabase Storage URL or external URL.';
        
        RAISE NOTICE '✅ Added image_url to CatalogItems';
    ELSE
        RAISE NOTICE '⏭️  image_url already exists in CatalogItems';
    END IF;
END $$;

-- STEP 2: Backfill image_url from metadata.image if it exists
-- (Some items might have image stored in metadata.image)
UPDATE "CatalogItems"
SET image_url = (metadata->>'image')
WHERE image_url IS NULL
AND metadata IS NOT NULL
AND metadata->>'image' IS NOT NULL
AND metadata->>'image' != ''
AND deleted = false;

-- Summary
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Migration 204 completed: Restored CatalogItems image_url';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Created/Updated:';
    RAISE NOTICE '   - Column: CatalogItems.image_url (if not exists)';
    RAISE NOTICE '   - Backfilled from metadata.image where available';
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Next Step:';
    RAISE NOTICE '   - Update CatalogItemNew.tsx UI to show image_url field';
    RAISE NOTICE '';
END $$;





