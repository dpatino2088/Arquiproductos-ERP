-- ====================================================
-- Migration: Create CollectionsCatalog Table (Complete)
-- ====================================================
-- Creates CollectionsCatalog table for fabrics only with all relationships
-- This table stores fabric collections and variants with technical specs
-- Source of truth: CatalogItems (where is_fabric = true)
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
    
    -- Item Type (should always be 'fabric')
    item_type text NOT NULL DEFAULT 'fabric',
    
    -- Basic information (denormalized from CatalogItem)
    sku text NOT NULL,
    name text NOT NULL,
    description text,
    
    -- Collection and variant
    collection_name text NOT NULL, -- Collection name (e.g., "BLOCK", "FIJI")
    variant_name text NOT NULL, -- Variant/Color name
    
    -- Roll dimensions
    roll_width numeric, -- Ancho del rollo
    roll_length numeric, -- Largo del rollo
    roll_uom text, -- "m" or "yd"
    
    -- Technical characteristics
    grammage_gsm numeric, -- Gramaje
    openness_pct numeric, -- Apertura
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
    updated_by uuid,
    
    -- Constraints
    CONSTRAINT collections_catalog_item_type_check CHECK (item_type = 'fabric')
);

-- ====================================================
-- STEP 2: Create indexes
-- ====================================================

-- Index for organization queries
CREATE INDEX IF NOT EXISTS idx_collections_catalog_organization_id 
    ON "CollectionsCatalog"(organization_id);

-- Index for catalog_item_id lookups
CREATE INDEX IF NOT EXISTS idx_collections_catalog_catalog_item_id 
    ON "CollectionsCatalog"(catalog_item_id);

-- Index for fabric_id lookups
CREATE INDEX IF NOT EXISTS idx_collections_catalog_fabric_id 
    ON "CollectionsCatalog"(fabric_id);

-- Index for organization + catalog_item (unique constraint support)
CREATE INDEX IF NOT EXISTS idx_collections_catalog_org_catalog_item 
    ON "CollectionsCatalog"(organization_id, catalog_item_id);

-- Index for organization + fabric
CREATE INDEX IF NOT EXISTS idx_collections_catalog_org_fabric 
    ON "CollectionsCatalog"(organization_id, fabric_id);

-- Index for collection name searches
CREATE INDEX IF NOT EXISTS idx_collections_catalog_org_collection 
    ON "CollectionsCatalog"(organization_id, collection_name);

-- Index for SKU searches
CREATE INDEX IF NOT EXISTS idx_collections_catalog_org_sku 
    ON "CollectionsCatalog"(organization_id, sku);

-- Index for variant searches
CREATE INDEX IF NOT EXISTS idx_collections_catalog_org_variant 
    ON "CollectionsCatalog"(organization_id, variant_name);

-- Index for active/deleted filtering
CREATE INDEX IF NOT EXISTS idx_collections_catalog_org_deleted 
    ON "CollectionsCatalog"(organization_id, deleted);

CREATE INDEX IF NOT EXISTS idx_collections_catalog_org_active 
    ON "CollectionsCatalog"(organization_id, active);

-- Unique constraint: one record per catalog_item per organization
CREATE UNIQUE INDEX IF NOT EXISTS idx_collections_catalog_unique_item 
    ON "CollectionsCatalog"(organization_id, catalog_item_id) 
    WHERE deleted = false;

-- ====================================================
-- STEP 3: Create updated_at trigger
-- ====================================================

-- Ensure set_updated_at function exists
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS set_collections_catalog_updated_at ON "CollectionsCatalog";
CREATE TRIGGER set_collections_catalog_updated_at
    BEFORE UPDATE ON "CollectionsCatalog"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 4: Create sync function from CatalogItem
-- ====================================================
-- This function automatically copies data from CatalogItem when creating/updating CollectionsCatalog

CREATE OR REPLACE FUNCTION sync_collections_catalog_from_catalog_item()
RETURNS TRIGGER AS $$
DECLARE
    catalog_item_record RECORD;
BEGIN
    -- Fetch the linked CatalogItem
    SELECT 
        ci.sku,
        ci.name,
        ci.description,
        ci.item_type,
        ci.is_fabric,
        COALESCE(ci.roll_width_m, (ci.metadata->>'roll_width_m')::numeric) as roll_width_m,
        COALESCE(ci.cost_price, (ci.metadata->>'cost_price')::numeric) as cost_price,
        COALESCE(ci.unit_price, (ci.metadata->>'unit_price')::numeric) as unit_price,
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
    
    -- Ensure only fabrics are added
    IF NOT catalog_item_record.is_fabric THEN
        RAISE EXCEPTION 'Only fabrics (is_fabric=true) can be added to CollectionsCatalog. CatalogItem % is not a fabric', NEW.catalog_item_id;
    END IF;
    
    -- Copy basic info from CatalogItem
    NEW.sku := COALESCE(NEW.sku, catalog_item_record.sku);
    NEW.name := COALESCE(NEW.name, catalog_item_record.name);
    NEW.description := COALESCE(NEW.description, catalog_item_record.description);
    NEW.item_type := COALESCE(NEW.item_type, catalog_item_record.item_type, 'fabric');
    
    -- Copy roll dimensions
    IF catalog_item_record.roll_width_m IS NOT NULL THEN
        NEW.roll_width := catalog_item_record.roll_width_m;
        NEW.roll_uom := COALESCE(NEW.roll_uom, 'm');
    END IF;
    
    -- Copy cost info
    IF catalog_item_record.cost_price IS NOT NULL THEN
        NEW.cost_value := catalog_item_record.cost_price;
        NEW.cost_uom := COALESCE(NEW.cost_uom, catalog_item_record.uom, 'm');
    END IF;
    
    -- Extract technical specs from metadata if available
    IF catalog_item_record.metadata IS NOT NULL THEN
        IF catalog_item_record.metadata ? 'grammage_gsm' THEN
            NEW.grammage_gsm := COALESCE(NEW.grammage_gsm, (catalog_item_record.metadata->>'grammage_gsm')::numeric);
        END IF;
        IF catalog_item_record.metadata ? 'openness_pct' THEN
            NEW.openness_pct := COALESCE(NEW.openness_pct, (catalog_item_record.metadata->>'openness_pct')::numeric);
        END IF;
        IF catalog_item_record.metadata ? 'material' THEN
            NEW.material := COALESCE(NEW.material, catalog_item_record.metadata->>'material');
        END IF;
        IF catalog_item_record.metadata ? 'roll_length' THEN
            NEW.roll_length := COALESCE(NEW.roll_length, (catalog_item_record.metadata->>'roll_length')::numeric);
        END IF;
    END IF;
    
    -- Set fabric_id to catalog_item_id if not set (for fabrics, they are the same)
    IF NEW.fabric_id IS NULL THEN
        NEW.fabric_id := NEW.catalog_item_id;
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
-- STEP 5: Add table and column comments
-- ====================================================

COMMENT ON TABLE "CollectionsCatalog" IS 'Stores fabric collections and variants with technical specifications. Only fabrics (is_fabric=true) from CatalogItems should be in this table. Source of truth is CatalogItems.';

COMMENT ON COLUMN "CollectionsCatalog".id IS 'Primary key';
COMMENT ON COLUMN "CollectionsCatalog".organization_id IS 'FK to Organizations - multi-tenant isolation';
COMMENT ON COLUMN "CollectionsCatalog".catalog_item_id IS 'FK to CatalogItems - the source of truth for SKU, name, description, specs, and cost';
COMMENT ON COLUMN "CollectionsCatalog".fabric_id IS 'FK to CatalogItems where is_fabric=true - the master fabric reference';
COMMENT ON COLUMN "CollectionsCatalog".item_type IS 'Item type (should always be "fabric" for records in this table)';
COMMENT ON COLUMN "CollectionsCatalog".sku IS 'SKU - denormalized from CatalogItem.sku';
COMMENT ON COLUMN "CollectionsCatalog".name IS 'Name - denormalized from CatalogItem.name';
COMMENT ON COLUMN "CollectionsCatalog".description IS 'Description - denormalized from CatalogItem.description';
COMMENT ON COLUMN "CollectionsCatalog".collection_name IS 'Collection name/grouping (e.g., "BLOCK", "FIJI", "HONEY")';
COMMENT ON COLUMN "CollectionsCatalog".variant_name IS 'Variant/color name (e.g., "White", "Ivory", "Chalk")';
COMMENT ON COLUMN "CollectionsCatalog".roll_width IS 'Ancho del rollo (roll width)';
COMMENT ON COLUMN "CollectionsCatalog".roll_length IS 'Largo del rollo (roll length)';
COMMENT ON COLUMN "CollectionsCatalog".roll_uom IS 'Unit of measure for roll dimensions (e.g., "m", "yd")';
COMMENT ON COLUMN "CollectionsCatalog".grammage_gsm IS 'Gramaje (fabric weight in grams per square meter)';
COMMENT ON COLUMN "CollectionsCatalog".openness_pct IS 'Apertura (openness percentage)';
COMMENT ON COLUMN "CollectionsCatalog".material IS 'Material composition';
COMMENT ON COLUMN "CollectionsCatalog".cost_value IS 'Base cost - denormalized from CatalogItem.cost_price';
COMMENT ON COLUMN "CollectionsCatalog".cost_uom IS 'Cost unit of measure - denormalized from CatalogItem.uom';
COMMENT ON COLUMN "CollectionsCatalog".active IS 'Active status';
COMMENT ON COLUMN "CollectionsCatalog".deleted IS 'Soft delete flag';
COMMENT ON COLUMN "CollectionsCatalog".archived IS 'Archived flag';

-- ====================================================
-- STEP 6: Success message
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ CollectionsCatalog table created successfully';
    RAISE NOTICE '   - Table: CollectionsCatalog';
    RAISE NOTICE '   - FKs: Organizations, CatalogItems (catalog_item_id), CatalogItems (fabric_id)';
    RAISE NOTICE '   - Indexes: 10 indexes created';
    RAISE NOTICE '   - Triggers: sync_collections_catalog_trigger, set_collections_catalog_updated_at';
    RAISE NOTICE '   - Constraint: Only fabrics (is_fabric=true) can be added';
END $$;













