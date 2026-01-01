-- ====================================================
-- Migration 267: Create BomRoleSkuMapping Table
-- ====================================================
-- Deterministic mapping table: role -> CatalogItem SKU
-- Replaces fuzzy name searches with explicit mappings
-- ====================================================

BEGIN;

-- ====================================================
-- STEP 1: Create BomRoleSkuMapping table
-- ====================================================

CREATE TABLE IF NOT EXISTS public."BomRoleSkuMapping" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Organization (optional - null means global mapping)
    organization_id uuid REFERENCES "Organizations"(id) ON DELETE CASCADE,
    
    -- Product type context
    product_type_id uuid NOT NULL REFERENCES "ProductTypes"(id) ON DELETE CASCADE,
    
    -- Component role (canonical role name)
    component_role text NOT NULL,
    
    -- Configuration fields (nullable - NULL means wildcard)
    operating_system_variant text NULL,  -- e.g. 'standard_m', 'standard_l'
    tube_type text NULL,                 -- e.g. 'RTU-42', 'RTU-50', 'RTU-65', 'RTU-80'
    bottom_rail_type text NULL,          -- e.g. 'standard', 'wrapped'
    side_channel_type text NULL,         -- e.g. 'side_only', 'side_and_bottom'
    hardware_color text NULL,           -- e.g. 'white', 'black', 'silver', 'bronze'
    
    -- Mapped CatalogItem
    catalog_item_id uuid NOT NULL REFERENCES "CatalogItems"(id) ON DELETE RESTRICT,
    
    -- Priority (lower number = higher priority)
    priority integer NOT NULL DEFAULT 100,
    
    -- Status
    active boolean NOT NULL DEFAULT true,
    deleted boolean NOT NULL DEFAULT false,
    
    -- Audit
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- ====================================================
-- STEP 2: Create indexes
-- ====================================================

-- Index for fast lookup by product_type and role
CREATE INDEX IF NOT EXISTS idx_bom_role_sku_mapping_product_role 
    ON public."BomRoleSkuMapping"(product_type_id, component_role)
    WHERE deleted = false AND active = true;

-- Index for full configuration lookup
CREATE INDEX IF NOT EXISTS idx_bom_role_sku_mapping_full_config 
    ON public."BomRoleSkuMapping"(product_type_id, component_role, operating_system_variant, tube_type, hardware_color, side_channel_type)
    WHERE deleted = false AND active = true;

-- Index for catalog_item_id lookups
CREATE INDEX IF NOT EXISTS idx_bom_role_sku_mapping_catalog_item 
    ON public."BomRoleSkuMapping"(catalog_item_id)
    WHERE deleted = false AND active = true;

-- Index for organization-specific lookups
CREATE INDEX IF NOT EXISTS idx_bom_role_sku_mapping_org 
    ON public."BomRoleSkuMapping"(organization_id, product_type_id, component_role)
    WHERE deleted = false AND active = true AND organization_id IS NOT NULL;

-- ====================================================
-- STEP 3: Create unique constraint (prevent duplicates)
-- ====================================================

-- Partial unique constraint to prevent duplicates of same specificity
CREATE UNIQUE INDEX IF NOT EXISTS uq_bom_role_sku_mapping_specificity
    ON public."BomRoleSkuMapping" (
        COALESCE(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
        product_type_id,
        component_role,
        COALESCE(operating_system_variant, ''),
        COALESCE(tube_type, ''),
        COALESCE(bottom_rail_type, ''),
        COALESCE(side_channel_type, ''),
        COALESCE(hardware_color, ''),
        catalog_item_id
    )
    WHERE deleted = false AND active = true;

-- ====================================================
-- STEP 4: Add updated_at trigger
-- ====================================================

CREATE OR REPLACE FUNCTION set_bom_role_sku_mapping_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_bom_role_sku_mapping_updated_at ON public."BomRoleSkuMapping";
CREATE TRIGGER set_bom_role_sku_mapping_updated_at
    BEFORE UPDATE ON public."BomRoleSkuMapping"
    FOR EACH ROW
    EXECUTE FUNCTION set_bom_role_sku_mapping_updated_at();

-- ====================================================
-- STEP 5: Add comments
-- ====================================================

COMMENT ON TABLE public."BomRoleSkuMapping" IS 
    'Deterministic mapping from BOM roles to CatalogItem SKUs based on configuration fields. Replaces fuzzy name searches with explicit mappings. NULL values in configuration fields act as wildcards.';

COMMENT ON COLUMN public."BomRoleSkuMapping".organization_id IS 
    'Optional organization-specific mapping. NULL means global mapping available to all organizations.';

COMMENT ON COLUMN public."BomRoleSkuMapping".component_role IS 
    'Canonical BOM role name (e.g. tube, bracket, fabric, motor, motor_adapter, operating_system_drive, etc.)';

COMMENT ON COLUMN public."BomRoleSkuMapping".priority IS 
    'Lower number = higher priority when multiple mappings match. Default is 100.';

COMMIT;


