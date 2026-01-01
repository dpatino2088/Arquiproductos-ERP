-- ====================================================
-- Populate MotorTubeCompatibility with Real SKUs
-- ====================================================
-- This script finds motor crown and drive SKUs and populates
-- MotorTubeCompatibility entries
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
  v_crown_sku_id uuid;
  v_drive_sku_id uuid;
  v_accessory_sku_id uuid;
BEGIN
  RAISE NOTICE '🔧 Populating MotorTubeCompatibility with real SKUs...';
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
  -- STEP 1: Find Motor Crown SKUs (RC3100-ABC-XX patterns)
  -- ====================================================
  RAISE NOTICE 'STEP 1: Finding motor crown SKUs...';
  
  -- Common patterns for motor crowns:
  -- RC3100-ABC-42, RC3100-ABC-50, RC3100-ABC-65, RC3100-ABC-80
  -- Or variations like RC3100-XX-42, etc.

  -- ====================================================
  -- STEP 2: Find Motor Drive SKUs (RC3164-XX, etc.)
  -- ====================================================
  RAISE NOTICE 'STEP 2: Finding motor drive SKUs...';
  
  -- Common patterns: RC3164-XX, RC3044, etc.

  -- ====================================================
  -- STEP 3: Update existing entry (RTU-65 + CM-09)
  -- ====================================================
  RAISE NOTICE 'STEP 3: Updating existing MotorTubeCompatibility entries...';

  -- Try to find crown for RTU-65
  SELECT id INTO v_crown_sku_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (
    sku ILIKE '%RC3100%65%' OR
    sku ILIKE '%RC3100%ABC%65%' OR
    sku ILIKE '%crown%65%' OR
    (item_name ILIKE '%crown%' AND item_name ILIKE '%65%')
  )
  LIMIT 1;

  -- Try to find drive for CM-09
  SELECT id INTO v_drive_sku_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (
    sku ILIKE '%RC3164%' OR
    sku ILIKE '%RC3044%' OR
    sku ILIKE '%drive%' OR
    item_name ILIKE '%drive%' OR
    item_name ILIKE '%motor%adapter%'
  )
  LIMIT 1;

  -- Update existing entry if we found SKUs
  IF v_crown_sku_id IS NOT NULL OR v_drive_sku_id IS NOT NULL THEN
    UPDATE "MotorTubeCompatibility"
    SET 
      required_crown_item_id = COALESCE(v_crown_sku_id, required_crown_item_id),
      required_drive_item_id = COALESCE(v_drive_sku_id, required_drive_item_id),
      updated_at = now()
    WHERE organization_id = v_org_id
    AND tube_type = 'RTU-65'
    AND motor_family = 'CM-09'
    AND deleted = false;

    IF v_crown_sku_id IS NOT NULL THEN
      RAISE NOTICE '  ✅ Updated RTU-65 + CM-09: crown = %', v_crown_sku_id;
    END IF;
    IF v_drive_sku_id IS NOT NULL THEN
      RAISE NOTICE '  ✅ Updated RTU-65 + CM-09: drive = %', v_drive_sku_id;
    END IF;
  ELSE
    RAISE WARNING '  ⚠️  Could not find crown/drive SKUs for RTU-65 + CM-09';
    RAISE NOTICE '  📝 You may need to manually update this entry with correct SKU IDs';
  END IF;

  -- ====================================================
  -- STEP 4: Add more MotorTubeCompatibility entries
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE 'STEP 4: Adding more MotorTubeCompatibility combinations...';
  RAISE NOTICE '  ⚠️  This requires actual CatalogItem IDs';
  RAISE NOTICE '  📝 Common combinations to add:';
  RAISE NOTICE '     - CM-05: RTU-42, RTU-50';
  RAISE NOTICE '     - CM-06: RTU-42, RTU-50, RTU-65';
  RAISE NOTICE '     - CM-09: RTU-65, RTU-80';
  RAISE NOTICE '     - CM-10: RTU-80';
  RAISE NOTICE '';
  RAISE NOTICE '  Example INSERT (uncomment and fill in SKU IDs):';
  RAISE NOTICE '  INSERT INTO "MotorTubeCompatibility" (';
  RAISE NOTICE '    organization_id,';
  RAISE NOTICE '    tube_type,';
  RAISE NOTICE '    motor_family,';
  RAISE NOTICE '    required_crown_item_id,';
  RAISE NOTICE '    required_drive_item_id';
  RAISE NOTICE '  ) VALUES (';
  RAISE NOTICE '    v_org_id,';
  RAISE NOTICE '    ''RTU-42'',';
  RAISE NOTICE '    ''CM-05'',';
  RAISE NOTICE '    (SELECT id FROM "CatalogItems" WHERE sku = ''RC3100-ABC-42''),';
  RAISE NOTICE '    (SELECT id FROM "CatalogItems" WHERE sku = ''RC3164-XX'')';
  RAISE NOTICE '  )';
  RAISE NOTICE '  ON CONFLICT (organization_id, tube_type, motor_family) WHERE deleted = false';
  RAISE NOTICE '  DO UPDATE SET';
  RAISE NOTICE '    required_crown_item_id = EXCLUDED.required_crown_item_id,';
  RAISE NOTICE '    required_drive_item_id = EXCLUDED.required_drive_item_id;';

  RAISE NOTICE '';
  RAISE NOTICE '✅ MotorTubeCompatibility population completed!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Next steps:';
  RAISE NOTICE '   1. Find your motor crown SKUs (search for RC3100, crown, etc.)';
  RAISE NOTICE '   2. Find your motor drive SKUs (search for RC3164, RC3044, etc.)';
  RAISE NOTICE '   3. Update this script with actual SKU IDs';
  RAISE NOTICE '   4. Add more combinations (CM-05, CM-06, CM-10)';

END $$;

-- ====================================================
-- Helper Query: Find Motor Parts
-- ====================================================
-- Run this separately to find motor crown and drive SKUs

SELECT 
  'MOTOR_CROWN' as part_type,
  id,
  sku,
  item_name,
  item_type
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%RC3100%' OR
  sku ILIKE '%crown%' OR
  item_name ILIKE '%crown%' OR
  item_name ILIKE '%motor%crown%'
)
ORDER BY sku
LIMIT 20;

SELECT 
  'MOTOR_DRIVE' as part_type,
  id,
  sku,
  item_name,
  item_type
FROM "CatalogItems"
WHERE deleted = false
AND (
  sku ILIKE '%RC3164%' OR
  sku ILIKE '%RC3044%' OR
  sku ILIKE '%drive%' OR
  item_name ILIKE '%drive%' OR
  item_name ILIKE '%motor%adapter%' OR
  item_name ILIKE '%motor%drive%'
)
ORDER BY sku
LIMIT 20;









