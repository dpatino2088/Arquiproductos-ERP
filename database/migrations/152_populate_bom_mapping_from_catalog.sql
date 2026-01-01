-- ====================================================
-- Migration: Populate BOM Mapping from CatalogItems
-- ====================================================
-- This script automatically creates HardwareColorMapping entries
-- by finding SKUs with color variants (W, BK, DBR, LB, etc.)
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
  v_base_sku text;
  v_white_id uuid;
  v_black_id uuid;
  v_bronze_id uuid;
  v_silver_id uuid;
  v_base_id uuid;
  v_mapped_count integer := 0;
  rec RECORD;
BEGIN
  RAISE NOTICE '🔧 Populating HardwareColorMapping from CatalogItems...';
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
  -- STEP 1: Find SKUs with color variants and create mappings
  -- ====================================================
  RAISE NOTICE 'STEP 1: Finding SKUs with color variants...';

  -- Find SKUs that have both base and color variants
  -- Pattern: Base SKU (e.g., RC2004) and variants (RC2004-W, RC2004-BK, etc.)
  FOR rec IN (
    WITH color_variants AS (
      SELECT 
        -- Extract base SKU (remove color suffix)
        CASE 
          WHEN sku ~ '^(.+)-W$' THEN regexp_replace(sku, '-W$', '')
          WHEN sku ~ '^(.+)-BK$' THEN regexp_replace(sku, '-BK$', '')
          WHEN sku ~ '^(.+)-DBR$' THEN regexp_replace(sku, '-DBR$', '')
          WHEN sku ~ '^(.+)-LB$' THEN regexp_replace(sku, '-LB$', '')
          WHEN sku ~ '^(.+)-S$' THEN regexp_replace(sku, '-S$', '')
          ELSE NULL
        END as base_sku_pattern,
        -- Group by base pattern
        CASE 
          WHEN sku ~ '-W$' THEN 'white'
          WHEN sku ~ '-BK$' THEN 'black'
          WHEN sku ~ '-DBR$' THEN 'bronze'
          WHEN sku ~ '-LB$' THEN 'black'  -- LB = Light Black/Off-white, treat as black variant
          WHEN sku ~ '-S$' THEN 'silver'
          ELSE NULL
        END as color,
        id,
        sku
      FROM "CatalogItems"
      WHERE organization_id = v_org_id
      AND deleted = false
      AND item_type = 'component'
      AND (
        sku ~ '-W$' OR
        sku ~ '-BK$' OR
        sku ~ '-DBR$' OR
        sku ~ '-LB$' OR
        sku ~ '-S$'
      )
    )
    SELECT * FROM color_variants
    WHERE base_sku_pattern IS NOT NULL
  ) LOOP
    -- Find base SKU (without color suffix)
    SELECT id INTO v_base_id
    FROM "CatalogItems"
    WHERE organization_id = v_org_id
    AND deleted = false
    AND sku = rec.base_sku_pattern
    LIMIT 1;

    -- If base SKU doesn't exist, try to find it with common patterns
    IF v_base_id IS NULL THEN
      -- Try without any suffix
      SELECT id INTO v_base_id
      FROM "CatalogItems"
      WHERE organization_id = v_org_id
      AND deleted = false
      AND sku = rec.base_sku_pattern
      LIMIT 1;
    END IF;

    -- If we found a base SKU, create mapping
    IF v_base_id IS NOT NULL AND rec.color IS NOT NULL THEN
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
      ON CONFLICT (organization_id, base_part_id, hardware_color) WHERE deleted = false
      DO UPDATE SET 
        mapped_part_id = EXCLUDED.mapped_part_id,
        updated_at = now();
      
      v_mapped_count := v_mapped_count + 1;
    END IF;
  END LOOP;

  RAISE NOTICE '  ✅ Created/updated % color mappings', v_mapped_count;

  -- ====================================================
  -- STEP 2: Manual mappings for specific known SKUs
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE 'STEP 2: Creating manual mappings for specific SKUs...';

  -- RC2004 (Adjustable bearing pin)
  SELECT id INTO v_base_id FROM "CatalogItems" WHERE organization_id = v_org_id AND sku = 'RC2004' AND deleted = false LIMIT 1;
  SELECT id INTO v_white_id FROM "CatalogItems" WHERE organization_id = v_org_id AND sku = 'RC2004-W' AND deleted = false LIMIT 1;
  SELECT id INTO v_black_id FROM "CatalogItems" WHERE organization_id = v_org_id AND sku = 'RC2004-BK' AND deleted = false LIMIT 1;
  
  IF v_base_id IS NOT NULL AND v_white_id IS NOT NULL THEN
    INSERT INTO "HardwareColorMapping" (organization_id, base_part_id, hardware_color, mapped_part_id)
    VALUES (v_org_id, v_base_id, 'white', v_white_id)
    ON CONFLICT (organization_id, base_part_id, hardware_color) WHERE deleted = false
    DO UPDATE SET mapped_part_id = EXCLUDED.mapped_part_id;
    RAISE NOTICE '  ✅ Mapped RC2004 -> white';
  END IF;

  IF v_base_id IS NOT NULL AND v_black_id IS NOT NULL THEN
    INSERT INTO "HardwareColorMapping" (organization_id, base_part_id, hardware_color, mapped_part_id)
    VALUES (v_org_id, v_base_id, 'black', v_black_id)
    ON CONFLICT (organization_id, base_part_id, hardware_color) WHERE deleted = false
    DO UPDATE SET mapped_part_id = EXCLUDED.mapped_part_id;
    RAISE NOTICE '  ✅ Mapped RC2004 -> black';
  END IF;

  -- RC2003 (Bearing pin)
  SELECT id INTO v_base_id FROM "CatalogItems" WHERE organization_id = v_org_id AND sku = 'RC2003' AND deleted = false LIMIT 1;
  SELECT id INTO v_white_id FROM "CatalogItems" WHERE organization_id = v_org_id AND sku = 'RC2003-W' AND deleted = false LIMIT 1;
  SELECT id INTO v_black_id FROM "CatalogItems" WHERE organization_id = v_org_id AND sku = 'RC2003-BK' AND deleted = false LIMIT 1;
  
  IF v_base_id IS NOT NULL AND v_white_id IS NOT NULL THEN
    INSERT INTO "HardwareColorMapping" (organization_id, base_part_id, hardware_color, mapped_part_id)
    VALUES (v_org_id, v_base_id, 'white', v_white_id)
    ON CONFLICT (organization_id, base_part_id, hardware_color) WHERE deleted = false
    DO UPDATE SET mapped_part_id = EXCLUDED.mapped_part_id;
    RAISE NOTICE '  ✅ Mapped RC2003 -> white';
  END IF;

  IF v_base_id IS NOT NULL AND v_black_id IS NOT NULL THEN
    INSERT INTO "HardwareColorMapping" (organization_id, base_part_id, hardware_color, mapped_part_id)
    VALUES (v_org_id, v_base_id, 'black', v_black_id)
    ON CONFLICT (organization_id, base_part_id, hardware_color) WHERE deleted = false
    DO UPDATE SET mapped_part_id = EXCLUDED.mapped_part_id;
    RAISE NOTICE '  ✅ Mapped RC2003 -> black';
  END IF;

  -- CC1017 (Ceiling bracket)
  SELECT id INTO v_base_id FROM "CatalogItems" WHERE organization_id = v_org_id AND sku = 'CC1017' AND deleted = false LIMIT 1;
  SELECT id INTO v_white_id FROM "CatalogItems" WHERE organization_id = v_org_id AND sku = 'CC1017-W' AND deleted = false LIMIT 1;
  SELECT id INTO v_black_id FROM "CatalogItems" WHERE organization_id = v_org_id AND sku = 'CC1017-BK' AND deleted = false LIMIT 1;
  
  IF v_base_id IS NOT NULL AND v_white_id IS NOT NULL THEN
    INSERT INTO "HardwareColorMapping" (organization_id, base_part_id, hardware_color, mapped_part_id)
    VALUES (v_org_id, v_base_id, 'white', v_white_id)
    ON CONFLICT (organization_id, base_part_id, hardware_color) WHERE deleted = false
    DO UPDATE SET mapped_part_id = EXCLUDED.mapped_part_id;
    RAISE NOTICE '  ✅ Mapped CC1017 -> white';
  END IF;

  IF v_base_id IS NOT NULL AND v_black_id IS NOT NULL THEN
    INSERT INTO "HardwareColorMapping" (organization_id, base_part_id, hardware_color, mapped_part_id)
    VALUES (v_org_id, v_base_id, 'black', v_black_id)
    ON CONFLICT (organization_id, base_part_id, hardware_color) WHERE deleted = false
    DO UPDATE SET mapped_part_id = EXCLUDED.mapped_part_id;
    RAISE NOTICE '  ✅ Mapped CC1017 -> black';
  END IF;

  -- ====================================================
  -- STEP 3: Create CassettePartsMapping
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE 'STEP 3: Creating CassettePartsMapping...';

  -- Cassette end caps (from your CSV: RC3036-W, RC3037-W, RC3038-W, RC3040-W, RC3041-W, RC3173-W)
  -- These are all white, so we'll map them as cassette end caps
  -- Note: You'll need to determine which shape each belongs to based on your product specs
  
  -- For now, we'll create a generic mapping - you can refine this later
  FOR rec IN (
    SELECT id, sku, item_name
    FROM "CatalogItems"
    WHERE organization_id = v_org_id
    AND deleted = false
    AND item_name ILIKE '%cassette%end%cap%'
  ) LOOP
    -- Map to 'round' shape as default (you can update this later)
    INSERT INTO "CassettePartsMapping" (
      organization_id,
      cassette_shape,
      part_role,
      catalog_item_id,
      qty_per_unit
    )
    VALUES (
      v_org_id,
      'round',  -- Default - update based on your specs
      'endcap_right',  -- Default - you may need left/right
      rec.id,  -- catalog_item_id
      1
    )
    ON CONFLICT (organization_id, cassette_shape, part_role) WHERE deleted = false
    DO UPDATE SET catalog_item_id = EXCLUDED.catalog_item_id;
    
    RAISE NOTICE '  ✅ Mapped cassette end cap: % (shape: round, role: endcap_right)', rec.sku;
  END LOOP;

  -- ====================================================
  -- STEP 4: Summary
  -- ====================================================
  RAISE NOTICE '';
  RAISE NOTICE '✅ BOM Mapping population completed!';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Summary:';
  
  SELECT COUNT(*) INTO v_mapped_count
  FROM "HardwareColorMapping"
  WHERE organization_id = v_org_id
  AND deleted = false;
  
  RAISE NOTICE '  - HardwareColorMapping entries: %', v_mapped_count;
  
  SELECT COUNT(*) INTO v_mapped_count
  FROM "CassettePartsMapping"
  WHERE organization_id = v_org_id
  AND deleted = false;
  
  RAISE NOTICE '  - CassettePartsMapping entries: %', v_mapped_count;
  
  RAISE NOTICE '';
  RAISE NOTICE '📝 Next steps:';
  RAISE NOTICE '   1. Review HardwareColorMapping entries';
  RAISE NOTICE '   2. Update CassettePartsMapping with correct shapes (round/square/L)';
  RAISE NOTICE '   3. Add MotorTubeCompatibility entries';
  RAISE NOTICE '   4. Add more CassettePartsMapping for endcaps_left, clips, etc.';

END $$;

