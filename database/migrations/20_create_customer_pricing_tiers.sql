-- ====================================================
-- Migration: Create Customer Pricing Tiers Table
-- ====================================================
-- This migration creates a table to manage customer pricing tiers
-- Each tier has a discount percentage that applies to MSRP
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Creating CustomerPricingTiers table';
  RAISE NOTICE '====================================================';

  -- Create CustomerPricingTiers table if it doesn't exist
  CREATE TABLE IF NOT EXISTS public."CustomerPricingTiers" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL,
    tier_name text NOT NULL,
    tier_code text NOT NULL,
    discount_pct numeric(5,2) NOT NULL DEFAULT 0.00 CHECK (discount_pct >= 0 AND discount_pct <= 100),
    description text,
    sort_order integer DEFAULT 0,
    active boolean DEFAULT true,
    deleted boolean DEFAULT false,
    archived boolean DEFAULT false,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    CONSTRAINT uq_customer_pricing_tiers_org_code UNIQUE (organization_id, tier_code)
  );

  RAISE NOTICE '✅ Created CustomerPricingTiers table';

  -- Add tier_id to DirectoryCustomers if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'DirectoryCustomers' 
    AND column_name = 'pricing_tier_id'
  ) THEN
    ALTER TABLE public."DirectoryCustomers" 
    ADD COLUMN pricing_tier_id uuid REFERENCES public."CustomerPricingTiers"(id);
    
    RAISE NOTICE '✅ Added pricing_tier_id to DirectoryCustomers';
  ELSE
    RAISE NOTICE 'ℹ️  Column pricing_tier_id already exists in DirectoryCustomers';
  END IF;

  -- Create indexes
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' 
    AND tablename = 'CustomerPricingTiers' 
    AND indexname = 'idx_customer_pricing_tiers_org'
  ) THEN
    CREATE INDEX idx_customer_pricing_tiers_org ON public."CustomerPricingTiers"(organization_id) 
    WHERE deleted = false;
    
    RAISE NOTICE '✅ Created index on organization_id';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE schemaname = 'public' 
    AND tablename = 'DirectoryCustomers' 
    AND indexname = 'idx_directory_customers_pricing_tier'
  ) THEN
    CREATE INDEX idx_directory_customers_pricing_tier ON public."DirectoryCustomers"(pricing_tier_id) 
    WHERE pricing_tier_id IS NOT NULL;
    
    RAISE NOTICE '✅ Created index on pricing_tier_id in DirectoryCustomers';
  END IF;

  -- Insert default pricing tiers for the organization
  DO $$
  DECLARE
    target_org_id uuid := '4de856e8-36ce-480a-952b-a2f5083c69d6';
    tier_count integer;
  BEGIN
    SELECT COUNT(*) INTO tier_count
    FROM public."CustomerPricingTiers"
    WHERE organization_id = target_org_id;

    IF tier_count = 0 THEN
      -- Insert default tiers
      INSERT INTO public."CustomerPricingTiers" (
        organization_id, tier_name, tier_code, discount_pct, description, sort_order
      ) VALUES
        (target_org_id, 'Retail', 'RETAIL', 0.00, 'Retail price - no discount', 1),
        (target_org_id, 'Standard', 'STANDARD', 10.00, 'Standard customer discount', 2),
        (target_org_id, 'Preferred', 'PREFERRED', 15.00, 'Preferred customer discount', 3),
        (target_org_id, 'VIP', 'VIP', 20.00, 'VIP customer discount', 4),
        (target_org_id, 'Wholesale', 'WHOLESALE', 25.00, 'Wholesale customer discount', 5);

      RAISE NOTICE '✅ Inserted default pricing tiers';
    ELSE
      RAISE NOTICE 'ℹ️  Pricing tiers already exist for organization';
    END IF;
  END $$;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Customer pricing tiers migration completed';
  RAISE NOTICE '====================================================';
END $$;













