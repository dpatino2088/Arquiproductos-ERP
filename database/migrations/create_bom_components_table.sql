-- ====================================================
-- Migration: Create BOMComponents table
-- ====================================================
-- This migration creates a table to store Bill of Materials (BOM) relationships
-- between CatalogItems. This allows products to be composed of other catalog items.
-- ====================================================

-- Enable pgcrypto extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ====================================================
-- STEP 1: Create BOMComponents table
-- ====================================================

CREATE TABLE IF NOT EXISTS "BOMComponents" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    
    -- Parent item (the product that uses this component)
    parent_item_id uuid NOT NULL REFERENCES "CatalogItems"(id) ON DELETE CASCADE,
    
    -- Component item (the part/material used in the parent)
    component_item_id uuid NOT NULL REFERENCES "CatalogItems"(id) ON DELETE CASCADE,
    
    -- Quantity of component needed per unit of parent
    qty_per_unit numeric(10, 4) NOT NULL DEFAULT 1,
    
    -- Unit of measure for the quantity
    uom text NOT NULL DEFAULT 'unit',
    
    -- Whether this component is required or optional
    is_required boolean NOT NULL DEFAULT true,
    
    -- Order/sequence for display and processing
    sequence_order integer NOT NULL DEFAULT 0,
    
    -- Additional configuration and rules (e.g., conditional logic)
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid,
    
    -- Prevent duplicate component entries for same parent
    CONSTRAINT bom_components_parent_component_unique 
        UNIQUE (parent_item_id, component_item_id, organization_id)
);

-- Create partial unique index for non-deleted items
CREATE UNIQUE INDEX IF NOT EXISTS idx_bom_components_parent_component_unique 
    ON "BOMComponents"(parent_item_id, component_item_id, organization_id) 
    WHERE deleted = false;

-- ====================================================
-- STEP 2: Create indexes for performance
-- ====================================================

-- Index for querying components by parent item
CREATE INDEX IF NOT EXISTS idx_bom_components_parent_item 
    ON "BOMComponents"(parent_item_id, deleted) 
    WHERE deleted = false;

-- Index for querying where a component is used
CREATE INDEX IF NOT EXISTS idx_bom_components_component_item 
    ON "BOMComponents"(component_item_id, deleted) 
    WHERE deleted = false;

-- Index for organization filtering
CREATE INDEX IF NOT EXISTS idx_bom_components_organization 
    ON "BOMComponents"(organization_id, deleted) 
    WHERE deleted = false;

-- Index for sequence ordering
CREATE INDEX IF NOT EXISTS idx_bom_components_sequence 
    ON "BOMComponents"(parent_item_id, sequence_order, deleted) 
    WHERE deleted = false;

-- ====================================================
-- STEP 3: Add comments for documentation
-- ====================================================

COMMENT ON TABLE "BOMComponents" IS 'Stores Bill of Materials relationships between CatalogItems. Defines which components are needed to build a product.';
COMMENT ON COLUMN "BOMComponents".parent_item_id IS 'The product that uses this component';
COMMENT ON COLUMN "BOMComponents".component_item_id IS 'The component/material used in the parent product';
COMMENT ON COLUMN "BOMComponents".qty_per_unit IS 'Quantity of component needed per unit of parent product';
COMMENT ON COLUMN "BOMComponents".uom IS 'Unit of measure for the quantity (e.g., unit, m, sqm)';
COMMENT ON COLUMN "BOMComponents".is_required IS 'Whether this component is required (true) or optional (false)';
COMMENT ON COLUMN "BOMComponents".sequence_order IS 'Display and processing order for components';
COMMENT ON COLUMN "BOMComponents".metadata IS 'Additional configuration: conditional rules, calculation formulas, etc.';

-- ====================================================
-- STEP 4: Add trigger to update updated_at timestamp
-- ====================================================

CREATE OR REPLACE FUNCTION update_bom_components_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_bom_components_updated_at
    BEFORE UPDATE ON "BOMComponents"
    FOR EACH ROW
    EXECUTE FUNCTION update_bom_components_updated_at();

-- ====================================================
-- Verification
-- ====================================================
-- Run these queries to verify the table was created correctly:
-- 
-- SELECT table_name, column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'BOMComponents'
-- ORDER BY ordinal_position;
-- 
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE tablename = 'BOMComponents';

