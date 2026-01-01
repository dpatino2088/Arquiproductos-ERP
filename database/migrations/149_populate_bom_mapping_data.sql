-- ====================================================
-- Migration: Populate BOM Mapping Data
-- ====================================================
-- This script helps populate:
-- 1) HardwareColorMapping (brackets, cassette parts, bottom bar by color)
-- 2) MotorTubeCompatibility (motor/tube combinations)
-- 3) CassettePartsMapping (cassette shape to parts)
-- 
-- IMPORTANT: You need to have your SKUs in CatalogItems first!
-- This script uses placeholder SKU lookups - replace with your actual SKUs
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
  v_bracket_base_id uuid;
  v_bracket_white_id uuid;
  v_bracket_black_id uuid;
  v_cassette_profile_round_id uuid;
  v_cassette_profile_square_id uuid;
  v_cassette_profile_l_id uuid;
  v_bottom_rail_base_id uuid;
  v_bottom_rail_white_id uuid;
  v_bottom_rail_black_id uuid;
BEGIN
  RAISE NOTICE '🔧 Populating BOM Mapping Data...';
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
  -- STEP 1: Find SKU IDs (you'll need to adjust these)
  -- ====================================================
  RAISE NOTICE 'STEP 1: Looking up SKU IDs...';

  -- Brackets (example: RC4004 base, RC4004-WH white, RC4004-BK black)
  SELECT id INTO v_bracket_base_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND sku = 'RC4004'
  AND deleted = false
  LIMIT 1;

  SELECT id INTO v_bracket_white_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND (sku = 'RC4004-WH' OR sku = 'RC4004-W' OR sku LIKE 'RC4004%WH%')
  AND deleted = false
  LIMIT 1;

  SELECT id INTO v_bracket_black_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND (sku = 'RC4004-BK' OR sku = 'RC4004-B' OR sku LIKE 'RC4004%BK%')
  AND deleted = false
  LIMIT 1;

  -- Bottom Rail (example: RCA-04 base, variants by color)
  SELECT id INTO v_bottom_rail_base_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND (sku = 'RCA-04' OR sku LIKE 'RCA-04%')
  AND deleted = false
  LIMIT 1;

  SELECT id INTO v_bottom_rail_white_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND (sku LIKE 'RCA-04%WH%' OR sku LIKE 'RCA-04%W%')
  AND deleted = false
  LIMIT 1;

  SELECT id INTO v_bottom_rail_black_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND (sku LIKE 'RCA-04%BK%' OR sku LIKE 'RCA-04%B%')
  AND deleted = false
  LIMIT 1;

  -- Cassette profiles (you'll need to find these)
  SELECT id INTO v_cassette_profile_round_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND (sku LIKE '%CASSETTE%ROUND%' OR sku LIKE '%CASS%R%' OR item_name ILIKE '%cassette%round%')
  AND deleted = false
  LIMIT 1;

  SELECT id INTO v_cassette_profile_square_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND (sku LIKE '%CASSETTE%SQUARE%' OR sku LIKE '%CASS%SQ%' OR item_name ILIKE '%cassette%square%')
  AND deleted = false
  LIMIT 1;

  SELECT id INTO v_cassette_profile_l_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND (sku LIKE '%CASSETTE%L%' OR sku LIKE '%CASS%L%' OR item_name ILIKE '%cassette%l%')
  AND deleted = false
  LIMIT 1;

  -- ====================================================
  -- STEP 2: Create HardwareColorMapping
  -- ====================================================
  RAISE NOTICE 'STEP 2: Creating HardwareColorMapping...';

  -- Brackets: White
  IF v_bracket_base_id IS NOT NULL AND v_bracket_white_id IS NOT NULL THEN
    INSERT INTO "HardwareColorMapping" (
      organization_id,
      base_part_id,
      hardware_color,
      mapped_part_id
    )
    VALUES (
      v_org_id,
      v_bracket_base_id,
      'white',
      v_bracket_white_id
    )
    ON CONFLICT (organization_id, base_part_id, hardware_color) WHERE deleted = false
    DO UPDATE SET mapped_part_id = EXCLUDED.mapped_part_id;
    RAISE NOTICE '  ✅ Mapped bracket white: % -> %', v_bracket_base_id, v_bracket_white_id;
  ELSE
    RAISE WARNING '  ⚠️  Bracket white mapping skipped (SKUs not found)';
  END IF;

  -- Brackets: Black
  IF v_bracket_base_id IS NOT NULL AND v_bracket_black_id IS NOT NULL THEN
    INSERT INTO "HardwareColorMapping" (
      organization_id,
      base_part_id,
      hardware_color,
      mapped_part_id
    )
    VALUES (
      v_org_id,
      v_bracket_base_id,
      'black',
      v_bracket_black_id
    )
    ON CONFLICT (organization_id, base_part_id, hardware_color) WHERE deleted = false
    DO UPDATE SET mapped_part_id = EXCLUDED.mapped_part_id;
    RAISE NOTICE '  ✅ Mapped bracket black: % -> %', v_bracket_base_id, v_bracket_black_id;
  ELSE
    RAISE WARNING '  ⚠️  Bracket black mapping skipped (SKUs not found)';
  END IF;

  -- Bottom Rail: White
  IF v_bottom_rail_base_id IS NOT NULL AND v_bottom_rail_white_id IS NOT NULL THEN
    INSERT INTO "HardwareColorMapping" (
      organization_id,
      base_part_id,
      hardware_color,
      mapped_part_id
    )
    VALUES (
      v_org_id,
      v_bottom_rail_base_id,
      'white',
      v_bottom_rail_white_id
    )
    ON CONFLICT (organization_id, base_part_id, hardware_color) WHERE deleted = false
    DO UPDATE SET mapped_part_id = EXCLUDED.mapped_part_id;
    RAISE NOTICE '  ✅ Mapped bottom rail white: % -> %', v_bottom_rail_base_id, v_bottom_rail_white_id;
  ELSE
    RAISE WARNING '  ⚠️  Bottom rail white mapping skipped (SKUs not found)';
  END IF;

  -- Bottom Rail: Black
  IF v_bottom_rail_base_id IS NOT NULL AND v_bottom_rail_black_id IS NOT NULL THEN
    INSERT INTO "HardwareColorMapping" (
      organization_id,
      base_part_id,
      hardware_color,
      mapped_part_id
    )
    VALUES (
      v_org_id,
      v_bottom_rail_base_id,
      'black',
      v_bottom_rail_black_id
    )
    ON CONFLICT (organization_id, base_part_id, hardware_color) WHERE deleted = false
    DO UPDATE SET mapped_part_id = EXCLUDED.mapped_part_id;
    RAISE NOTICE '  ✅ Mapped bottom rail black: % -> %', v_bottom_rail_base_id, v_bottom_rail_black_id;
  ELSE
    RAISE WARNING '  ⚠️  Bottom rail black mapping skipped (SKUs not found)';
  END IF;

  -- ====================================================
  -- STEP 3: Create CassettePartsMapping
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE 'STEP 3: Creating CassettePartsMapping...';

  -- Round Cassette Profile
  IF v_cassette_profile_round_id IS NOT NULL THEN
    INSERT INTO "CassettePartsMapping" (
      organization_id,
      cassette_shape,
      part_role,
      catalog_item_id,
      qty_per_unit
    )
    VALUES (
      v_org_id,
      'round',
      'profile',
      v_cassette_profile_round_id,
      1
    )
    ON CONFLICT (organization_id, cassette_shape, part_role) WHERE deleted = false
    DO UPDATE SET catalog_item_id = EXCLUDED.catalog_item_id;
    RAISE NOTICE '  ✅ Mapped round cassette profile: %', v_cassette_profile_round_id;
  ELSE
    RAISE WARNING '  ⚠️  Round cassette profile mapping skipped (SKU not found)';
  END IF;

  -- Square Cassette Profile
  IF v_cassette_profile_square_id IS NOT NULL THEN
    INSERT INTO "CassettePartsMapping" (
      organization_id,
      cassette_shape,
      part_role,
      catalog_item_id,
      qty_per_unit
    )
    VALUES (
      v_org_id,
      'square',
      'profile',
      v_cassette_profile_square_id,
      1
    )
    ON CONFLICT (organization_id, cassette_shape, part_role) WHERE deleted = false
    DO UPDATE SET catalog_item_id = EXCLUDED.catalog_item_id;
    RAISE NOTICE '  ✅ Mapped square cassette profile: %', v_cassette_profile_square_id;
  ELSE
    RAISE WARNING '  ⚠️  Square cassette profile mapping skipped (SKU not found)';
  END IF;

  -- L-Shape Cassette Profile
  IF v_cassette_profile_l_id IS NOT NULL THEN
    INSERT INTO "CassettePartsMapping" (
      organization_id,
      cassette_shape,
      part_role,
      catalog_item_id,
      qty_per_unit
    )
    VALUES (
      v_org_id,
      'L',
      'profile',
      v_cassette_profile_l_id,
      1
    )
    ON CONFLICT (organization_id, cassette_shape, part_role) WHERE deleted = false
    DO UPDATE SET catalog_item_id = EXCLUDED.catalog_item_id;
    RAISE NOTICE '  ✅ Mapped L-shape cassette profile: %', v_cassette_profile_l_id;
  ELSE
    RAISE WARNING '  ⚠️  L-shape cassette profile mapping skipped (SKU not found)';
  END IF;

  -- NOTE: You'll need to add endcaps, clips, etc. for each cassette shape
  -- Example for endcaps (you'll need to find these SKUs):
  -- INSERT INTO "CassettePartsMapping" (..., part_role = 'endcap_left', ...)
  -- INSERT INTO "CassettePartsMapping" (..., part_role = 'endcap_right', ...)
  -- INSERT INTO "CassettePartsMapping" (..., part_role = 'clip', ...)

  -- ====================================================
  -- STEP 4: Create MotorTubeCompatibility (placeholder)
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE 'STEP 4: Creating MotorTubeCompatibility...';
  RAISE NOTICE '  ⚠️  This requires actual CatalogItem IDs for motor parts';
  RAISE NOTICE '  📝 You need to:';
  RAISE NOTICE '     1. Find motor crown SKUs (e.g., RC3100-ABC-42, RC3100-ABC-65)';
  RAISE NOTICE '     2. Find drive mechanism SKUs (e.g., RC3164-XX)';
  RAISE NOTICE '     3. Update this script with actual IDs';
  RAISE NOTICE '';
  RAISE NOTICE '  Example structure (uncomment and fill in):';
  RAISE NOTICE '  INSERT INTO "MotorTubeCompatibility" (';
  RAISE NOTICE '    organization_id,';
  RAISE NOTICE '    tube_type,';
  RAISE NOTICE '    motor_family,';
  RAISE NOTICE '    required_crown_item_id,';
  RAISE NOTICE '    required_drive_item_id';
  RAISE NOTICE '  ) VALUES (';
  RAISE NOTICE '    v_org_id,';
  RAISE NOTICE '    ''RTU-65'',';
  RAISE NOTICE '    ''CM-09'',';
  RAISE NOTICE '    (SELECT id FROM "CatalogItems" WHERE sku = ''RC3100-ABC-65''),';
  RAISE NOTICE '    (SELECT id FROM "CatalogItems" WHERE sku = ''RC3164-XX'')';
  RAISE NOTICE '  );';

  RAISE NOTICE '';
  RAISE NOTICE '✅ Mapping data population completed!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Next steps:';
  RAISE NOTICE '   1. Verify your SKUs exist in CatalogItems';
  RAISE NOTICE '   2. Update this script with your actual SKU patterns';
  RAISE NOTICE '   3. Add MotorTubeCompatibility entries with real part IDs';
  RAISE NOTICE '   4. Add CassettePartsMapping for endcaps and clips';

END $$;









