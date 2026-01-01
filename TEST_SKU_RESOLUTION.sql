-- ====================================================
-- TEST: SKU Resolution Logic
-- ====================================================
-- This script tests if the SKU resolution logic would find the SKUs
-- ====================================================

DO $$
DECLARE
  v_organization_id uuid;
  v_rca_04_id uuid;
  v_rca_21_id uuid;
  v_rc3101_id uuid;
  v_rc3102_id uuid;
  v_rcas_09_75_id uuid;
  v_rc3104_id uuid;
  v_resolved_sku text;
BEGIN
  -- Get Organization ID
  SELECT id INTO v_organization_id
  FROM "Organizations"
  WHERE deleted = false
  ORDER BY created_at ASC
  LIMIT 1;
  
  IF v_organization_id IS NULL THEN
    RAISE EXCEPTION 'No active organization found';
  END IF;
  
  RAISE NOTICE 'Testing SKU Resolution for Organization: %', v_organization_id;
  RAISE NOTICE '';
  
  -- Test RCA-04
  SELECT id INTO v_rca_04_id FROM "CatalogItems" 
  WHERE (sku = 'RCA-04' OR sku ILIKE 'RCA-04-%' OR sku ILIKE 'RCA04%')
    AND organization_id = v_organization_id 
    AND deleted = false
  ORDER BY 
    CASE 
      WHEN sku = 'RCA-04' THEN 1
      WHEN sku ILIKE 'RCA-04-W%' OR sku ILIKE '%W%' THEN 2
      WHEN sku ILIKE 'RCA-04-A%' OR sku ILIKE '%A%' THEN 3
      ELSE 4
    END
  LIMIT 1;
  
  IF v_rca_04_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_rca_04_id;
    RAISE NOTICE '✅ RCA-04: FOUND - SKU: % (ID: %)', v_resolved_sku, v_rca_04_id;
  ELSE
    RAISE WARNING '❌ RCA-04: NOT FOUND';
  END IF;
  
  -- Test RCA-21
  SELECT id INTO v_rca_21_id FROM "CatalogItems" 
  WHERE (sku = 'RCA-21' OR sku ILIKE 'RCA-21-%' OR sku ILIKE 'RCA21%')
    AND organization_id = v_organization_id 
    AND deleted = false
  ORDER BY 
    CASE 
      WHEN sku = 'RCA-21' THEN 1
      WHEN sku ILIKE 'RCA-21-W%' OR sku ILIKE '%W%' THEN 2
      WHEN sku ILIKE 'RCA-21-A%' OR sku ILIKE '%A%' THEN 3
      ELSE 4
    END
  LIMIT 1;
  
  IF v_rca_21_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_rca_21_id;
    RAISE NOTICE '✅ RCA-21: FOUND - SKU: % (ID: %)', v_resolved_sku, v_rca_21_id;
  ELSE
    RAISE WARNING '❌ RCA-21: NOT FOUND';
  END IF;
  
  -- Test RC3101
  SELECT id INTO v_rc3101_id FROM "CatalogItems" 
  WHERE (sku = 'RC3101' OR sku ILIKE 'RC3101-%' OR sku ILIKE '%RC3101%')
    AND organization_id = v_organization_id 
    AND deleted = false
  ORDER BY 
    CASE 
      WHEN sku = 'RC3101' THEN 1
      WHEN sku ILIKE 'RC3101-W%' OR sku ILIKE '%W%' THEN 2
      WHEN sku ILIKE 'RC3101-A%' OR sku ILIKE '%A%' THEN 3
      ELSE 4
    END
  LIMIT 1;
  
  IF v_rc3101_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_rc3101_id;
    RAISE NOTICE '✅ RC3101: FOUND - SKU: % (ID: %)', v_resolved_sku, v_rc3101_id;
  ELSE
    RAISE WARNING '❌ RC3101: NOT FOUND';
  END IF;
  
  -- Test RC3102
  SELECT id INTO v_rc3102_id FROM "CatalogItems" 
  WHERE (sku = 'RC3102' OR sku ILIKE 'RC3102-%' OR sku ILIKE '%RC3102%')
    AND organization_id = v_organization_id 
    AND deleted = false
  ORDER BY 
    CASE 
      WHEN sku = 'RC3102' THEN 1
      WHEN sku ILIKE 'RC3102-W%' OR sku ILIKE '%W%' THEN 2
      WHEN sku ILIKE 'RC3102-A%' OR sku ILIKE '%A%' THEN 3
      ELSE 4
    END
  LIMIT 1;
  
  IF v_rc3102_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_rc3102_id;
    RAISE NOTICE '✅ RC3102: FOUND - SKU: % (ID: %)', v_resolved_sku, v_rc3102_id;
  ELSE
    RAISE WARNING '❌ RC3102: NOT FOUND';
  END IF;
  
  -- Test RCAS-09-75
  SELECT id INTO v_rcas_09_75_id FROM "CatalogItems" 
  WHERE (sku = 'RCAS-09-75' OR sku ILIKE 'RCAS-09-75%' OR sku ILIKE 'RCAS0975%')
    AND organization_id = v_organization_id 
    AND deleted = false
  ORDER BY sku
  LIMIT 1;
  
  IF v_rcas_09_75_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_rcas_09_75_id;
    RAISE NOTICE '✅ RCAS-09-75: FOUND - SKU: % (ID: %)', v_resolved_sku, v_rcas_09_75_id;
  ELSE
    RAISE WARNING '❌ RCAS-09-75: NOT FOUND';
  END IF;
  
  -- Test RC3104
  SELECT id INTO v_rc3104_id FROM "CatalogItems" 
  WHERE (sku = 'RC3104' OR sku ILIKE 'RC3104-%' OR sku ILIKE '%RC3104%')
    AND organization_id = v_organization_id 
    AND deleted = false
  ORDER BY 
    CASE 
      WHEN sku = 'RC3104' THEN 1
      WHEN sku ILIKE 'RC3104-W%' OR sku ILIKE '%W%' THEN 2
      WHEN sku ILIKE 'RC3104-A%' OR sku ILIKE '%A%' THEN 3
      ELSE 4
    END
  LIMIT 1;
  
  IF v_rc3104_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_rc3104_id;
    RAISE NOTICE '✅ RC3104: FOUND - SKU: % (ID: %)', v_resolved_sku, v_rc3104_id;
  ELSE
    RAISE WARNING '❌ RC3104: NOT FOUND';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Test completed. If all SKUs are found,';
  RAISE NOTICE 're-run REBUILD_BOM_MODULE_COMPLETE.sql';
  RAISE NOTICE '========================================';
  
END $$;








