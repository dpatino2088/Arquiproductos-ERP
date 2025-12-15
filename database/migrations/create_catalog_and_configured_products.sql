-- ====================================================
-- Migration: Create Catalog and Configured Products Tables
-- ====================================================
-- Implements unified Catalog system with Manufacturers, Categories, Collections, Variants
-- and Configured Products with BOM and Rules for curtain quoting
-- Tables: PascalCase, Columns: snake_case
-- Includes standard audit fields: deleted, archived, created_at, updated_at, created_by, updated_by
-- ====================================================

-- Enable pgcrypto extension for gen_random_uuid() if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 1: Create ENUMs (idempotent)
-- ====================================================

-- catalog_item_type ENUM
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'catalog_item_type') THEN
        CREATE TYPE catalog_item_type AS ENUM (
            'component',
            'fabric',
            'linear',
            'service',
            'accessory'
        );
        RAISE NOTICE '✅ Created enum catalog_item_type';
    ELSE
        RAISE NOTICE '⏭️  Enum catalog_item_type already exists';
    END IF;
END $$;

-- catalog_uom ENUM
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'catalog_uom') THEN
        CREATE TYPE catalog_uom AS ENUM (
            'ea',
            'm',
            'sqm',
            'roll'
        );
        RAISE NOTICE '✅ Created enum catalog_uom';
    ELSE
        RAISE NOTICE '⏭️  Enum catalog_uom already exists';
    END IF;
END $$;

-- fabric_pricing_mode ENUM (may already exist, but make idempotent)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'fabric_pricing_mode') THEN
        CREATE TYPE fabric_pricing_mode AS ENUM (
            'per_linear_m',
            'per_sqm'
        );
        RAISE NOTICE '✅ Created enum fabric_pricing_mode';
    ELSE
        RAISE NOTICE '⏭️  Enum fabric_pricing_mode already exists';
    END IF;
END $$;

-- bom_qty_basis ENUM
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'bom_qty_basis') THEN
        CREATE TYPE bom_qty_basis AS ENUM (
            'per_unit',
            'per_width_m',
            'per_height_m',
            'per_area_sqm',
            'fixed'
        );
        RAISE NOTICE '✅ Created enum bom_qty_basis';
    ELSE
        RAISE NOTICE '⏭️  Enum bom_qty_basis already exists';
    END IF;
END $$;

-- rule_type ENUM
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rule_type') THEN
        CREATE TYPE rule_type AS ENUM (
            'allowed_collection',
            'allowed_variant',
            'allowed_item'
        );
        RAISE NOTICE '✅ Created enum rule_type';
    ELSE
        RAISE NOTICE '⏭️  Enum rule_type already exists';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Create updated_at trigger function (if not exists)
-- ====================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ====================================================
-- STEP 3: Create Manufacturers table
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
-- STEP 4: Create ItemCategories table (nested)
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
-- STEP 5: Create CatalogItems table
-- ====================================================

CREATE TABLE IF NOT EXISTS "CatalogItems" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    
    -- Foreign keys
    manufacturer_id uuid REFERENCES "Manufacturers"(id) ON DELETE SET NULL,
    category_id uuid REFERENCES "ItemCategories"(id) ON DELETE SET NULL,
    
    -- Basic information
    sku text NOT NULL,
    name text NOT NULL,
    description text,
    
    -- Item classification
    item_type catalog_item_type NOT NULL,
    
    -- Units of measure
    uom catalog_uom NOT NULL,              -- base inventory unit
    purchase_uom catalog_uom NOT NULL,     -- how we buy
    sales_uom catalog_uom NOT NULL,        -- how we sell/quote
    
    -- Pricing
    cost numeric(12,4),
    price numeric(12,4),
    
    -- Status
    active boolean NOT NULL DEFAULT true,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Unique index for sku per organization (excluding deleted)
CREATE UNIQUE INDEX IF NOT EXISTS idx_catalog_items_org_sku_unique 
    ON "CatalogItems"(organization_id, sku) 
    WHERE deleted = false;

-- Indexes for CatalogItems
CREATE INDEX IF NOT EXISTS idx_catalog_items_organization_id 
    ON "CatalogItems"(organization_id);
CREATE INDEX IF NOT EXISTS idx_catalog_items_organization_item_type_active 
    ON "CatalogItems"(organization_id, item_type, active);
CREATE INDEX IF NOT EXISTS idx_catalog_items_manufacturer_id 
    ON "CatalogItems"(manufacturer_id);
CREATE INDEX IF NOT EXISTS idx_catalog_items_category_id 
    ON "CatalogItems"(category_id);
CREATE INDEX IF NOT EXISTS idx_catalog_items_organization_deleted 
    ON "CatalogItems"(organization_id, deleted);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_catalog_items_updated_at ON "CatalogItems";
CREATE TRIGGER set_catalog_items_updated_at
    BEFORE UPDATE ON "CatalogItems"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 6: Create CatalogCollections table
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
-- STEP 7: Create CatalogVariants table
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
CREATE INDEX IF NOT EXISTS idx_catalog_variants_organization_active 
    ON "CatalogVariants"(organization_id, active);
CREATE INDEX IF NOT EXISTS idx_catalog_variants_organization_deleted 
    ON "CatalogVariants"(organization_id, deleted);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_catalog_variants_updated_at ON "CatalogVariants";
CREATE TRIGGER set_catalog_variants_updated_at
    BEFORE UPDATE ON "CatalogVariants"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 8: Create CatalogItemVariants pivot table
-- ====================================================

CREATE TABLE IF NOT EXISTS "CatalogItemVariants" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    item_id uuid NOT NULL REFERENCES "CatalogItems"(id) ON DELETE CASCADE,
    variant_id uuid NOT NULL REFERENCES "CatalogVariants"(id) ON DELETE CASCADE,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Unique index for item-variant combination (excluding deleted)
CREATE UNIQUE INDEX IF NOT EXISTS idx_catalog_item_variants_org_item_variant_unique 
    ON "CatalogItemVariants"(organization_id, item_id, variant_id) 
    WHERE deleted = false;

-- Indexes for CatalogItemVariants
CREATE INDEX IF NOT EXISTS idx_catalog_item_variants_organization_id 
    ON "CatalogItemVariants"(organization_id);
CREATE INDEX IF NOT EXISTS idx_catalog_item_variants_item_id 
    ON "CatalogItemVariants"(item_id);
CREATE INDEX IF NOT EXISTS idx_catalog_item_variants_variant_id 
    ON "CatalogItemVariants"(variant_id);
CREATE INDEX IF NOT EXISTS idx_catalog_item_variants_organization_deleted 
    ON "CatalogItemVariants"(organization_id, deleted);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_catalog_item_variants_updated_at ON "CatalogItemVariants";
CREATE TRIGGER set_catalog_item_variants_updated_at
    BEFORE UPDATE ON "CatalogItemVariants"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 9: Create FabricSpecs table (1:1 with CatalogItems where item_type='fabric')
-- ====================================================

CREATE TABLE IF NOT EXISTS "FabricSpecs" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    item_id uuid NOT NULL UNIQUE REFERENCES "CatalogItems"(id) ON DELETE CASCADE,
    
    -- Fabric specifications
    roll_width_mm int NOT NULL,
    roll_length_m numeric(10,3) NOT NULL,
    pricing_mode fabric_pricing_mode NOT NULL DEFAULT 'per_linear_m',
    notes text,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Indexes for FabricSpecs
CREATE INDEX IF NOT EXISTS idx_fabric_specs_organization_id 
    ON "FabricSpecs"(organization_id);
CREATE INDEX IF NOT EXISTS idx_fabric_specs_item_id 
    ON "FabricSpecs"(item_id);
CREATE INDEX IF NOT EXISTS idx_fabric_specs_organization_deleted 
    ON "FabricSpecs"(organization_id, deleted);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_fabric_specs_updated_at ON "FabricSpecs";
CREATE TRIGGER set_fabric_specs_updated_at
    BEFORE UPDATE ON "FabricSpecs"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 10: Create ConfiguredProductTypes table
-- ====================================================

CREATE TABLE IF NOT EXISTS "ConfiguredProductTypes" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    name text NOT NULL,
    code text,
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

-- Indexes for ConfiguredProductTypes
CREATE INDEX IF NOT EXISTS idx_configured_product_types_organization_id 
    ON "ConfiguredProductTypes"(organization_id);
CREATE INDEX IF NOT EXISTS idx_configured_product_types_organization_deleted 
    ON "ConfiguredProductTypes"(organization_id, deleted);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_configured_product_types_updated_at ON "ConfiguredProductTypes";
CREATE TRIGGER set_configured_product_types_updated_at
    BEFORE UPDATE ON "ConfiguredProductTypes"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 11: Create ConfiguredProducts table
-- ====================================================

CREATE TABLE IF NOT EXISTS "ConfiguredProducts" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    configured_product_type_id uuid NOT NULL REFERENCES "ConfiguredProductTypes"(id) ON DELETE RESTRICT,
    name text NOT NULL,
    code text,
    
    -- Product specifications
    max_width_mm int,
    max_height_mm int,
    supports_side_channel boolean NOT NULL DEFAULT false,
    supports_motorization boolean NOT NULL DEFAULT false,
    
    -- Status
    active boolean NOT NULL DEFAULT true,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Indexes for ConfiguredProducts
CREATE INDEX IF NOT EXISTS idx_configured_products_organization_id 
    ON "ConfiguredProducts"(organization_id);
CREATE INDEX IF NOT EXISTS idx_configured_products_configured_product_type_id 
    ON "ConfiguredProducts"(configured_product_type_id);
CREATE INDEX IF NOT EXISTS idx_configured_products_organization_active 
    ON "ConfiguredProducts"(organization_id, active);
CREATE INDEX IF NOT EXISTS idx_configured_products_organization_deleted 
    ON "ConfiguredProducts"(organization_id, deleted);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_configured_products_updated_at ON "ConfiguredProducts";
CREATE TRIGGER set_configured_products_updated_at
    BEFORE UPDATE ON "ConfiguredProducts"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 12: Create ConfiguredProductBOM table
-- ====================================================

CREATE TABLE IF NOT EXISTS "ConfiguredProductBOM" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    configured_product_id uuid NOT NULL REFERENCES "ConfiguredProducts"(id) ON DELETE CASCADE,
    component_item_id uuid NOT NULL REFERENCES "CatalogItems"(id) ON DELETE RESTRICT,
    
    -- BOM calculation
    qty_basis bom_qty_basis NOT NULL,
    qty_factor numeric(12,4) NOT NULL DEFAULT 1,
    sort_order int NOT NULL DEFAULT 0,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Indexes for ConfiguredProductBOM
CREATE INDEX IF NOT EXISTS idx_configured_product_bom_organization_id 
    ON "ConfiguredProductBOM"(organization_id);
CREATE INDEX IF NOT EXISTS idx_configured_product_bom_configured_product_id 
    ON "ConfiguredProductBOM"(configured_product_id);
CREATE INDEX IF NOT EXISTS idx_configured_product_bom_component_item_id 
    ON "ConfiguredProductBOM"(component_item_id);
CREATE INDEX IF NOT EXISTS idx_configured_product_bom_organization_deleted 
    ON "ConfiguredProductBOM"(organization_id, deleted);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_configured_product_bom_updated_at ON "ConfiguredProductBOM";
CREATE TRIGGER set_configured_product_bom_updated_at
    BEFORE UPDATE ON "ConfiguredProductBOM"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 13: Create ConfiguredProductRules table
-- ====================================================

CREATE TABLE IF NOT EXISTS "ConfiguredProductRules" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    configured_product_id uuid NOT NULL REFERENCES "ConfiguredProducts"(id) ON DELETE CASCADE,
    
    -- Rule definition
    rule_type rule_type NOT NULL,
    collection_id uuid REFERENCES "CatalogCollections"(id) ON DELETE CASCADE,
    variant_id uuid REFERENCES "CatalogVariants"(id) ON DELETE CASCADE,
    item_id uuid REFERENCES "CatalogItems"(id) ON DELETE CASCADE,
    
    -- Additional condition data
    condition_json jsonb NOT NULL DEFAULT '{}'::jsonb,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Indexes for ConfiguredProductRules
CREATE INDEX IF NOT EXISTS idx_configured_product_rules_organization_id 
    ON "ConfiguredProductRules"(organization_id);
CREATE INDEX IF NOT EXISTS idx_configured_product_rules_configured_product_id 
    ON "ConfiguredProductRules"(configured_product_id);
CREATE INDEX IF NOT EXISTS idx_configured_product_rules_collection_id 
    ON "ConfiguredProductRules"(collection_id);
CREATE INDEX IF NOT EXISTS idx_configured_product_rules_variant_id 
    ON "ConfiguredProductRules"(variant_id);
CREATE INDEX IF NOT EXISTS idx_configured_product_rules_item_id 
    ON "ConfiguredProductRules"(item_id);
CREATE INDEX IF NOT EXISTS idx_configured_product_rules_organization_deleted 
    ON "ConfiguredProductRules"(organization_id, deleted);

-- Trigger for updated_at
DROP TRIGGER IF EXISTS set_configured_product_rules_updated_at ON "ConfiguredProductRules";
CREATE TRIGGER set_configured_product_rules_updated_at
    BEFORE UPDATE ON "ConfiguredProductRules"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 14: Add comments for documentation
-- ====================================================

COMMENT ON TABLE "Manufacturers" IS 'Manufacturers of catalog items';
COMMENT ON TABLE "ItemCategories" IS 'Nested categories for organizing catalog items';
COMMENT ON TABLE "CatalogItems" IS 'Unified catalog items table for all physical goods: components, fabrics, linear items, services, accessories';
COMMENT ON TABLE "CatalogCollections" IS 'Collections for grouping catalog items (e.g., fabric collections)';
COMMENT ON TABLE "CatalogVariants" IS 'Variants within collections (e.g., colors)';
COMMENT ON TABLE "CatalogItemVariants" IS 'Pivot table linking catalog items to variants';
COMMENT ON TABLE "FabricSpecs" IS 'Fabric-specific specifications (1:1 with CatalogItems where item_type=fabric)';
COMMENT ON TABLE "ConfiguredProductTypes" IS 'Types of configured products (e.g., curtain systems)';
COMMENT ON TABLE "ConfiguredProducts" IS 'Configured products with specifications (e.g., specific curtain systems)';
COMMENT ON TABLE "ConfiguredProductBOM" IS 'Bill of Materials for configured products';
COMMENT ON TABLE "ConfiguredProductRules" IS 'Rules limiting which collections/variants/items are compatible with configured products';

COMMENT ON COLUMN "CatalogItems".item_type IS 'Type of catalog item: component, fabric, linear, service, or accessory';
COMMENT ON COLUMN "CatalogItems".uom IS 'Base inventory unit of measure';
COMMENT ON COLUMN "CatalogItems".purchase_uom IS 'Unit of measure for purchasing';
COMMENT ON COLUMN "CatalogItems".sales_uom IS 'Unit of measure for sales/quotes';
COMMENT ON COLUMN "FabricSpecs".roll_width_mm IS 'Width of fabric roll in millimeters';
COMMENT ON COLUMN "FabricSpecs".roll_length_m IS 'Length of fabric roll in meters';
COMMENT ON COLUMN "FabricSpecs".pricing_mode IS 'How fabric is priced: per_linear_m or per_sqm';
COMMENT ON COLUMN "ConfiguredProductBOM".qty_basis IS 'Basis for quantity calculation: per_unit, per_width_m, per_height_m, per_area_sqm, or fixed';
COMMENT ON COLUMN "ConfiguredProductBOM".qty_factor IS 'Multiplier for quantity calculation';
COMMENT ON COLUMN "ConfiguredProductRules".rule_type IS 'Type of rule: allowed_collection, allowed_variant, or allowed_item';
COMMENT ON COLUMN "ConfiguredProductRules".condition_json IS 'Additional condition data in JSON format';

-- ====================================================
-- STEP 15: Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Created:';
    RAISE NOTICE '   - 5 ENUMs: catalog_item_type, catalog_uom, fabric_pricing_mode, bom_qty_basis, rule_type';
    RAISE NOTICE '   - 11 tables: Manufacturers, ItemCategories, CatalogItems, CatalogCollections,';
    RAISE NOTICE '                CatalogVariants, CatalogItemVariants, FabricSpecs,';
    RAISE NOTICE '                ConfiguredProductTypes, ConfiguredProducts, ConfiguredProductBOM,';
    RAISE NOTICE '                ConfiguredProductRules';
    RAISE NOTICE '   - Indexes and triggers configured';
    RAISE NOTICE '   - All tables are multi-tenant with organization_id';
END $$;



