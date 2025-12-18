-- ====================================================
-- Migration: Add Customer Discount Fields to CostSettings
-- ====================================================
-- Adds discount percentage fields for each customer type
-- Customer Type -> Discount mapping (v1)
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Adding customer discount fields to CostSettings';
  RAISE NOTICE '====================================================';

  -- Step 1: Add discount_reseller_pct
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'CostSettings' 
      AND column_name = 'discount_reseller_pct'
  ) THEN
    ALTER TABLE "CostSettings"
      ADD COLUMN discount_reseller_pct numeric(5,2) NOT NULL DEFAULT 0.00
      CHECK (discount_reseller_pct >= 0 AND discount_reseller_pct <= 100);
    
    RAISE NOTICE '✅ Added discount_reseller_pct column';
  ELSE
    RAISE NOTICE 'ℹ️  Column discount_reseller_pct already exists';
  END IF;

  -- Step 2: Add discount_distributor_pct
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'CostSettings' 
      AND column_name = 'discount_distributor_pct'
  ) THEN
    ALTER TABLE "CostSettings"
      ADD COLUMN discount_distributor_pct numeric(5,2) NOT NULL DEFAULT 0.00
      CHECK (discount_distributor_pct >= 0 AND discount_distributor_pct <= 100);
    
    RAISE NOTICE '✅ Added discount_distributor_pct column';
  ELSE
    RAISE NOTICE 'ℹ️  Column discount_distributor_pct already exists';
  END IF;

  -- Step 3: Add discount_partner_pct
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'CostSettings' 
      AND column_name = 'discount_partner_pct'
  ) THEN
    ALTER TABLE "CostSettings"
      ADD COLUMN discount_partner_pct numeric(5,2) NOT NULL DEFAULT 0.00
      CHECK (discount_partner_pct >= 0 AND discount_partner_pct <= 100);
    
    RAISE NOTICE '✅ Added discount_partner_pct column';
  ELSE
    RAISE NOTICE 'ℹ️  Column discount_partner_pct already exists';
  END IF;

  -- Step 4: Add discount_vip_pct
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
      AND table_name = 'CostSettings' 
      AND column_name = 'discount_vip_pct'
  ) THEN
    ALTER TABLE "CostSettings"
      ADD COLUMN discount_vip_pct numeric(5,2) NOT NULL DEFAULT 0.00
      CHECK (discount_vip_pct >= 0 AND discount_vip_pct <= 100);
    
    RAISE NOTICE '✅ Added discount_vip_pct column';
  ELSE
    RAISE NOTICE 'ℹ️  Column discount_vip_pct already exists';
  END IF;

  -- Step 5: Update existing records to have default 0 values (if they were NULL)
  UPDATE "CostSettings"
  SET 
    discount_reseller_pct = COALESCE(discount_reseller_pct, 0),
    discount_distributor_pct = COALESCE(discount_distributor_pct, 0),
    discount_partner_pct = COALESCE(discount_partner_pct, 0),
    discount_vip_pct = COALESCE(discount_vip_pct, 0)
  WHERE discount_reseller_pct IS NULL 
     OR discount_distributor_pct IS NULL 
     OR discount_partner_pct IS NULL 
     OR discount_vip_pct IS NULL;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Migration complete';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '';
END $$;

