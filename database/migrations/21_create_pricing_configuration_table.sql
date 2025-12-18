-- ====================================================
-- Migration: Create Pricing Configuration Table
-- ====================================================
-- This migration creates a comprehensive pricing table
-- that includes margins, discounts, labor costs, and shipping costs
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Creating PricingConfiguration table';
  RAISE NOTICE '====================================================';

  -- Create PricingConfiguration table
  CREATE TABLE IF NOT EXISTS public."PricingConfiguration" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES "Organizations"(id) ON DELETE CASCADE,
    
    -- Item reference (can be null for global/default config)
    catalog_item_id uuid REFERENCES "CatalogItems"(id) ON DELETE CASCADE,
    item_category_id uuid REFERENCES "ItemCategories"(id) ON DELETE SET NULL,
    
    -- Base pricing
    cost_exw numeric(12,2) NOT NULL DEFAULT 0, -- Base cost (Ex Works)
    default_margin_pct numeric(5,2) NOT NULL DEFAULT 35.00, -- Default margin percentage
    msrp numeric(12,2), -- Manufacturer's Suggested Retail Price (calculated)
    
    -- Labor costs
    labor_cost_per_unit numeric(12,2) DEFAULT 0, -- Costo de mano de obra por unidad
    labor_cost_per_hour numeric(12,2) DEFAULT 0, -- Costo de mano de obra por hora
    labor_hours_per_unit numeric(10,2) DEFAULT 0, -- Horas de mano de obra por unidad
    
    -- Shipping costs
    shipping_cost_base numeric(12,2) DEFAULT 0, -- Costo base de envío
    shipping_cost_per_kg numeric(12,2) DEFAULT 0, -- Costo de envío por kilogramo
    shipping_cost_per_unit numeric(12,2) DEFAULT 0, -- Costo de envío por unidad
    shipping_cost_percentage numeric(5,2) DEFAULT 0, -- Porcentaje del costo total para envío
    
    -- Additional costs
    import_tax_pct numeric(5,2) DEFAULT 0, -- Porcentaje de impuesto de importación
    freight_cost numeric(12,2) DEFAULT 0, -- Costo de flete estimado
    handling_cost numeric(12,2) DEFAULT 0, -- Costo de manejo
    
    -- Discount tiers (reference to CustomerPricingTiers)
    -- These are applied on top of MSRP
    tier_retail_discount_pct numeric(5,2) DEFAULT 0,
    tier_standard_discount_pct numeric(5,2) DEFAULT 10.00,
    tier_preferred_discount_pct numeric(5,2) DEFAULT 15.00,
    tier_vip_discount_pct numeric(5,2) DEFAULT 20.00,
    tier_wholesale_discount_pct numeric(5,2) DEFAULT 25.00,
    
    -- Metadata
    notes text,
    effective_from date,
    effective_to date,
    active boolean DEFAULT true,
    deleted boolean DEFAULT false,
    archived boolean DEFAULT false,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    
    -- Constraints
    CONSTRAINT chk_margin CHECK (default_margin_pct >= 0 AND default_margin_pct <= 100),
    CONSTRAINT chk_discounts CHECK (
      tier_retail_discount_pct >= 0 AND tier_retail_discount_pct <= 100 AND
      tier_standard_discount_pct >= 0 AND tier_standard_discount_pct <= 100 AND
      tier_preferred_discount_pct >= 0 AND tier_preferred_discount_pct <= 100 AND
      tier_vip_discount_pct >= 0 AND tier_vip_discount_pct <= 100 AND
      tier_wholesale_discount_pct >= 0 AND tier_wholesale_discount_pct <= 100
    )
  );

  RAISE NOTICE '✅ Created PricingConfiguration table';

  -- Create indexes
  CREATE INDEX IF NOT EXISTS idx_pricing_config_org 
    ON public."PricingConfiguration"(organization_id) 
    WHERE deleted = false AND active = true;
  
  CREATE INDEX IF NOT EXISTS idx_pricing_config_item 
    ON public."PricingConfiguration"(catalog_item_id) 
    WHERE catalog_item_id IS NOT NULL AND deleted = false;
  
  CREATE INDEX IF NOT EXISTS idx_pricing_config_category 
    ON public."PricingConfiguration"(item_category_id) 
    WHERE item_category_id IS NOT NULL AND deleted = false;
  
  CREATE INDEX IF NOT EXISTS idx_pricing_config_dates 
    ON public."PricingConfiguration"(effective_from, effective_to) 
    WHERE deleted = false AND active = true;

  RAISE NOTICE '✅ Created indexes on PricingConfiguration';

  -- Add trigger to calculate MSRP automatically
  CREATE OR REPLACE FUNCTION calculate_pricing_msrp()
  RETURNS TRIGGER AS $$
  BEGIN
    -- Calculate MSRP: cost_exw * (1 + margin/100) + labor + shipping
    IF NEW.cost_exw IS NOT NULL AND NEW.default_margin_pct IS NOT NULL THEN
      NEW.msrp := ROUND(
        (NEW.cost_exw + 
         COALESCE(NEW.labor_cost_per_unit, 0) + 
         COALESCE(NEW.shipping_cost_base, 0) +
         COALESCE(NEW.freight_cost, 0) +
         COALESCE(NEW.handling_cost, 0)
        ) * (1 + NEW.default_margin_pct / 100),
        2
      );
    END IF;
    
    NEW.updated_at := now();
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;

  DROP TRIGGER IF EXISTS trigger_calculate_pricing_msrp ON public."PricingConfiguration";
  CREATE TRIGGER trigger_calculate_pricing_msrp
    BEFORE INSERT OR UPDATE ON public."PricingConfiguration"
    FOR EACH ROW
    EXECUTE FUNCTION calculate_pricing_msrp();

  RAISE NOTICE '✅ Created trigger to auto-calculate MSRP';

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Pricing configuration migration completed';
  RAISE NOTICE '====================================================';
END $$;

