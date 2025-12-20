-- ====================================================
-- Migration: Create Catalog Entities Tables
-- ====================================================
-- Creates Manufacturers, ItemCategories, CatalogCollections, and CatalogVariants tables
-- These tables are needed for the Catalog management UI
-- Tables: PascalCase, Columns: snake_case
-- Includes standard audit fields: deleted, archived, created_at, updated_at, created_by, updated_by
-- ====================================================

-- Enable pgcrypto extension for gen_random_uuid() if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 1: Create or reuse updated_at trigger function
-- ====================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ====================================================
-- STEP 2: Create Manufacturers table
-- ====================================================

CREATE TABLE IF NOT EXISTS "Manufacturers" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    name text NOT NULL,
    code text,
    notes text,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Indexes for Manufacturers
CREATE INDEX IF NOT EXISTS idx_manufacturers_organization_id 
    ON "Manufacturers"(organization_id);
CREATE INDEX IF NOT EXISTS idx_manufacturers_organization_deleted 
    ON "Manufacturers"(organization_id, deleted);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_manufacturers_updated_at ON "Manufacturers";
CREATE TRIGGER set_manufacturers_updated_at
    BEFORE UPDATE ON "Manufacturers"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 3: Create ItemCategories table (nested)
-- ====================================================

CREATE TABLE IF NOT EXISTS "ItemCategories" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    parent_id uuid REFERENCES "ItemCategories"(id) ON DELETE SET NULL,
    name text NOT NULL,
    code text,
    sort_order int NOT NULL DEFAULT 0,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Indexes for ItemCategories
CREATE INDEX IF NOT EXISTS idx_item_categories_organization_id 
    ON "ItemCategories"(organization_id);
CREATE INDEX IF NOT EXISTS idx_item_categories_parent_id 
    ON "ItemCategories"(parent_id);
CREATE INDEX IF NOT EXISTS idx_item_categories_organization_deleted 
    ON "ItemCategories"(organization_id, deleted);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_item_categories_updated_at ON "ItemCategories";
CREATE TRIGGER set_item_categories_updated_at
    BEFORE UPDATE ON "ItemCategories"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 4: Create CatalogCollections table
-- ====================================================

CREATE TABLE IF NOT EXISTS "CatalogCollections" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    name text NOT NULL,
    code text,
    description text,
    active boolean NOT NULL DEFAULT true,
    sort_order int NOT NULL DEFAULT 0,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Indexes for CatalogCollections
CREATE INDEX IF NOT EXISTS idx_catalog_collections_organization_id 
    ON "CatalogCollections"(organization_id);
CREATE INDEX IF NOT EXISTS idx_catalog_collections_organization_active 
    ON "CatalogCollections"(organization_id, active);
CREATE INDEX IF NOT EXISTS idx_catalog_collections_organization_deleted 
    ON "CatalogCollections"(organization_id, deleted);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_catalog_collections_updated_at ON "CatalogCollections";
CREATE TRIGGER set_catalog_collections_updated_at
    BEFORE UPDATE ON "CatalogCollections"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 5: Create CatalogVariants table
-- ====================================================

CREATE TABLE IF NOT EXISTS "CatalogVariants" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    collection_id uuid NOT NULL REFERENCES "CatalogCollections"(id) ON DELETE CASCADE,
    name text NOT NULL,
    code text,
    color_name text,
    active boolean NOT NULL DEFAULT true,
    sort_order int NOT NULL DEFAULT 0,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Unique index for variant name per collection (excluding deleted)
CREATE UNIQUE INDEX IF NOT EXISTS idx_catalog_variants_org_collection_name_unique 
    ON "CatalogVariants"(organization_id, collection_id, name) 
    WHERE deleted = false;

-- Indexes for CatalogVariants
CREATE INDEX IF NOT EXISTS idx_catalog_variants_organization_id 
    ON "CatalogVariants"(organization_id);
CREATE INDEX IF NOT EXISTS idx_catalog_variants_collection_id 
    ON "CatalogVariants"(collection_id);
CREATE INDEX IF NOT EXISTS idx_catalog_variants_organization_deleted 
    ON "CatalogVariants"(organization_id, deleted);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_catalog_variants_updated_at ON "CatalogVariants";
CREATE TRIGGER set_catalog_variants_updated_at
    BEFORE UPDATE ON "CatalogVariants"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- Summary
-- ====================================================
DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Created tables: Manufacturers, ItemCategories, CatalogCollections, CatalogVariants';
END $$;







