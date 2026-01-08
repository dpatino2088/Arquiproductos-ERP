-- ====================================================
-- Migration: Add Fabric Rotation and Heat Seal Fields
-- ====================================================
-- Adds fields to CatalogItems for fabric rotation and heat sealing capabilities
-- ====================================================

DO $$
BEGIN
  RAISE NOTICE '🔧 Adding fabric rotation and heat seal fields to CatalogItems...';
  
  -- Add can_rotate field (boolean) - indicates if fabric can be rotated
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'can_rotate'
  ) THEN
    ALTER TABLE public."CatalogItems"
      ADD COLUMN can_rotate boolean NOT NULL DEFAULT false;
    
    COMMENT ON COLUMN public."CatalogItems".can_rotate IS 
      'Indicates if the fabric can be rotated (used for width/height optimization)';
    
    RAISE NOTICE '  ✅ Added can_rotate column to CatalogItems';
  ELSE
    RAISE NOTICE '  ⏭️  can_rotate column already exists';
  END IF;
  
  -- Add can_heatseal field (boolean) - indicates if fabric can be heat sealed
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'can_heatseal'
  ) THEN
    ALTER TABLE public."CatalogItems"
      ADD COLUMN can_heatseal boolean NOT NULL DEFAULT false;
    
    COMMENT ON COLUMN public."CatalogItems".can_heatseal IS 
      'Indicates if the fabric can be heat sealed (only relevant if can_rotate = true)';
    
    RAISE NOTICE '  ✅ Added can_heatseal column to CatalogItems';
  ELSE
    RAISE NOTICE '  ⏭️  can_heatseal column already exists';
  END IF;
  
  -- Add heatseal_price_per_meter field (numeric) - price per meter for heat sealing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'CatalogItems' 
    AND column_name = 'heatseal_price_per_meter'
  ) THEN
    ALTER TABLE public."CatalogItems"
      ADD COLUMN heatseal_price_per_meter numeric(12, 2);
    
    COMMENT ON COLUMN public."CatalogItems".heatseal_price_per_meter IS 
      'Price per meter for heat sealing (only relevant if can_heatseal = true). Can be overridden by organization settings.';
    
    RAISE NOTICE '  ✅ Added heatseal_price_per_meter column to CatalogItems';
  ELSE
    RAISE NOTICE '  ⏭️  heatseal_price_per_meter column already exists';
  END IF;
  
  -- Add constraint: can_heatseal can only be true if can_rotate is true
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'check_heatseal_requires_rotation'
  ) THEN
    ALTER TABLE public."CatalogItems"
      ADD CONSTRAINT check_heatseal_requires_rotation 
      CHECK (can_heatseal = false OR can_rotate = true);
    
    RAISE NOTICE '  ✅ Added constraint: can_heatseal requires can_rotate';
  ELSE
    RAISE NOTICE '  ⏭️  Constraint check_heatseal_requires_rotation already exists';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ Migration completed successfully!';
  RAISE NOTICE '📋 Added fields:';
  RAISE NOTICE '   - can_rotate (boolean)';
  RAISE NOTICE '   - can_heatseal (boolean)';
  RAISE NOTICE '   - heatseal_price_per_meter (numeric)';
  RAISE NOTICE '';
END $$;











