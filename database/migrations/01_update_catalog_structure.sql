-- ====================================================
-- Migration: Update Catalog Structure (Simplified)
-- ====================================================
-- This migration updates the catalog structure to use:
-- 1. CollectionsCatalog as entity table (id, name, manufacturer_id)
-- 2. variant_name as text field in CatalogItems (not FK)
-- 3. item_name field in CatalogItems
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Ensure CollectionsCatalog has correct structure
-- ====================================================

-- Add columns if they don't exist
DO $$
BEGIN
    -- Add manufacturer_id if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'CollectionsCatalog' 
        AND column_name = 'manufacturer_id'
    ) THEN
        ALTER TABLE "CollectionsCatalog" 
        ADD COLUMN manufacturer_id uuid REFERENCES "Manufacturers"(id);
    END IF;

    -- Add collection_type if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'CollectionsCatalog' 
        AND column_name = 'collection_type'
    ) THEN
        ALTER TABLE "CollectionsCatalog" 
        ADD COLUMN collection_type text;
    END IF;
END $$;

-- ====================================================
-- STEP 2: Update CatalogItems structure
-- ====================================================

-- Add item_name column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'CatalogItems' 
        AND column_name = 'item_name'
    ) THEN
        ALTER TABLE "CatalogItems" 
        ADD COLUMN item_name text;
    END IF;
END $$;

-- Add variant_name as text field (not FK) if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'CatalogItems' 
        AND column_name = 'variant_name'
    ) THEN
        ALTER TABLE "CatalogItems" 
        ADD COLUMN variant_name text;
    END IF;
END $$;

-- Migrate variant_id to variant_name if variant_id exists and variant_name is empty
-- This will be done in the import script, but we ensure the column exists

-- ====================================================
-- STEP 3: Clean up old data (optional - uncomment if needed)
-- ====================================================

-- Uncomment these if you want to clean existing data:
-- DELETE FROM "CatalogItemProductTypes" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6';
-- DELETE FROM "CatalogItems" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6';
-- DELETE FROM "CollectionVariants" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6';
-- DELETE FROM "CollectionsCatalog" WHERE organization_id = '4de856e8-36ce-480a-952b-a2f5083c69d6';

COMMIT;

-- ====================================================
-- Notes:
-- - CollectionVariants table is kept for backward compatibility but not used
-- - variant_name is now a text field in CatalogItems
-- - item_name stores the Item_name from CSV
-- ====================================================

