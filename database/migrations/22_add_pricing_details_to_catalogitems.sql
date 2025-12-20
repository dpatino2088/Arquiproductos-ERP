-- ====================================================
-- Migration: Add Detailed Pricing Fields to CatalogItems
-- ====================================================
-- This migration adds labor costs, shipping costs, and additional costs
-- to CatalogItems for comprehensive pricing management
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '====================================================';
  RAISE NOTICE 'Adding detailed pricing fields to CatalogItems';
  RAISE NOTICE '====================================================';

  -- Add labor cost fields
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'labor_cost_per_unit'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN labor_cost_per_unit numeric(12,2) DEFAULT 0;
    RAISE NOTICE '✅ Added labor_cost_per_unit column';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'labor_cost_per_hour'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN labor_cost_per_hour numeric(12,2) DEFAULT 0;
    RAISE NOTICE '✅ Added labor_cost_per_hour column';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'labor_hours_per_unit'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN labor_hours_per_unit numeric(10,2) DEFAULT 0;
    RAISE NOTICE '✅ Added labor_hours_per_unit column';
  END IF;

  -- Add shipping cost fields
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'shipping_cost_base'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN shipping_cost_base numeric(12,2) DEFAULT 0;
    RAISE NOTICE '✅ Added shipping_cost_base column';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'shipping_cost_per_kg'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN shipping_cost_per_kg numeric(12,2) DEFAULT 0;
    RAISE NOTICE '✅ Added shipping_cost_per_kg column';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'shipping_cost_per_unit'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN shipping_cost_per_unit numeric(12,2) DEFAULT 0;
    RAISE NOTICE '✅ Added shipping_cost_per_unit column';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'shipping_cost_percentage'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN shipping_cost_percentage numeric(5,2) DEFAULT 0;
    RAISE NOTICE '✅ Added shipping_cost_percentage column';
  END IF;

  -- Add additional cost fields
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'import_tax_pct'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN import_tax_pct numeric(5,2) DEFAULT 0;
    RAISE NOTICE '✅ Added import_tax_pct column';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'freight_cost'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN freight_cost numeric(12,2) DEFAULT 0;
    RAISE NOTICE '✅ Added freight_cost column';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'handling_cost'
  ) THEN
    ALTER TABLE public."CatalogItems" 
    ADD COLUMN handling_cost numeric(12,2) DEFAULT 0;
    RAISE NOTICE '✅ Added handling_cost column';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '====================================================';
  RAISE NOTICE '✅ Detailed pricing fields migration completed';
  RAISE NOTICE '====================================================';
END $$;





