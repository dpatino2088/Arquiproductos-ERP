-- ====================================================
-- Migration: Clean BOMComponents Hardware Color
-- ====================================================
-- This script removes specific hardware_color values from BOMComponents
-- and sets applies_color = true for components that should use HardwareColorMapping
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
  v_updated_count integer := 0;
  v_component_count integer := 0;
  rec RECORD;
BEGIN
  RAISE NOTICE '🔧 Cleaning BOMComponents hardware_color...';
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

  -- Count components that need updating
  SELECT COUNT(*) INTO v_component_count
  FROM "BOMComponents"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (
    hardware_color IS NOT NULL
    OR (applies_color = false AND component_item_id IN (
      SELECT base_part_id FROM "HardwareColorMapping" WHERE organization_id = v_org_id AND deleted = false
    ))
  );

  RAISE NOTICE '  📊 Found % components that may need updating', v_component_count;
  RAISE NOTICE '';

  -- ====================================================
  -- STEP 1: Update components with hardware_color to use applies_color instead
  -- ====================================================
  RAISE NOTICE 'STEP 1: Updating components with specific hardware_color...';

  FOR rec IN (
    SELECT 
      id,
      component_item_id,
      component_role,
      hardware_color,
      applies_color,
      (SELECT sku FROM "CatalogItems" WHERE id = component_item_id) as sku
    FROM "BOMComponents"
    WHERE organization_id = v_org_id
    AND deleted = false
    AND hardware_color IS NOT NULL
  ) LOOP
    -- Check if this component has color variants in HardwareColorMapping
    IF EXISTS (
      SELECT 1
      FROM "HardwareColorMapping"
      WHERE organization_id = v_org_id
      AND base_part_id = rec.component_item_id
      AND deleted = false
    ) THEN
      -- Component has color variants - set applies_color = true and remove hardware_color
      UPDATE "BOMComponents"
      SET 
        applies_color = true,
        hardware_color = NULL,
        updated_at = now()
      WHERE id = rec.id
      AND deleted = false;

      v_updated_count := v_updated_count + 1;
      RAISE NOTICE '  ✅ Updated: % (role: %) - removed hardware_color=%, set applies_color=true', 
        rec.sku, rec.component_role, rec.hardware_color;
    ELSE
      -- Component doesn't have color variants - just remove hardware_color
      UPDATE "BOMComponents"
      SET 
        hardware_color = NULL,
        updated_at = now()
      WHERE id = rec.id
      AND deleted = false;

      v_updated_count := v_updated_count + 1;
      RAISE NOTICE '  ✅ Updated: % (role: %) - removed hardware_color=% (no color variants found)', 
        rec.sku, rec.component_role, rec.hardware_color;
    END IF;
  END LOOP;

  -- ====================================================
  -- STEP 2: Set applies_color = true for components that have color variants
  -- but applies_color is false or NULL
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE 'STEP 2: Setting applies_color=true for components with color variants...';

  FOR rec IN (
    SELECT DISTINCT
      bom.id,
      bom.component_role,
      bom.applies_color,
      (SELECT sku FROM "CatalogItems" WHERE id = bom.component_item_id) as sku
    FROM "BOMComponents" bom
    INNER JOIN "HardwareColorMapping" hcm ON bom.component_item_id = hcm.base_part_id
    WHERE bom.organization_id = v_org_id
    AND bom.deleted = false
    AND hcm.organization_id = v_org_id
    AND hcm.deleted = false
    AND (bom.applies_color = false OR bom.applies_color IS NULL)
  ) LOOP
    UPDATE "BOMComponents"
    SET 
      applies_color = true,
      updated_at = now()
    WHERE id = rec.id
    AND deleted = false;

    v_updated_count := v_updated_count + 1;
    RAISE NOTICE '  ✅ Updated: % (role: %) - set applies_color=true (has color variants)', 
      rec.sku, rec.component_role;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ BOMComponents cleanup completed!';
  RAISE NOTICE '  📊 Total updated: % components', v_updated_count;
  RAISE NOTICE '';

  -- ====================================================
  -- Summary
  -- ====================================================
  RAISE NOTICE '📊 Final BOMComponents summary:';
  
  FOR rec IN (
    SELECT 
      applies_color,
      COUNT(*) as count
    FROM "BOMComponents"
    WHERE organization_id = v_org_id
    AND deleted = false
    GROUP BY applies_color
    ORDER BY applies_color NULLS LAST
  ) LOOP
    RAISE NOTICE '  - applies_color = %: % components', 
      COALESCE(rec.applies_color::text, 'NULL'), rec.count;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '📊 Components with hardware_color (should be 0):';
  SELECT COUNT(*) INTO v_component_count
  FROM "BOMComponents"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND hardware_color IS NOT NULL;
  
  RAISE NOTICE '  - Components with hardware_color: %', v_component_count;

END $$;

-- ====================================================
-- Verification Queries
-- ====================================================

-- Show components that still have hardware_color (should be 0 or minimal)
SELECT 
  'BOMComponents with hardware_color' as check_type,
  id,
  component_role,
  hardware_color,
  applies_color,
  (SELECT sku FROM "CatalogItems" WHERE id = component_item_id) as sku
FROM "BOMComponents"
WHERE deleted = false
AND hardware_color IS NOT NULL
ORDER BY component_role, hardware_color
LIMIT 20;

-- Show components with applies_color = true
SELECT 
  'BOMComponents with applies_color=true' as check_type,
  COUNT(*) as count,
  component_role
FROM "BOMComponents"
WHERE deleted = false
AND applies_color = true
GROUP BY component_role
ORDER BY component_role;

