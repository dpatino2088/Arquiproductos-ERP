-- ====================================================
-- Migration: Create CollectionsCatalog Table
-- ====================================================
-- Replaces CatalogVariants with a denormalized table that links
-- CatalogItems (fabrics) to collections and variants
-- CollectionsCatalog is a projection of CatalogItem for browsing
-- ====================================================

-- Enable pgcrypto extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 1: Create CollectionsCatalog table
-- ====================================================

CREATE TABLE IF NOT EXISTS "CollectionsCatalog" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    
    -- Foreign keys
    catalog_item_id uuid NOT NULL REFERENCES "CatalogItems"(id) ON DELETE RESTRICT,
    fabric_id uuid NOT NULL REFERENCES "CatalogItems"(id) ON DELETE RESTRICT,
    
    -- Basic information (denormalized from CatalogItem)
    sku text NOT NULL,
    name text NOT NULL,
    description text,
    
    -- Collection and variant (replaces CatalogVariants)
    collection text NOT NULL,
    variant text NOT NULL, -- replaces color_name
    
    -- Roll dimensions
    roll_width numeric,
    roll_length numeric,
    roll_uom text, -- e.g. "m", "yd"
    
    -- Technical characteristics
    grammage_gsm numeric,
    openness_pct numeric,
    material text,
    
    -- Base cost info (sourced from CatalogItem)
    cost_value numeric,
    cost_uom text, -- "m" or "yd"
    
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

-- ====================================================
-- STEP 2: Create indexes
-- ====================================================

CREATE INDEX IF NOT EXISTS idx_collections_catalog_organization_catalog_item 
    ON "CollectionsCatalog"(organization_id, catalog_item_id);

CREATE INDEX IF NOT EXISTS idx_collections_catalog_organization_fabric 
    ON "CollectionsCatalog"(organization_id, fabric_id);

CREATE INDEX IF NOT EXISTS idx_collections_catalog_organization_collection 
    ON "CollectionsCatalog"(organization_id, collection);

CREATE INDEX IF NOT EXISTS idx_collections_catalog_organization_sku 
    ON "CollectionsCatalog"(organization_id, sku);

CREATE INDEX IF NOT EXISTS idx_collections_catalog_organization_deleted 
    ON "CollectionsCatalog"(organization_id, deleted);

CREATE INDEX IF NOT EXISTS idx_collections_catalog_catalog_item_id 
    ON "CollectionsCatalog"(catalog_item_id);

CREATE INDEX IF NOT EXISTS idx_collections_catalog_fabric_id 
    ON "CollectionsCatalog"(fabric_id);

-- Unique constraint: one collection+variant per catalog_item per organization
CREATE UNIQUE INDEX IF NOT EXISTS idx_collections_catalog_org_item_collection_variant_unique 
    ON "CollectionsCatalog"(organization_id, catalog_item_id, collection, variant) 
    WHERE deleted = false;

-- ====================================================
-- STEP 3: Create trigger for updated_at
-- ====================================================

-- Use existing set_updated_at function if it exists, otherwise create it
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_collections_catalog_updated_at ON "CollectionsCatalog";
CREATE TRIGGER set_collections_catalog_updated_at
    BEFORE UPDATE ON "CollectionsCatalog"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 4: Create function to auto-populate from CatalogItem
-- ====================================================
-- This function copies data from CatalogItem when creating/updating CollectionsCatalog

CREATE OR REPLACE FUNCTION sync_collections_catalog_from_catalog_item()
RETURNS TRIGGER AS $$
DECLARE
    catalog_item_record RECORD;
BEGIN
    -- Fetch the linked CatalogItem
    -- Note: CatalogItems may have different column names, so we check what exists
    SELECT 
        ci.sku,
        ci.name,
        ci.description,
        COALESCE(ci.roll_width_m, (ci.metadata->>'roll_width_m')::numeric) as roll_width_m,
        COALESCE(ci.cost_price, ci.cost, (ci.metadata->>'cost_price')::numeric) as cost_price,
        COALESCE(ci.unit_price, ci.price, (ci.metadata->>'unit_price')::numeric) as unit_price,
        ci.uom,
        ci.metadata
    INTO catalog_item_record
    FROM "CatalogItems" ci
    WHERE ci.id = NEW.catalog_item_id
      AND ci.deleted = false;
    
    -- If CatalogItem not found, raise error
    IF NOT FOUND THEN
        RAISE EXCEPTION 'CatalogItem with id % not found or deleted', NEW.catalog_item_id;
    END IF;
    
    -- Copy basic info from CatalogItem
    NEW.sku := COALESCE(NEW.sku, catalog_item_record.sku);
    NEW.name := COALESCE(NEW.name, catalog_item_record.name);
    NEW.description := COALESCE(NEW.description, catalog_item_record.description);
    
    -- Copy roll dimensions
    IF catalog_item_record.roll_width_m IS NOT NULL THEN
        NEW.roll_width := catalog_item_record.roll_width_m;
        NEW.roll_uom := 'm';
    END IF;
    
    -- Copy cost info
    IF catalog_item_record.cost_price IS NOT NULL THEN
        NEW.cost_value := catalog_item_record.cost_price;
        NEW.cost_uom := COALESCE(catalog_item_record.uom, 'm');
    END IF;
    
    -- Extract technical specs from metadata if available
    IF catalog_item_record.metadata IS NOT NULL THEN
        IF catalog_item_record.metadata ? 'grammage_gsm' THEN
            NEW.grammage_gsm := (catalog_item_record.metadata->>'grammage_gsm')::numeric;
        END IF;
        IF catalog_item_record.metadata ? 'openness_pct' THEN
            NEW.openness_pct := (catalog_item_record.metadata->>'openness_pct')::numeric;
        END IF;
        IF catalog_item_record.metadata ? 'material' THEN
            NEW.material := catalog_item_record.metadata->>'material';
        END IF;
        IF catalog_item_record.metadata ? 'roll_length' THEN
            NEW.roll_length := (catalog_item_record.metadata->>'roll_length')::numeric;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-populate on INSERT and UPDATE
DROP TRIGGER IF EXISTS sync_collections_catalog_trigger ON "CollectionsCatalog";
CREATE TRIGGER sync_collections_catalog_trigger
    BEFORE INSERT OR UPDATE ON "CollectionsCatalog"
    FOR EACH ROW
    EXECUTE FUNCTION sync_collections_catalog_from_catalog_item();

-- ====================================================
-- STEP 5: Add comments
-- ====================================================

COMMENT ON TABLE "CollectionsCatalog" IS 'Denormalized projection of CatalogItems for fabric collections and variants. Source of truth is CatalogItem.';
COMMENT ON COLUMN "CollectionsCatalog".catalog_item_id IS 'FK to CatalogItems - the source of truth for SKU, name, description, specs, and cost';
COMMENT ON COLUMN "CollectionsCatalog".fabric_id IS 'FK to CatalogItems where is_fabric=true - the master fabric reference';
COMMENT ON COLUMN "CollectionsCatalog".collection IS 'Collection name/grouping (e.g., "BLOCK", "FIJI")';
COMMENT ON COLUMN "CollectionsCatalog".variant IS 'Variant/color name (replaces color_name from CatalogVariants)';
COMMENT ON COLUMN "CollectionsCatalog".sku IS 'Denormalized from CatalogItem.sku';
COMMENT ON COLUMN "CollectionsCatalog".name IS 'Denormalized from CatalogItem.name';
COMMENT ON COLUMN "CollectionsCatalog".cost_value IS 'Denormalized from CatalogItem.cost_price';
COMMENT ON COLUMN "CollectionsCatalog".cost_uom IS 'Denormalized from CatalogItem.uom';

-- ====================================================
-- STEP 6: Deprecate CatalogVariants (mark as deprecated, don't delete)
-- ====================================================

-- Add a comment to CatalogVariants table indicating it's deprecated
COMMENT ON TABLE "CatalogVariants" IS 'DEPRECATED: Use CollectionsCatalog instead. This table is kept for backward compatibility but should not be used for new records.';

-- Print success messages
DO $$
BEGIN
    RAISE NOTICE '✅ CollectionsCatalog table created successfully';
    RAISE NOTICE '⚠️  CatalogVariants is now deprecated - use CollectionsCatalog instead';
END $$;

