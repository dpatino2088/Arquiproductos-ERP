-- ====================================================
-- Migration: Add Organization Heat Seal Settings
-- ====================================================
-- Creates table to store organization-specific heat seal pricing
-- Allows organizations to override default heat seal prices
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '🔧 Creating OrganizationHeatSealSettings table...';
  
  -- Create table for organization heat seal settings
  CREATE TABLE IF NOT EXISTS public."OrganizationHeatSealSettings" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    
    -- Default heat seal price per meter (can override CatalogItems.heatseal_price_per_meter)
    default_heatseal_price_per_meter numeric(12, 2) NOT NULL DEFAULT 10.00,
    
    -- Audit fields
    deleted boolean NOT NULL DEFAULT false,
    archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    created_by uuid,
    updated_by uuid,
    
    -- Constraints
    CONSTRAINT check_positive_heatseal_price 
      CHECK (default_heatseal_price_per_meter >= 0)
  );
  
  -- Create unique index for one setting per organization (active only)
  CREATE UNIQUE INDEX IF NOT EXISTS uq_org_heatseal_settings_org 
    ON public."OrganizationHeatSealSettings"(organization_id) 
    WHERE deleted = false;
  
  -- Create index for organization lookups
  CREATE INDEX IF NOT EXISTS idx_org_heatseal_settings_org 
    ON public."OrganizationHeatSealSettings"(organization_id) 
    WHERE deleted = false;
  
  COMMENT ON TABLE public."OrganizationHeatSealSettings" IS 
    'Organization-specific settings for heat seal pricing. Allows organizations to override default prices from CatalogItems.';
  
  COMMENT ON COLUMN public."OrganizationHeatSealSettings".default_heatseal_price_per_meter IS 
    'Default price per meter for heat sealing. Used when CatalogItems.heatseal_price_per_meter is NULL or when organization wants to override.';
  
  RAISE NOTICE '  ✅ Created OrganizationHeatSealSettings table';
  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration completed successfully!';
  RAISE NOTICE '';
END $$;









