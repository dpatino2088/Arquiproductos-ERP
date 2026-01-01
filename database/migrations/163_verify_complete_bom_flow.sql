-- ====================================================
-- Migration: Verify Complete BOM Flow
-- ====================================================
-- This script verifies that the BOM system is correctly configured:
-- 1. HardwareColorMapping has entries for colored components
-- 2. BOMComponents have applies_color = true (not hardware_color)
-- 3. MotorTubeCompatibility has entries
-- 4. CassettePartsMapping has entries
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
  v_hardware_color_count integer;
  v_bom_components_count integer;
  v_motor_tube_count integer;
  v_cassette_parts_count integer;
  v_issues text[] := ARRAY[]::text[];
  rec RECORD;
BEGIN
  RAISE NOTICE '🔍 Verifying Complete BOM Flow Configuration...';
  RAISE NOTICE '';

  -- Get organization ID
  SELECT id INTO v_org_id
  FROM "Organizations"
  WHERE deleted = false
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'No active organization found';
  END IF;

  RAISE NOTICE '  📦 Organization ID: %', v_org_id;
  RAISE NOTICE '';

  -- ====================================================
  -- Check 1: HardwareColorMapping
  -- ====================================================
  RAISE NOTICE 'CHECK 1: HardwareColorMapping...';
  
  SELECT COUNT(*) INTO v_hardware_color_count
  FROM "HardwareColorMapping"
  WHERE organization_id = v_org_id
  AND deleted = false;

  RAISE NOTICE '  📊 Total entries: %', v_hardware_color_count;

  IF v_hardware_color_count = 0 THEN
    v_issues := array_append(v_issues, 'HardwareColorMapping has no entries');
    RAISE WARNING '  ⚠️  HardwareColorMapping is empty!';
  ELSE
    RAISE NOTICE '  ✅ HardwareColorMapping has entries';
    
    -- Show color distribution
    RAISE NOTICE '  📊 Color distribution:';
    FOR rec IN (
      SELECT hardware_color, COUNT(*) as count
      FROM "HardwareColorMapping"
      WHERE organization_id = v_org_id
      AND deleted = false
      GROUP BY hardware_color
      ORDER BY hardware_color
    ) LOOP
      RAISE NOTICE '    - %: % entries', rec.hardware_color, rec.count;
    END LOOP;
  END IF;

  RAISE NOTICE '';

  -- ====================================================
  -- Check 2: BOMComponents
  -- ====================================================
  RAISE NOTICE 'CHECK 2: BOMComponents...';
  
  -- Count components with applies_color = true
  SELECT COUNT(*) INTO v_bom_components_count
  FROM "BOMComponents"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND applies_color = true;

  RAISE NOTICE '  📊 Components with applies_color=true: %', v_bom_components_count;

  -- Count components with hardware_color (should be 0)
  DECLARE
    v_components_with_color integer;
  BEGIN
    SELECT COUNT(*) INTO v_components_with_color
    FROM "BOMComponents"
    WHERE organization_id = v_org_id
    AND deleted = false
    AND hardware_color IS NOT NULL;

    IF v_components_with_color > 0 THEN
      v_issues := array_append(v_issues, format('%s BOMComponents still have hardware_color', v_components_with_color));
      RAISE WARNING '  ⚠️  % components still have hardware_color (should be 0)', v_components_with_color;
    ELSE
      RAISE NOTICE '  ✅ No components have hardware_color';
    END IF;
  END;

  IF v_bom_components_count = 0 THEN
    v_issues := array_append(v_issues, 'No BOMComponents have applies_color=true');
    RAISE WARNING '  ⚠️  No components have applies_color=true!';
  ELSE
    RAISE NOTICE '  ✅ Components configured for color mapping';
  END IF;

  RAISE NOTICE '';

  -- ====================================================
  -- Check 3: MotorTubeCompatibility
  -- ====================================================
  RAISE NOTICE 'CHECK 3: MotorTubeCompatibility...';
  
  SELECT COUNT(*) INTO v_motor_tube_count
  FROM "MotorTubeCompatibility"
  WHERE organization_id = v_org_id
  AND deleted = false;

  RAISE NOTICE '  📊 Total entries: %', v_motor_tube_count;

  IF v_motor_tube_count = 0 THEN
    v_issues := array_append(v_issues, 'MotorTubeCompatibility has no entries');
    RAISE WARNING '  ⚠️  MotorTubeCompatibility is empty!';
  ELSE
    RAISE NOTICE '  ✅ MotorTubeCompatibility has entries';
    
    -- Show entries with SKUs
    RAISE NOTICE '  📊 Entries:';
    FOR rec IN (
      SELECT 
        tube_type,
        motor_family,
        (SELECT sku FROM "CatalogItems" WHERE id = required_crown_item_id) as crown_sku,
        (SELECT sku FROM "CatalogItems" WHERE id = required_drive_item_id) as drive_sku
      FROM "MotorTubeCompatibility"
      WHERE organization_id = v_org_id
      AND deleted = false
      ORDER BY motor_family, tube_type
    ) LOOP
      RAISE NOTICE '    - % + %: crown=% | drive=%', 
        rec.tube_type, rec.motor_family, 
        COALESCE(rec.crown_sku, 'NULL'), 
        COALESCE(rec.drive_sku, 'NULL');
    END LOOP;
  END IF;

  RAISE NOTICE '';

  -- ====================================================
  -- Check 4: CassettePartsMapping
  -- ====================================================
  RAISE NOTICE 'CHECK 4: CassettePartsMapping...';
  
  SELECT COUNT(*) INTO v_cassette_parts_count
  FROM "CassettePartsMapping"
  WHERE organization_id = v_org_id
  AND deleted = false;

  RAISE NOTICE '  📊 Total entries: %', v_cassette_parts_count;

  IF v_cassette_parts_count = 0 THEN
    v_issues := array_append(v_issues, 'CassettePartsMapping has no entries');
    RAISE WARNING '  ⚠️  CassettePartsMapping is empty!';
  ELSE
    RAISE NOTICE '  ✅ CassettePartsMapping has entries';
    
    -- Show shape/role distribution
    RAISE NOTICE '  📊 Shape/Role distribution:';
    FOR rec IN (
      SELECT cassette_shape, part_role, COUNT(*) as count
      FROM "CassettePartsMapping"
      WHERE organization_id = v_org_id
      AND deleted = false
      GROUP BY cassette_shape, part_role
      ORDER BY cassette_shape, part_role
    ) LOOP
      RAISE NOTICE '    - % / %: % entries', rec.cassette_shape, rec.part_role, rec.count;
    END LOOP;
  END IF;

  RAISE NOTICE '';

  -- ====================================================
  -- Final Summary
  -- ====================================================
  RAISE NOTICE '═══════════════════════════════════════════════════════════';
  RAISE NOTICE '📊 VERIFICATION SUMMARY';
  RAISE NOTICE '═══════════════════════════════════════════════════════════';
  RAISE NOTICE '';
  RAISE NOTICE '  HardwareColorMapping: % entries', v_hardware_color_count;
  RAISE NOTICE '  BOMComponents (applies_color=true): % components', v_bom_components_count;
  RAISE NOTICE '  MotorTubeCompatibility: % entries', v_motor_tube_count;
  RAISE NOTICE '  CassettePartsMapping: % entries', v_cassette_parts_count;
  RAISE NOTICE '';

  IF array_length(v_issues, 1) > 0 THEN
    RAISE WARNING '⚠️  ISSUES FOUND:';
    FOR i IN 1..array_length(v_issues, 1) LOOP
      RAISE WARNING '  %: %', i, v_issues[i];
    END LOOP;
    RAISE NOTICE '';
    RAISE NOTICE '📝 Please address these issues before using the BOM system.';
  ELSE
    RAISE NOTICE '✅ All checks passed! BOM system is ready to use.';
    RAISE NOTICE '';
    RAISE NOTICE '📝 Next steps:';
    RAISE NOTICE '  1. Test the UI: Select a hardware color in OperatingSystemStep';
    RAISE NOTICE '  2. Generate a quote line with BOM';
    RAISE NOTICE '  3. Verify that all components use the selected color';
  END IF;

END $$;

-- ====================================================
-- Additional Verification Queries
-- ====================================================

-- Check if QuoteLines have hardware_color populated
SELECT 
  'QuoteLines with hardware_color' as check_type,
  COUNT(*) as total_quote_lines,
  COUNT(hardware_color) as lines_with_hardware_color,
  COUNT(DISTINCT hardware_color) as unique_colors
FROM "QuoteLines"
WHERE deleted = false;

-- Show sample QuoteLines with configuration
SELECT 
  'Sample QuoteLines' as check_type,
  ql.id,
  ql.hardware_color,
  ql.drive_type,
  ql.bottom_rail_type,
  ql.cassette,
  ql.side_channel,
  pt.name as product_type,
  ci.sku as catalog_item_sku
FROM "QuoteLines" ql
LEFT JOIN "ProductTypes" pt ON ql.product_type_id = pt.id
LEFT JOIN "CatalogItems" ci ON ql.catalog_item_id = ci.id
WHERE ql.deleted = false
ORDER BY ql.created_at DESC
LIMIT 5;

-- Check QuoteLineComponents generated from BOM
SELECT 
  'QuoteLineComponents from BOM' as check_type,
  qlc.source,
  qlc.component_role,
  COUNT(*) as count,
  (SELECT sku FROM "CatalogItems" WHERE id = qlc.catalog_item_id) as sample_sku
FROM "QuoteLineComponents" qlc
WHERE qlc.deleted = false
AND qlc.source = 'configured_component'
GROUP BY qlc.source, qlc.component_role, qlc.catalog_item_id
ORDER BY qlc.component_role
LIMIT 10;

