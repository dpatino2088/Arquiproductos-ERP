-- ====================================================
-- Migration: Populate MotorTubeCompatibility with Real SKUs
-- ====================================================
-- This script populates MotorTubeCompatibility with actual SKUs
-- from CatalogItems based on motor family and tube type combinations
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
  v_crown_id uuid;
  v_drive_id uuid;
  v_updated_count integer := 0;
  v_inserted_count integer := 0;
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
  -- CM-05 (28mm, 2Nm) - Compatible with RTU-42, RTU-50
  -- ====================================================
  RAISE NOTICE 'STEP 1: CM-05 (28mm, 2Nm motor)...';

  -- Crown for CM-05: RC3107-ABC (Crown 38mm for 2Nm motor CM-05)
  SELECT id INTO v_crown_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND sku = 'RC3107-ABC'
  LIMIT 1;

  -- Drive for CM-05: RC3083-ABC (Drive plug 38mm DC motor)
  SELECT id INTO v_drive_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND sku = 'RC3083-ABC'
  LIMIT 1;

  -- RTU-42 + CM-05
  IF v_crown_id IS NOT NULL OR v_drive_id IS NOT NULL THEN
    INSERT INTO "MotorTubeCompatibility" (
      organization_id,
      tube_type,
      motor_family,
      required_crown_item_id,
      required_drive_item_id,
      notes
    )
    VALUES (
      v_org_id,
      'RTU-42',
      'CM-05',
      v_crown_id,
      v_drive_id,
      'CM-05 (28mm, 2Nm) with RTU-42 tube'
    )
    ON CONFLICT (organization_id, tube_type, motor_family) 
    WHERE deleted = false 
    DO UPDATE SET
      required_crown_item_id = COALESCE(EXCLUDED.required_crown_item_id, "MotorTubeCompatibility".required_crown_item_id),
      required_drive_item_id = COALESCE(EXCLUDED.required_drive_item_id, "MotorTubeCompatibility".required_drive_item_id),
      notes = EXCLUDED.notes,
      updated_at = now();
    
    v_inserted_count := v_inserted_count + 1;
    RAISE NOTICE '  ✅ RTU-42 + CM-05: crown=% | drive=%', v_crown_id, v_drive_id;
  END IF;

  -- RTU-50 + CM-05
  IF v_crown_id IS NOT NULL OR v_drive_id IS NOT NULL THEN
    INSERT INTO "MotorTubeCompatibility" (
      organization_id,
      tube_type,
      motor_family,
      required_crown_item_id,
      required_drive_item_id,
      notes
    )
    VALUES (
      v_org_id,
      'RTU-50',
      'CM-05',
      v_crown_id,
      v_drive_id,
      'CM-05 (28mm, 2Nm) with RTU-50 tube'
    )
    ON CONFLICT (organization_id, tube_type, motor_family) 
    WHERE deleted = false 
    DO UPDATE SET
      required_crown_item_id = COALESCE(EXCLUDED.required_crown_item_id, "MotorTubeCompatibility".required_crown_item_id),
      required_drive_item_id = COALESCE(EXCLUDED.required_drive_item_id, "MotorTubeCompatibility".required_drive_item_id),
      notes = EXCLUDED.notes,
      updated_at = now();
    
    v_inserted_count := v_inserted_count + 1;
    RAISE NOTICE '  ✅ RTU-50 + CM-05: crown=% | drive=%', v_crown_id, v_drive_id;
  END IF;

  -- ====================================================
  -- CM-06 (35mm, 6Nm DC) - Compatible with RTU-42, RTU-50, RTU-65
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE 'STEP 2: CM-06 (35mm, 6Nm DC motor)...';

  -- Crown for CM-06: RC2047-ABC (Crown Somfy DC 28-30-35-38mm) or RC3098-ABC (Crown 42/50mm Somfy)
  SELECT id INTO v_crown_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku = 'RC2047-ABC' OR sku = 'RC3098-ABC')
  LIMIT 1;

  -- Drive for CM-06: RC3164-W (default white, or any color variant)
  SELECT id INTO v_drive_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND sku LIKE 'RC3164%'
  LIMIT 1;

  -- RTU-42 + CM-06
  IF v_crown_id IS NOT NULL OR v_drive_id IS NOT NULL THEN
    INSERT INTO "MotorTubeCompatibility" (
      organization_id,
      tube_type,
      motor_family,
      required_crown_item_id,
      required_drive_item_id,
      notes
    )
    VALUES (
      v_org_id,
      'RTU-42',
      'CM-06',
      v_crown_id,
      v_drive_id,
      'CM-06 (35mm, 6Nm DC) with RTU-42 tube'
    )
    ON CONFLICT (organization_id, tube_type, motor_family) 
    WHERE deleted = false 
    DO UPDATE SET
      required_crown_item_id = COALESCE(EXCLUDED.required_crown_item_id, "MotorTubeCompatibility".required_crown_item_id),
      required_drive_item_id = COALESCE(EXCLUDED.required_drive_item_id, "MotorTubeCompatibility".required_drive_item_id),
      notes = EXCLUDED.notes,
      updated_at = now();
    
    v_inserted_count := v_inserted_count + 1;
    RAISE NOTICE '  ✅ RTU-42 + CM-06: crown=% | drive=%', v_crown_id, v_drive_id;
  END IF;

  -- RTU-50 + CM-06
  IF v_crown_id IS NOT NULL OR v_drive_id IS NOT NULL THEN
    INSERT INTO "MotorTubeCompatibility" (
      organization_id,
      tube_type,
      motor_family,
      required_crown_item_id,
      required_drive_item_id,
      notes
    )
    VALUES (
      v_org_id,
      'RTU-50',
      'CM-06',
      v_crown_id,
      v_drive_id,
      'CM-06 (35mm, 6Nm DC) with RTU-50 tube'
    )
    ON CONFLICT (organization_id, tube_type, motor_family) 
    WHERE deleted = false 
    DO UPDATE SET
      required_crown_item_id = COALESCE(EXCLUDED.required_crown_item_id, "MotorTubeCompatibility".required_crown_item_id),
      required_drive_item_id = COALESCE(EXCLUDED.required_drive_item_id, "MotorTubeCompatibility".required_drive_item_id),
      notes = EXCLUDED.notes,
      updated_at = now();
    
    v_inserted_count := v_inserted_count + 1;
    RAISE NOTICE '  ✅ RTU-50 + CM-06: crown=% | drive=%', v_crown_id, v_drive_id;
  END IF;

  -- RTU-65 + CM-06
  IF v_crown_id IS NOT NULL OR v_drive_id IS NOT NULL THEN
    INSERT INTO "MotorTubeCompatibility" (
      organization_id,
      tube_type,
      motor_family,
      required_crown_item_id,
      required_drive_item_id,
      notes
    )
    VALUES (
      v_org_id,
      'RTU-65',
      'CM-06',
      v_crown_id,
      v_drive_id,
      'CM-06 (35mm, 6Nm DC) with RTU-65 tube'
    )
    ON CONFLICT (organization_id, tube_type, motor_family) 
    WHERE deleted = false 
    DO UPDATE SET
      required_crown_item_id = COALESCE(EXCLUDED.required_crown_item_id, "MotorTubeCompatibility".required_crown_item_id),
      required_drive_item_id = COALESCE(EXCLUDED.required_drive_item_id, "MotorTubeCompatibility".required_drive_item_id),
      notes = EXCLUDED.notes,
      updated_at = now();
    
    v_inserted_count := v_inserted_count + 1;
    RAISE NOTICE '  ✅ RTU-65 + CM-06: crown=% | drive=%', v_crown_id, v_drive_id;
  END IF;

  -- ====================================================
  -- CM-09 (35mm, 6Nm AC) - Compatible with RTU-65, RTU-80
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE 'STEP 3: CM-09 (35mm, 6Nm AC motor)...';

  -- Crown for CM-09 AC: RC3044-ABC (Crown Somfy AC 42-50-65-80mm)
  SELECT id INTO v_crown_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND sku = 'RC3044-ABC'
  LIMIT 1;

  -- Drive for CM-09 AC: RC3045-ABC (Drive plug Somfy AC 42-50mm) or RC3100-ABC-W (motor cover)
  SELECT id INTO v_drive_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku = 'RC3045-ABC' OR sku LIKE 'RC3100-ABC%')
  LIMIT 1;

  -- RTU-65 + CM-09
  IF v_crown_id IS NOT NULL OR v_drive_id IS NOT NULL THEN
    INSERT INTO "MotorTubeCompatibility" (
      organization_id,
      tube_type,
      motor_family,
      required_crown_item_id,
      required_drive_item_id,
      notes
    )
    VALUES (
      v_org_id,
      'RTU-65',
      'CM-09',
      v_crown_id,
      v_drive_id,
      'CM-09 (35mm, 6Nm AC) with RTU-65 tube'
    )
    ON CONFLICT (organization_id, tube_type, motor_family) 
    WHERE deleted = false 
    DO UPDATE SET
      required_crown_item_id = COALESCE(EXCLUDED.required_crown_item_id, "MotorTubeCompatibility".required_crown_item_id),
      required_drive_item_id = COALESCE(EXCLUDED.required_drive_item_id, "MotorTubeCompatibility".required_drive_item_id),
      notes = EXCLUDED.notes,
      updated_at = now();
    
    v_updated_count := v_updated_count + 1;
    RAISE NOTICE '  ✅ RTU-65 + CM-09: crown=% | drive=%', v_crown_id, v_drive_id;
  END IF;

  -- RTU-80 + CM-09
  IF v_crown_id IS NOT NULL OR v_drive_id IS NOT NULL THEN
    INSERT INTO "MotorTubeCompatibility" (
      organization_id,
      tube_type,
      motor_family,
      required_crown_item_id,
      required_drive_item_id,
      notes
    )
    VALUES (
      v_org_id,
      'RTU-80',
      'CM-09',
      v_crown_id,
      v_drive_id,
      'CM-09 (35mm, 6Nm AC) with RTU-80 tube'
    )
    ON CONFLICT (organization_id, tube_type, motor_family) 
    WHERE deleted = false 
    DO UPDATE SET
      required_crown_item_id = COALESCE(EXCLUDED.required_crown_item_id, "MotorTubeCompatibility".required_crown_item_id),
      required_drive_item_id = COALESCE(EXCLUDED.required_drive_item_id, "MotorTubeCompatibility".required_drive_item_id),
      notes = EXCLUDED.notes,
      updated_at = now();
    
    v_inserted_count := v_inserted_count + 1;
    RAISE NOTICE '  ✅ RTU-80 + CM-09: crown=% | drive=%', v_crown_id, v_drive_id;
  END IF;

  -- ====================================================
  -- CM-10 (35mm, 8Nm AC) - Compatible with RTU-80
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE 'STEP 4: CM-10 (35mm, 8Nm AC motor)...';

  -- Crown for CM-10 AC: Same as CM-09 (RC3044-ABC)
  SELECT id INTO v_crown_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND sku = 'RC3044-ABC'
  LIMIT 1;

  -- Drive for CM-10 AC: Same as CM-09 (RC3045-ABC or RC3100-ABC)
  SELECT id INTO v_drive_id
  FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku = 'RC3045-ABC' OR sku LIKE 'RC3100-ABC%')
  LIMIT 1;

  -- RTU-80 + CM-10
  IF v_crown_id IS NOT NULL OR v_drive_id IS NOT NULL THEN
    INSERT INTO "MotorTubeCompatibility" (
      organization_id,
      tube_type,
      motor_family,
      required_crown_item_id,
      required_drive_item_id,
      notes
    )
    VALUES (
      v_org_id,
      'RTU-80',
      'CM-10',
      v_crown_id,
      v_drive_id,
      'CM-10 (35mm, 8Nm AC) with RTU-80 tube'
    )
    ON CONFLICT (organization_id, tube_type, motor_family) 
    WHERE deleted = false 
    DO UPDATE SET
      required_crown_item_id = COALESCE(EXCLUDED.required_crown_item_id, "MotorTubeCompatibility".required_crown_item_id),
      required_drive_item_id = COALESCE(EXCLUDED.required_drive_item_id, "MotorTubeCompatibility".required_drive_item_id),
      notes = EXCLUDED.notes,
      updated_at = now();
    
    v_inserted_count := v_inserted_count + 1;
    RAISE NOTICE '  ✅ RTU-80 + CM-10: crown=% | drive=%', v_crown_id, v_drive_id;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '✅ MotorTubeCompatibility population completed!';
  RAISE NOTICE '  📊 Updated: % entries', v_updated_count;
  RAISE NOTICE '  📊 Inserted: % entries', v_inserted_count;
  RAISE NOTICE '  📊 Total: % entries', v_updated_count + v_inserted_count;

END $$;

-- ====================================================
-- Verification Query
-- ====================================================
SELECT 
  'MotorTubeCompatibility' as table_name,
  tube_type,
  motor_family,
  (SELECT sku FROM "CatalogItems" WHERE id = required_crown_item_id) as crown_sku,
  (SELECT sku FROM "CatalogItems" WHERE id = required_drive_item_id) as drive_sku,
  notes
FROM "MotorTubeCompatibility"
WHERE deleted = false
ORDER BY motor_family, tube_type;

