-- ====================================================
-- Migration: Verify Enhanced BOM Architecture
-- ====================================================
-- This script verifies that all tables, indexes, and seed data
-- from migration 146 were created successfully
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
  v_products_count integer;
  v_options_count integer;
  v_values_count integer;
  rec RECORD;
BEGIN
  RAISE NOTICE '🔍 Verifying Enhanced BOM Architecture...';
  RAISE NOTICE '';

  -- Get first active organization
  SELECT id INTO v_org_id
  FROM "Organizations"
  WHERE deleted = false
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE WARNING '  ⚠️  No active organization found';
    RETURN;
  END IF;

  RAISE NOTICE '  📊 Organization ID: %', v_org_id;
  RAISE NOTICE '';

  -- Check Products
  SELECT COUNT(*) INTO v_products_count
  FROM "Products"
  WHERE organization_id = v_org_id
  AND deleted = false;

  RAISE NOTICE '  ✅ Products: % record(s)', v_products_count;

  -- Check ProductOptions
  SELECT COUNT(*) INTO v_options_count
  FROM "ProductOptions"
  WHERE organization_id = v_org_id
  AND deleted = false;

  RAISE NOTICE '  ✅ ProductOptions: % record(s)', v_options_count;

  -- Check ProductOptionValues
  SELECT COUNT(*) INTO v_values_count
  FROM "ProductOptionValues" pov
  JOIN "ProductOptions" po ON pov.option_id = po.id
  WHERE po.organization_id = v_org_id
  AND pov.deleted = false;

  RAISE NOTICE '  ✅ ProductOptionValues: % record(s)', v_values_count;

  -- List ProductOptions
  RAISE NOTICE '';
  RAISE NOTICE '  📋 ProductOptions created:';
  FOR rec IN (
    SELECT option_code, name, input_type, 
           (SELECT COUNT(*) FROM "ProductOptionValues" WHERE option_id = po.id AND deleted = false) as value_count
    FROM "ProductOptions" po
    WHERE organization_id = v_org_id
    AND deleted = false
    ORDER BY sort_order
  ) LOOP
    RAISE NOTICE '    - % (%) [%] - % values', rec.option_code, rec.name, rec.input_type, rec.value_count;
  END LOOP;

  -- Check indexes
  RAISE NOTICE '';
  RAISE NOTICE '  🔍 Checking unique indexes...';
  
  IF EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'uq_products_org_code'
  ) THEN
    RAISE NOTICE '    ✅ uq_products_org_code exists';
  ELSE
    RAISE WARNING '    ⚠️  uq_products_org_code missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'uq_product_options_org_code'
  ) THEN
    RAISE NOTICE '    ✅ uq_product_options_org_code exists';
  ELSE
    RAISE WARNING '    ⚠️  uq_product_options_org_code missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_indexes 
    WHERE indexname = 'uq_product_option_values_code'
  ) THEN
    RAISE NOTICE '    ✅ uq_product_option_values_code exists';
  ELSE
    RAISE WARNING '    ⚠️  uq_product_option_values_code missing';
  END IF;

  -- Check tables exist
  RAISE NOTICE '';
  RAISE NOTICE '  🔍 Checking tables...';
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'Products') THEN
    RAISE NOTICE '    ✅ Products table exists';
  ELSE
    RAISE WARNING '    ⚠️  Products table missing';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'ConfiguredProducts') THEN
    RAISE NOTICE '    ✅ ConfiguredProducts table exists';
  ELSE
    RAISE WARNING '    ⚠️  ConfiguredProducts table missing';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'MotorTubeCompatibility') THEN
    RAISE NOTICE '    ✅ MotorTubeCompatibility table exists';
  ELSE
    RAISE WARNING '    ⚠️  MotorTubeCompatibility table missing';
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'BomInstances') THEN
    RAISE NOTICE '    ✅ BomInstances table exists';
  ELSE
    RAISE WARNING '    ⚠️  BomInstances table missing';
  END IF;

  -- Check BOMComponents new columns
  RAISE NOTICE '';
  RAISE NOTICE '  🔍 Checking BOMComponents extensions...';
  
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'BOMComponents' 
    AND column_name = 'qty_type'
  ) THEN
    RAISE NOTICE '    ✅ qty_type column exists';
  ELSE
    RAISE WARNING '    ⚠️  qty_type column missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'BOMComponents' 
    AND column_name = 'qty_value'
  ) THEN
    RAISE NOTICE '    ✅ qty_value column exists';
  ELSE
    RAISE WARNING '    ⚠️  qty_value column missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'BOMComponents' 
    AND column_name = 'select_rule'
  ) THEN
    RAISE NOTICE '    ✅ select_rule column exists';
  ELSE
    RAISE WARNING '    ⚠️  select_rule column missing';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Verification completed!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Next steps:';
  RAISE NOTICE '   1. Populate CatalogItems with your actual SKUs';
  RAISE NOTICE '   2. Create HardwareColorMapping entries';
  RAISE NOTICE '   3. Create MotorTubeCompatibility entries';
  RAISE NOTICE '   4. Create CassettePartsMapping entries';
  RAISE NOTICE '   5. Update BOMComponents with qty_type, qty_value, select_rule';

END $$;

