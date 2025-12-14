-- ====================================================
-- Migration: Create Catalog and Quotes Tables
-- ====================================================
-- Implements new modules Catalog and Quotes for made-to-measure curtain quoting workflow
-- Tables: PascalCase, Columns: snake_case
-- Includes standard audit fields: deleted, archived, created_at, updated_at, created_by, updated_by
-- ====================================================

-- Enable pgcrypto extension for gen_random_uuid() if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 1: Create ENUMs (idempotent)
-- ====================================================

-- measure_basis ENUM
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'measure_basis') THEN
        CREATE TYPE measure_basis AS ENUM (
            'unit',
            'width_linear',
            'height_linear',
            'area',
            'fabric'
        );
        RAISE NOTICE '✅ Created enum measure_basis';
    ELSE
        RAISE NOTICE '⏭️  Enum measure_basis already exists';
    END IF;
END $$;

-- fabric_pricing_mode ENUM
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

-- quote_status ENUM
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'quote_status') THEN
        CREATE TYPE quote_status AS ENUM (
            'draft',
            'sent',
            'approved',
            'rejected',
            'cancelled'
        );
        RAISE NOTICE '✅ Created enum quote_status';
    ELSE
        RAISE NOTICE '⏭️  Enum quote_status already exists';
    END IF;
END $$;

-- ====================================================
-- STEP 2: Create CatalogItems table
-- ====================================================

CREATE TABLE IF NOT EXISTS "CatalogItems" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    
    -- Basic information
    sku text NOT NULL,
    name text NOT NULL,
    description text,
    
    -- Measurement and pricing
    measure_basis measure_basis NOT NULL,
    uom text NOT NULL DEFAULT 'unit', -- Unit of measure (e.g., 'unit', 'm', 'sqm')
    
    -- Fabric-specific fields
    is_fabric boolean NOT NULL DEFAULT false,
    roll_width_m numeric(10, 3), -- Width of fabric roll in meters
    fabric_pricing_mode fabric_pricing_mode,
    
    -- Pricing
    unit_price numeric(12, 2) NOT NULL DEFAULT 0,
    cost_price numeric(12, 2) NOT NULL DEFAULT 0,
    
    -- Status
    active boolean NOT NULL DEFAULT true,
    discontinued boolean NOT NULL DEFAULT false,
    
    -- Metadata
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    
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
CREATE INDEX IF NOT EXISTS idx_catalog_items_organization_deleted 
    ON "CatalogItems"(organization_id, deleted);
CREATE INDEX IF NOT EXISTS idx_catalog_items_organization_active 
    ON "CatalogItems"(organization_id, active, deleted);
CREATE INDEX IF NOT EXISTS idx_catalog_items_sku 
    ON "CatalogItems"(sku);
CREATE INDEX IF NOT EXISTS idx_catalog_items_is_fabric 
    ON "CatalogItems"(is_fabric) WHERE is_fabric = true;

-- ====================================================
-- STEP 3: Create Quotes table
-- ====================================================

CREATE TABLE IF NOT EXISTS "Quotes" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    customer_id uuid NOT NULL REFERENCES "DirectoryCustomers"(id) ON DELETE RESTRICT,
    
    -- Quote information
    quote_no text NOT NULL,
    status quote_status NOT NULL DEFAULT 'draft',
    currency text NOT NULL DEFAULT 'USD',
    
    -- Totals (stored as JSONB for flexibility)
    totals jsonb NOT NULL DEFAULT '{"subtotal": 0, "tax": 0, "total": 0}'::jsonb,
    
    -- Notes
    notes text,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Unique index for quote_no per organization (excluding deleted)
CREATE UNIQUE INDEX IF NOT EXISTS idx_quotes_org_quote_no_unique 
    ON "Quotes"(organization_id, quote_no) 
    WHERE deleted = false;

-- Indexes for Quotes
CREATE INDEX IF NOT EXISTS idx_quotes_organization_id 
    ON "Quotes"(organization_id);
CREATE INDEX IF NOT EXISTS idx_quotes_customer_id 
    ON "Quotes"(customer_id);
CREATE INDEX IF NOT EXISTS idx_quotes_organization_deleted 
    ON "Quotes"(organization_id, deleted);
CREATE INDEX IF NOT EXISTS idx_quotes_status 
    ON "Quotes"(status);
CREATE INDEX IF NOT EXISTS idx_quotes_quote_no 
    ON "Quotes"(quote_no);
CREATE INDEX IF NOT EXISTS idx_quotes_organization_status 
    ON "Quotes"(organization_id, status, deleted);

-- ====================================================
-- STEP 4: Create QuoteLines table
-- ====================================================

CREATE TABLE IF NOT EXISTS "QuoteLines" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    quote_id uuid NOT NULL REFERENCES "Quotes"(id) ON DELETE CASCADE,
    catalog_item_id uuid NOT NULL REFERENCES "CatalogItems"(id) ON DELETE RESTRICT,
    
    -- Quantity
    qty numeric(10, 3) NOT NULL DEFAULT 1,
    
    -- Dimensions (in meters)
    width_m numeric(10, 3),
    height_m numeric(10, 3),
    
    -- Snapshots (captured at time of quote creation)
    measure_basis_snapshot measure_basis NOT NULL,
    roll_width_m_snapshot numeric(10, 3),
    fabric_pricing_mode_snapshot fabric_pricing_mode,
    
    -- Computed values
    computed_qty numeric(12, 4) NOT NULL DEFAULT 0,
    
    -- Price snapshots
    unit_price_snapshot numeric(12, 2) NOT NULL DEFAULT 0,
    unit_cost_snapshot numeric(12, 2) NOT NULL DEFAULT 0,
    
    -- Line total
    line_total numeric(12, 2) NOT NULL DEFAULT 0,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid
);

-- Indexes for QuoteLines
CREATE INDEX IF NOT EXISTS idx_quote_lines_organization_id 
    ON "QuoteLines"(organization_id);
CREATE INDEX IF NOT EXISTS idx_quote_lines_quote_id 
    ON "QuoteLines"(quote_id);
CREATE INDEX IF NOT EXISTS idx_quote_lines_catalog_item_id 
    ON "QuoteLines"(catalog_item_id);
CREATE INDEX IF NOT EXISTS idx_quote_lines_organization_deleted 
    ON "QuoteLines"(organization_id, deleted);

-- ====================================================
-- STEP 5: Create updated_at trigger function (if not exists)
-- ====================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
DROP TRIGGER IF EXISTS set_catalog_items_updated_at ON "CatalogItems";
CREATE TRIGGER set_catalog_items_updated_at
    BEFORE UPDATE ON "CatalogItems"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS set_quotes_updated_at ON "Quotes";
CREATE TRIGGER set_quotes_updated_at
    BEFORE UPDATE ON "Quotes"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS set_quote_lines_updated_at ON "QuoteLines";
CREATE TRIGGER set_quote_lines_updated_at
    BEFORE UPDATE ON "QuoteLines"
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

-- ====================================================
-- STEP 6: Add comments
-- ====================================================

COMMENT ON TABLE "CatalogItems" IS 'Catalog items for made-to-measure curtain quoting';
COMMENT ON TABLE "Quotes" IS 'Customer quotes for made-to-measure curtains';
COMMENT ON TABLE "QuoteLines" IS 'Individual line items within a quote';

COMMENT ON COLUMN "CatalogItems".measure_basis IS 'How this item is measured: unit, width_linear, height_linear, area, or fabric';
COMMENT ON COLUMN "CatalogItems".fabric_pricing_mode IS 'For fabric items: per_linear_m or per_sqm';
COMMENT ON COLUMN "QuoteLines".computed_qty IS 'Calculated quantity based on measure_basis and dimensions';
COMMENT ON COLUMN "QuoteLines".measure_basis_snapshot IS 'Captured measure_basis from catalog item at quote time';

-- ====================================================
-- STEP 7: Final summary
-- ====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Migration completed successfully!';
    RAISE NOTICE '📋 Created:';
    RAISE NOTICE '   - 3 ENUMs: measure_basis, fabric_pricing_mode, quote_status';
    RAISE NOTICE '   - 3 tables: CatalogItems, Quotes, QuoteLines';
    RAISE NOTICE '   - Indexes and triggers configured';
END $$;

