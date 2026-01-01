-- ====================================================
-- Migration: Populate BOM Mappings from CSV SKUs
-- ====================================================
-- This script populates HardwareColorMapping, MotorTubeCompatibility,
-- and CassettePartsMapping based on actual SKUs found in CatalogItems
--
-- IMPORTANT: Execute migration 159_update_hardware_color_constraint.sql FIRST
-- to update the HardwareColorMapping constraint to allow additional colors
-- (grey, anthracite, off_white, etc.)
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
  v_motor_cm09_id uuid;
  v_tube_rtu38_id uuid;
  v_tube_rtu42_id uuid;
  v_tube_rtu50_id uuid;
  v_tube_rtu65_id uuid;
  v_tube_rtu80_id uuid;
  v_crown_rtu65_cm09_id uuid;
  v_drive_rtu65_cm09_id uuid;
  v_base_id uuid;
  v_shape text;
  v_role text;
  v_hardware_color_count integer := 0;
  v_cassette_parts_count integer := 0;
  v_mapped_count integer := 0;
  rec RECORD;
BEGIN
  RAISE NOTICE '🔧 Populating BOM Mappings from CatalogItems SKUs...';
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
  -- STEP 1: Find Tube SKUs
  -- ====================================================
  RAISE NOTICE 'STEP 1: Finding tube SKUs...';
  
  SELECT id INTO v_tube_rtu38_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND sku = 'RTU-38'
  LIMIT 1;

  SELECT id INTO v_tube_rtu42_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND sku = 'RTU-42'
  LIMIT 1;

  SELECT id INTO v_tube_rtu50_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND sku = 'RTU-50'
  LIMIT 1;

  SELECT id INTO v_tube_rtu65_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND sku = 'RTU-65'
  LIMIT 1;

  SELECT id INTO v_tube_rtu80_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND sku = 'RTU-80'
  LIMIT 1;

  RAISE NOTICE '  ✅ Found tubes: RTU-38=% | RTU-42=% | RTU-50=% | RTU-65=% | RTU-80=%',
    v_tube_rtu38_id, v_tube_rtu42_id, v_tube_rtu50_id, v_tube_rtu65_id, v_tube_rtu80_id;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 2: Find Motor SKUs
  -- ====================================================
  RAISE NOTICE 'STEP 2: Finding motor SKUs...';
  
  SELECT id INTO v_motor_cm09_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku LIKE 'CM-09%' OR sku = 'CM-09')
  LIMIT 1;

  RAISE NOTICE '  ✅ Found motor CM-09: %', v_motor_cm09_id;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 3: Find Motor Crown SKUs for RTU-65 + CM-09
  -- ====================================================
  RAISE NOTICE 'STEP 3: Finding motor crown SKUs for RTU-65 + CM-09...';
  
  -- Try to find crown for 65mm tube (RC3100-ABC-XX or similar)
  SELECT id INTO v_crown_rtu65_cm09_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (
    sku LIKE 'RC3100-ABC%' OR
    sku LIKE 'RC3100%' OR
    (item_name ILIKE '%crown%' AND (item_name ILIKE '%65%' OR item_name ILIKE '%AC%'))
  )
  LIMIT 1;

  RAISE NOTICE '  ✅ Found crown for RTU-65: %', v_crown_rtu65_cm09_id;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 4: Find Motor Drive SKUs for RTU-65 + CM-09
  -- ====================================================
  RAISE NOTICE 'STEP 4: Finding motor drive SKUs for RTU-65 + CM-09...';
  
  -- Try to find drive/adapter for CM-09 (RC3164-XX, RC3044, etc.)
  SELECT id INTO v_drive_rtu65_cm09_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (
    sku LIKE 'RC3164%' OR
    sku LIKE 'RC3044%' OR
    sku LIKE 'RC3045%' OR
    (item_name ILIKE '%motor%adapter%' OR item_name ILIKE '%drive%plug%')
  )
  LIMIT 1;

  RAISE NOTICE '  ✅ Found drive for CM-09: %', v_drive_rtu65_cm09_id;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 5: Update MotorTubeCompatibility
  -- ====================================================
  RAISE NOTICE 'STEP 5: Updating MotorTubeCompatibility...';

  -- Update existing RTU-65 + CM-09 entry
  IF v_crown_rtu65_cm09_id IS NOT NULL OR v_drive_rtu65_cm09_id IS NOT NULL THEN
    UPDATE "MotorTubeCompatibility"
    SET 
      required_crown_item_id = COALESCE(v_crown_rtu65_cm09_id, required_crown_item_id),
      required_drive_item_id = COALESCE(v_drive_rtu65_cm09_id, required_drive_item_id),
      updated_at = now()
    WHERE organization_id = v_org_id
    AND tube_type = 'RTU-65'
    AND motor_family = 'CM-09'
    AND deleted = false;

    RAISE NOTICE '  ✅ Updated RTU-65 + CM-09 compatibility';
  ELSE
    RAISE WARNING '  ⚠️  Could not find crown/drive SKUs for RTU-65 + CM-09';
  END IF;

  RAISE NOTICE '';

  -- ====================================================
  -- STEP 6: Populate HardwareColorMapping for Brackets and Cassettes
  -- ====================================================
  RAISE NOTICE 'STEP 6: Populating HardwareColorMapping for brackets and cassettes...';

  -- RC2006: Roller blind bracket metal S (with color variants)
  -- Also includes cassette end caps with color variants
  FOR rec IN (
    SELECT 
      CASE 
        WHEN sku ~ '^(.+)-W$' THEN regexp_replace(sku, '-W$', '')
        WHEN sku ~ '^(.+)-BK$' THEN regexp_replace(sku, '-BK$', '')
        WHEN sku ~ '^(.+)-DBR$' THEN regexp_replace(sku, '-DBR$', '')
        WHEN sku ~ '^(.+)-GR$' THEN regexp_replace(sku, '-GR$', '')
        WHEN sku ~ '^(.+)-AN$' THEN regexp_replace(sku, '-AN$', '')
        WHEN sku ~ '^(.+)-LB$' THEN regexp_replace(sku, '-LB$', '')
        ELSE NULL
      END as base_sku_pattern,
      CASE 
        WHEN sku ~ '-W$' THEN 'white'
        WHEN sku ~ '-BK$' THEN 'black'
        WHEN sku ~ '-DBR$' THEN 'bronze'
        WHEN sku ~ '-GR$' THEN 'grey'
        WHEN sku ~ '-AN$' THEN 'anthracite'
        WHEN sku ~ '-LB$' THEN 'off_white'
        ELSE NULL
      END as color,
      id,
      sku
    FROM "CatalogItems"
    WHERE organization_id = v_org_id
    AND deleted = false
    AND item_type = 'component'
    AND (
      sku LIKE 'RC2006%' OR  -- Brackets S
      sku LIKE 'RC4004%' OR  -- Brackets L
      sku LIKE 'RC2007%' OR  -- End caps S
      sku LIKE 'RC2008%' OR  -- Screw caps S
      sku LIKE 'RC4005%' OR  -- End caps L
      sku LIKE 'RC4006%' OR  -- Screw caps L
      sku LIKE 'RC2003%' OR  -- Bearing pins
      sku LIKE 'RC2004%' OR  -- Adjustable bearing pins
      sku LIKE 'RC3036%' OR  -- Cassette end cap square M right
      sku LIKE 'RC3037%' OR  -- Cassette end cap square M left
      sku LIKE 'RC3038%' OR  -- Cassette end cap round M chain right
      sku LIKE 'RC3040%' OR  -- Cassette end cap square M chain left
      sku LIKE 'RC3041%' OR  -- Cassette end cap square M chain right
      sku LIKE 'RC3173%'     -- Cassette end cap square M motorized left
    )
    AND (
      sku ~ '-W$' OR sku ~ '-BK$' OR sku ~ '-DBR$' OR 
      sku ~ '-GR$' OR sku ~ '-AN$' OR sku ~ '-LB$'
    )
  ) LOOP
    IF rec.base_sku_pattern IS NOT NULL AND rec.color IS NOT NULL THEN
      -- Find base SKU (without color suffix)
      SELECT id INTO v_base_id
      FROM "CatalogItems"
      WHERE organization_id = v_org_id
      AND deleted = false
      AND sku = rec.base_sku_pattern
      LIMIT 1;

      -- If base SKU doesn't exist, use white variant as base
      IF v_base_id IS NULL THEN
        SELECT id INTO v_base_id
        FROM "CatalogItems"
        WHERE organization_id = v_org_id
        AND deleted = false
        AND sku = rec.base_sku_pattern || '-W'
        LIMIT 1;
      END IF;

      -- If still no base found, skip this mapping (can't create mapping without a base)
      IF v_base_id IS NULL THEN
        RAISE NOTICE '  ⚠️  Skipping mapping for % - no base SKU found', rec.sku;
        CONTINUE;
      END IF;

      -- Don't create mapping if base and mapped are the same (would violate constraint)
      -- This happens when processing white variant and using it as base
      IF v_base_id = rec.id THEN
        -- This is expected for white variants when used as base - skip silently
        CONTINUE;
      END IF;

      -- Insert/update HardwareColorMapping
      INSERT INTO "HardwareColorMapping" (
        organization_id,
        base_part_id,
        hardware_color,
        mapped_part_id
      )
      VALUES (
        v_org_id,
        v_base_id,
        rec.color,
        rec.id
      )
      ON CONFLICT (organization_id, base_part_id, hardware_color) 
      WHERE deleted = false 
      DO UPDATE SET
        mapped_part_id = EXCLUDED.mapped_part_id,
        updated_at = now();

      v_mapped_count := v_mapped_count + 1;
    END IF;
  END LOOP;

  v_hardware_color_count := v_mapped_count;
  RAISE NOTICE '  ✅ Created/updated % HardwareColorMapping entries (brackets, end caps, bearing pins, cassette end caps)', v_hardware_color_count;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 7: Populate CassettePartsMapping (shape and role only)
  -- ====================================================
  RAISE NOTICE 'STEP 7: Populating CassettePartsMapping (shape and role mapping)...';

  v_mapped_count := 0;

  -- Find cassette end caps
  FOR rec IN (
    SELECT id, sku, item_name
    FROM "CatalogItems"
    WHERE organization_id = v_org_id
    AND deleted = false
    AND (
      item_name ILIKE '%cassette%end%cap%' OR
      sku LIKE 'RC3036%' OR  -- Square M right
      sku LIKE 'RC3037%' OR  -- Square M left
      sku LIKE 'RC3038%' OR  -- Round M chain right
      sku LIKE 'RC3040%' OR  -- Square M chain left
      sku LIKE 'RC3041%' OR  -- Square M chain right
      sku LIKE 'RC3052%' OR  -- Semi-open cassette end cap set M (square, both left+right in set)
      sku LIKE 'RC3132%' OR  -- Semi-open cassette endcap set M square (both left+right in set)
      sku LIKE 'RC3173%'     -- Square M motorized left
    )
  ) LOOP
    -- Determine cassette shape and part role from SKU/item_name
    -- Default values
    v_shape := 'round';
    v_role := 'endcap_right';

    -- Determine shape - prioritize item_name, then SKU patterns
    IF rec.item_name ILIKE '%square%' THEN
      v_shape := 'square';
    ELSIF rec.item_name ILIKE '%round%' THEN
      v_shape := 'round';
    ELSIF rec.sku LIKE '%3036%' OR rec.sku LIKE '%3037%' OR 
          rec.sku LIKE '%3040%' OR rec.sku LIKE '%3041%' OR 
          rec.sku LIKE '%3173%' OR rec.sku LIKE '%3132%' OR 
          rec.sku LIKE '%3052%' THEN
      v_shape := 'square';
    ELSIF rec.sku LIKE '%3038%' THEN
      v_shape := 'round';
    END IF;

    -- Determine role - prioritize item_name, then SKU patterns
    -- Note: RC3052 and RC3132 are "set" items that include both left and right
    -- For these, we'll default to 'endcap_right' but they should ideally be handled differently
    IF rec.item_name ILIKE '%left%' AND rec.item_name NOT ILIKE '%right%' THEN
      v_role := 'endcap_left';
    ELSIF rec.item_name ILIKE '%right%' AND rec.item_name NOT ILIKE '%left%' THEN
      v_role := 'endcap_right';
    ELSIF rec.sku LIKE '%3037%' OR rec.sku LIKE '%3040%' OR rec.sku LIKE '%3173%' THEN
      v_role := 'endcap_left';
    ELSIF rec.sku LIKE '%3036%' OR rec.sku LIKE '%3038%' OR rec.sku LIKE '%3041%' THEN
      v_role := 'endcap_right';
    ELSIF rec.sku LIKE '%3052%' OR rec.sku LIKE '%3132%' THEN
      -- These are "set" items - default to right, but note they include both
      v_role := 'endcap_right';
    END IF;

    -- Insert/update CassettePartsMapping
    INSERT INTO "CassettePartsMapping" (
      organization_id,
      cassette_shape,
      part_role,
      catalog_item_id,
      qty_per_unit
    )
    VALUES (
      v_org_id,
      v_shape,
      v_role,
      rec.id,
      1
    )
    ON CONFLICT (organization_id, cassette_shape, part_role) 
    WHERE deleted = false 
    DO UPDATE SET
      catalog_item_id = EXCLUDED.catalog_item_id,
      qty_per_unit = EXCLUDED.qty_per_unit,
      updated_at = now();

    v_mapped_count := v_mapped_count + 1;
  END LOOP;

  v_cassette_parts_count := v_mapped_count;
  RAISE NOTICE '  ✅ Created/updated % CassettePartsMapping entries', v_cassette_parts_count;
  RAISE NOTICE '';

  RAISE NOTICE '✅ BOM Mappings population completed!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Summary:';
  RAISE NOTICE '   - Tubes found: RTU-38, RTU-42, RTU-50, RTU-65, RTU-80';
  RAISE NOTICE '   - Motor CM-09 found: %', v_motor_cm09_id;
  RAISE NOTICE '   - Crown for RTU-65 + CM-09: %', v_crown_rtu65_cm09_id;
  RAISE NOTICE '   - Drive for RTU-65 + CM-09: %', v_drive_rtu65_cm09_id;
  RAISE NOTICE '   - HardwareColorMapping entries (brackets, end caps, cassettes): %', v_hardware_color_count;
  RAISE NOTICE '   - CassettePartsMapping entries (shape/role): %', v_cassette_parts_count;

END $$;

-- ====================================================
-- Verification Queries
-- ====================================================

-- Check MotorTubeCompatibility
SELECT 
  'MotorTubeCompatibility' as table_name,
  tube_type,
  motor_family,
  (SELECT sku FROM "CatalogItems" WHERE id = required_crown_item_id) as crown_sku,
  (SELECT sku FROM "CatalogItems" WHERE id = required_drive_item_id) as drive_sku
FROM "MotorTubeCompatibility"
WHERE deleted = false
ORDER BY tube_type, motor_family;

-- Check HardwareColorMapping (sample)
SELECT 
  'HardwareColorMapping' as table_name,
  (SELECT sku FROM "CatalogItems" WHERE id = base_part_id) as base_sku,
  hardware_color,
  (SELECT sku FROM "CatalogItems" WHERE id = mapped_part_id) as color_sku
FROM "HardwareColorMapping"
WHERE deleted = false
ORDER BY base_sku, hardware_color
LIMIT 20;

-- Check CassettePartsMapping
SELECT 
  'CassettePartsMapping' as table_name,
  cassette_shape,
  part_role,
  (SELECT sku FROM "CatalogItems" WHERE id = catalog_item_id) as sku,
  qty_per_unit
FROM "CassettePartsMapping"
WHERE deleted = false
ORDER BY cassette_shape, part_role;

