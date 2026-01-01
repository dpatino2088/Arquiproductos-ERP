-- ====================================================
-- REBUILD BOM MODULE - COMPLETE & CLEAN
-- ====================================================
-- This script rebuilds the BOM module with:
-- 1. 3 Base BOMTemplates (BOTTOM_RAIL_ONLY, SIDE_CHANNEL_ONLY, SIDE_CHANNEL_WITH_BOTTOM_RAIL)
-- 2. Additional components organized by category (TUBO, CASSETTE, DRIVE, BRACKET, etc.)
-- 3. Clear naming and organization
-- ====================================================
-- INSTRUCTIONS:
-- 1. Organization ID and Product Type ID are automatically detected (first active)
-- 2. Verify SKU codes (RCA-04, RC3101, etc.) match your CatalogItems
-- 3. Run this script in Supabase SQL Editor
-- ====================================================

DO $$
DECLARE
  v_organization_id uuid;
  v_product_type_id uuid;
  
  -- BOMTemplate IDs
  v_bottom_rail_only_id uuid;
  v_side_channel_only_id uuid;
  v_side_channel_with_bottom_rail_id uuid;
  
  -- CatalogItem IDs (will be resolved by SKU)
  v_rca_04_id uuid; -- Bottom Rail profile
  v_rca_21_id uuid; -- End Cap
  v_rc3101_id uuid; -- Side Channel profile
  v_rc3102_id uuid; -- Side Channel cover
  v_rcas_09_75_id uuid; -- Insert / gasket
  v_rc3104_id uuid; -- Top Fix Bracket
  
  -- Additional component IDs (to be resolved)
  v_tube_42_id uuid;
  v_tube_65_id uuid;
  v_tube_80_id uuid;
  v_cassette_round_id uuid;
  v_cassette_square_id uuid;
  v_cassette_l_id uuid;
  v_drive_motor_id uuid;
  v_drive_manual_id uuid;
  v_bracket_standard_id uuid;
  
  v_updated_count integer;
  v_resolved_sku text;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'REBUILDING BOM MODULE - COMPLETE';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  
  -- Step 0: Get Organization ID (use first active organization if not specified)
  SELECT id INTO v_organization_id
  FROM "Organizations"
  WHERE deleted = false
  ORDER BY created_at ASC
  LIMIT 1;
  
  IF v_organization_id IS NULL THEN
    RAISE EXCEPTION 'No active organization found. Please ensure at least one organization exists.';
  END IF;
  
  RAISE NOTICE '✅ Using Organization ID: %', v_organization_id;
  
  -- Get Product Type ID (use first active product type for this organization if not specified)
  SELECT id INTO v_product_type_id
  FROM "ProductTypes"
  WHERE organization_id = v_organization_id
    AND deleted = false
  ORDER BY created_at ASC
  LIMIT 1;
  
  IF v_product_type_id IS NULL THEN
    RAISE EXCEPTION 'No active ProductType found for organization %. Please create a ProductType first.', v_organization_id;
  END IF;
  
  RAISE NOTICE '✅ Using Product Type ID: %', v_product_type_id;
  RAISE NOTICE '';
  
  -- Step 1: Soft delete existing BOMTemplates and BOMComponents
  RAISE NOTICE 'Step 1: Cleaning existing BOM data...';
  
  UPDATE "BOMComponents"
  SET deleted = true, updated_at = NOW()
  WHERE organization_id = v_organization_id
    AND deleted = false;
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  RAISE NOTICE '  ✅ Soft deleted % BOMComponents', v_updated_count;
  
  UPDATE "BOMTemplates"
  SET deleted = true, updated_at = NOW()
  WHERE organization_id = v_organization_id
    AND deleted = false;
  
  GET DIAGNOSTICS v_updated_count = ROW_COUNT;
  RAISE NOTICE '  ✅ Soft deleted % BOMTemplates', v_updated_count;
  RAISE NOTICE '';
  
  -- Step 2: Resolve CatalogItem IDs by SKU (with flexible pattern matching for color variants)
  RAISE NOTICE 'Step 2: Resolving CatalogItem IDs by SKU...';
  
  -- Bottom Rail components (buscar con patrones flexibles para variantes de color)
  -- Preferir SKU base o blanco (-W) para usar como base en HardwareColorMapping
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
  
  -- Side Channel components (buscar con patrones flexibles)
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
  
  SELECT id INTO v_rcas_09_75_id FROM "CatalogItems" 
  WHERE (sku = 'RCAS-09-75' OR sku ILIKE 'RCAS-09-75%' OR sku ILIKE 'RCAS0975%')
    AND organization_id = v_organization_id 
    AND deleted = false
  ORDER BY sku
  LIMIT 1;
  
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
  
  -- Additional components (resolve by pattern)
  SELECT id INTO v_tube_42_id FROM "CatalogItems" 
  WHERE (sku ILIKE '%RTU%42%' OR sku ILIKE '%TUBE%42%' OR sku = 'RTU-42') 
    AND organization_id = v_organization_id 
    AND deleted = false
  ORDER BY 
    CASE 
      WHEN sku = 'RTU-42' THEN 1
      ELSE 2
    END
  LIMIT 1;
  
  SELECT id INTO v_tube_65_id FROM "CatalogItems" 
  WHERE (sku ILIKE '%RTU%65%' OR sku ILIKE '%TUBE%65%' OR sku = 'RTU-65') 
    AND organization_id = v_organization_id 
    AND deleted = false
  ORDER BY 
    CASE 
      WHEN sku = 'RTU-65' THEN 1
      ELSE 2
    END
  LIMIT 1;
  
  SELECT id INTO v_tube_80_id FROM "CatalogItems" 
  WHERE (sku ILIKE '%RTU%80%' OR sku ILIKE '%TUBE%80%' OR sku = 'RTU-80') 
    AND organization_id = v_organization_id 
    AND deleted = false
  ORDER BY 
    CASE 
      WHEN sku = 'RTU-80' THEN 1
      ELSE 2
    END
  LIMIT 1;
  
  -- Log resolved SKUs
  RAISE NOTICE '  ✅ CatalogItem IDs resolved:';
  IF v_rca_04_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_rca_04_id;
    RAISE NOTICE '    - RCA-04: % (ID: %)', v_resolved_sku, v_rca_04_id;
  ELSE
    RAISE WARNING '    - RCA-04: NOT FOUND';
  END IF;
  
  IF v_rca_21_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_rca_21_id;
    RAISE NOTICE '    - RCA-21: % (ID: %)', v_resolved_sku, v_rca_21_id;
  ELSE
    RAISE WARNING '    - RCA-21: NOT FOUND';
  END IF;
  
  IF v_rc3101_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_rc3101_id;
    RAISE NOTICE '    - RC3101: % (ID: %)', v_resolved_sku, v_rc3101_id;
  ELSE
    RAISE WARNING '    - RC3101: NOT FOUND';
  END IF;
  
  IF v_rc3102_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_rc3102_id;
    RAISE NOTICE '    - RC3102: % (ID: %)', v_resolved_sku, v_rc3102_id;
  ELSE
    RAISE WARNING '    - RC3102: NOT FOUND';
  END IF;
  
  IF v_rcas_09_75_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_rcas_09_75_id;
    RAISE NOTICE '    - RCAS-09-75: % (ID: %)', v_resolved_sku, v_rcas_09_75_id;
  ELSE
    RAISE WARNING '    - RCAS-09-75: NOT FOUND';
  END IF;
  
  IF v_rc3104_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_rc3104_id;
    RAISE NOTICE '    - RC3104: % (ID: %)', v_resolved_sku, v_rc3104_id;
  ELSE
    RAISE WARNING '    - RC3104: NOT FOUND';
  END IF;
  
  IF v_tube_42_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_tube_42_id;
    RAISE NOTICE '    - Tube 42mm: % (ID: %)', v_resolved_sku, v_tube_42_id;
  END IF;
  
  IF v_tube_65_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_tube_65_id;
    RAISE NOTICE '    - Tube 65mm: % (ID: %)', v_resolved_sku, v_tube_65_id;
  END IF;
  
  IF v_tube_80_id IS NOT NULL THEN
    SELECT sku INTO v_resolved_sku FROM "CatalogItems" WHERE id = v_tube_80_id;
    RAISE NOTICE '    - Tube 80mm: % (ID: %)', v_resolved_sku, v_tube_80_id;
  END IF;
  
  RAISE NOTICE '';
  
  -- Step 3: Create BOMTemplates
  RAISE NOTICE 'Step 3: Creating BOMTemplates...';
  
  -- BOMTemplate 1: BOTTOM_RAIL_ONLY
  INSERT INTO "BOMTemplates" (
    organization_id,
    product_type_id,
    name,
    description,
    active,
    created_at,
    updated_at,
    deleted
  ) VALUES (
    v_organization_id,
    v_product_type_id,
    'BOTTOM_RAIL_ONLY',
    'BOM Template for Bottom Rail only configuration',
    true,
    NOW(),
    NOW(),
    false
  ) RETURNING id INTO v_bottom_rail_only_id;
  
  RAISE NOTICE '  ✅ Created BOMTemplate: BOTTOM_RAIL_ONLY (ID: %)', v_bottom_rail_only_id;
  
  -- BOMTemplate 2: SIDE_CHANNEL_ONLY
  INSERT INTO "BOMTemplates" (
    organization_id,
    product_type_id,
    name,
    description,
    active,
    created_at,
    updated_at,
    deleted
  ) VALUES (
    v_organization_id,
    v_product_type_id,
    'SIDE_CHANNEL_ONLY',
    'BOM Template for Side Channel only configuration',
    true,
    NOW(),
    NOW(),
    false
  ) RETURNING id INTO v_side_channel_only_id;
  
  RAISE NOTICE '  ✅ Created BOMTemplate: SIDE_CHANNEL_ONLY (ID: %)', v_side_channel_only_id;
  
  -- BOMTemplate 3: SIDE_CHANNEL_WITH_BOTTOM_RAIL
  INSERT INTO "BOMTemplates" (
    organization_id,
    product_type_id,
    name,
    description,
    active,
    created_at,
    updated_at,
    deleted
  ) VALUES (
    v_organization_id,
    v_product_type_id,
    'SIDE_CHANNEL_WITH_BOTTOM_RAIL',
    'BOM Template for Side Channel + Bottom Rail configuration',
    true,
    NOW(),
    NOW(),
    false
  ) RETURNING id INTO v_side_channel_with_bottom_rail_id;
  
  RAISE NOTICE '  ✅ Created BOMTemplate: SIDE_CHANNEL_WITH_BOTTOM_RAIL (ID: %)', v_side_channel_with_bottom_rail_id;
  RAISE NOTICE '';
  
  -- Step 4: Create BOMComponents for BOTTOM_RAIL_ONLY
  RAISE NOTICE 'Step 4: Creating BOMComponents for BOTTOM_RAIL_ONLY...';
  
  -- Category: BOTTOM_RAIL (Bottom Rail Profile - Standard)
  -- Note: RCA-04 puede ser blanco/negro (applies_color = true) y wrapped/standard (block_condition)
  IF v_rca_04_id IS NOT NULL THEN
    -- Standard Bottom Rail Profile
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_bottom_rail_only_id,
      'bottom_rail_profile',
      'bottom_rail',
      jsonb_build_object('bottom_rail_type', 'standard'),
      true, -- Aplica color (blanco/negro) via HardwareColorMapping
      v_rca_04_id,
      false,
      1,
      'm',
      10,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added bottom_rail_profile (RCA-04) - Standard, applies_color = true';
    
    -- Wrapped Bottom Rail Profile
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_bottom_rail_only_id,
      'bottom_rail_profile',
      'bottom_rail',
      jsonb_build_object('bottom_rail_type', 'wrapped'),
      true, -- Aplica color (blanco/negro) via HardwareColorMapping
      v_rca_04_id,
      false,
      1,
      'm',
      11,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added bottom_rail_profile (RCA-04) - Wrapped, applies_color = true';
  ELSE
    RAISE WARNING '  ⚠️  SKU RCA-04 not found - skipping bottom_rail_profile components';
  END IF;
  
  -- Category: BOTTOM_RAIL (Bottom Rail End Cap)
  -- Note: RCA-21 es el End Cap del Bottom Rail Profile (RCA-04)
  IF v_rca_21_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_bottom_rail_only_id,
      'bottom_rail_end_cap',
      'bottom_rail',
      NULL,
      false,
      v_rca_21_id,
      false,
      2,
      'ea',
      20,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added bottom_rail_end_cap (RCA-21)';
  ELSE
    RAISE WARNING '  ⚠️  SKU RCA-21 not found - skipping bottom_rail_end_cap component';
  END IF;
  
  RAISE NOTICE '  ✅ Completed BOMComponents for BOTTOM_RAIL_ONLY';
  RAISE NOTICE '';
  
  -- Step 5: Create BOMComponents for SIDE_CHANNEL_ONLY
  RAISE NOTICE 'Step 5: Creating BOMComponents for SIDE_CHANNEL_ONLY...';
  
  -- Category: SIDE_CHANNEL
  IF v_rc3101_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_side_channel_only_id,
      'side_channel_profile',
      'side_channel',
      jsonb_build_object('side_channel', true, 'side_channel_type', 'side_only'),
      false,
      v_rc3101_id,
      false,
      1,
      'm',
      10,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added side_channel_profile (RC3101)';
  ELSE
    RAISE WARNING '  ⚠️  SKU RC3101 not found - skipping side_channel_profile component';
  END IF;
  
  IF v_rc3102_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_side_channel_only_id,
      NULL, -- side_channel_cover (no specific role, using NULL)
      'side_channel',
      jsonb_build_object('side_channel', true, 'side_channel_type', 'side_only'),
      false,
      v_rc3102_id,
      false,
      1,
      'm',
      20,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added side_channel_cover (RC3102) - Accesorio de Side Channel';
  ELSE
    RAISE WARNING '  ⚠️  SKU RC3102 not found - skipping side_channel_cover component';
  END IF;
  
  -- Category: ACCESSORY (component_role = NULL, block_type = NULL for accessories)
  -- Note: 'accessory' is not a valid component_role, using NULL instead
  IF v_rcas_09_75_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_side_channel_only_id,
      NULL,
      NULL,
      NULL,
      false,
      v_rcas_09_75_id,
      false,
      2,
      'ea',
      30,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added accessory (RCAS-09-75)';
  ELSE
    RAISE WARNING '  ⚠️  SKU RCAS-09-75 not found - skipping accessory component';
  END IF;
  
  -- Category: BRACKET (block_type = 'brackets' - note: plural)
  IF v_rc3104_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_side_channel_only_id,
      'bracket',
      'brackets',
      NULL,
      true,
      v_rc3104_id,
      false,
      2,
      'ea',
      40,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added bracket (RC3104)';
  ELSE
    RAISE WARNING '  ⚠️  SKU RC3104 not found - skipping bracket component';
  END IF;
  
  RAISE NOTICE '  ✅ Completed BOMComponents for SIDE_CHANNEL_ONLY';
  RAISE NOTICE '';
  
  -- Step 6: Create BOMComponents for SIDE_CHANNEL_WITH_BOTTOM_RAIL
  RAISE NOTICE 'Step 6: Creating BOMComponents for SIDE_CHANNEL_WITH_BOTTOM_RAIL...';
  
  -- Category: SIDE_CHANNEL (from SIDE_CHANNEL_ONLY)
  IF v_rc3101_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_side_channel_with_bottom_rail_id,
      'side_channel_profile',
      'side_channel',
      jsonb_build_object('side_channel', true, 'side_channel_type', 'side_and_bottom'),
      false,
      v_rc3101_id,
      false,
      1,
      'm',
      10,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added side_channel_profile (RC3101)';
  ELSE
    RAISE WARNING '  ⚠️  SKU RC3101 not found - skipping side_channel_profile component';
  END IF;
  
  IF v_rc3102_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_side_channel_with_bottom_rail_id,
      NULL, -- side_channel_cover (no specific role, using NULL)
      'side_channel',
      jsonb_build_object('side_channel', true, 'side_channel_type', 'side_and_bottom'),
      false,
      v_rc3102_id,
      false,
      1,
      'm',
      20,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added side_channel_cover (RC3102) - Accesorio de Side Channel';
  ELSE
    RAISE WARNING '  ⚠️  SKU RC3102 not found - skipping side_channel_cover component';
  END IF;
  
  -- Category: BOTTOM_RAIL (Bottom Rail Profile - Standard)
  -- Note: RCA-04 puede ser blanco/negro (applies_color = true) y wrapped/standard (block_condition)
  -- NO tiene relación con Side Channel, solo con bottom_rail_type
  IF v_rca_04_id IS NOT NULL THEN
    -- Standard Bottom Rail Profile
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_side_channel_with_bottom_rail_id,
      'bottom_rail_profile',
      'bottom_rail',
      jsonb_build_object('bottom_rail_type', 'standard'),
      true, -- Aplica color (blanco/negro) via HardwareColorMapping
      v_rca_04_id,
      false,
      1,
      'm',
      30,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added bottom_rail_profile (RCA-04) - Standard, applies_color = true';
    
    -- Wrapped Bottom Rail Profile
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_side_channel_with_bottom_rail_id,
      'bottom_rail_profile',
      'bottom_rail',
      jsonb_build_object('bottom_rail_type', 'wrapped'),
      true, -- Aplica color (blanco/negro) via HardwareColorMapping
      v_rca_04_id,
      false,
      1,
      'm',
      31,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added bottom_rail_profile (RCA-04) - Wrapped, applies_color = true';
  ELSE
    RAISE WARNING '  ⚠️  SKU RCA-04 not found - skipping bottom_rail_profile components';
  END IF;
  
  -- Category: ACCESSORY
  IF v_rcas_09_75_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_side_channel_with_bottom_rail_id,
      NULL,
      NULL,
      NULL,
      false,
      v_rcas_09_75_id,
      false,
      2,
      'ea',
      40,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added accessory (RCAS-09-75)';
  ELSE
    RAISE WARNING '  ⚠️  SKU RCAS-09-75 not found - skipping accessory component';
  END IF;
  
  -- Category: BOTTOM_RAIL (Bottom Rail End Cap)
  -- Note: RCA-21 es el End Cap del Bottom Rail Profile (RCA-04), NO tiene relación con Side Channel
  IF v_rca_21_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_side_channel_with_bottom_rail_id,
      'bottom_rail_end_cap',
      'bottom_rail',
      NULL, -- Bottom Rail es independiente de Side Channel
      false,
      v_rca_21_id,
      false,
      2,
      'ea',
      50,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added bottom_rail_end_cap (RCA-21)';
  ELSE
    RAISE WARNING '  ⚠️  SKU RCA-21 not found - skipping bottom_rail_end_cap component';
  END IF;
  
  -- Category: BRACKET
  IF v_rc3104_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    ) VALUES (
      v_organization_id,
      v_side_channel_with_bottom_rail_id,
      'bracket',
      'brackets',
      NULL,
      true,
      v_rc3104_id,
      false,
      2,
      'ea',
      60,
      NOW(),
      NOW(),
      false
    );
    RAISE NOTICE '  ✅ Added bracket (RC3104)';
  ELSE
    RAISE WARNING '  ⚠️  SKU RC3104 not found - skipping bracket component';
  END IF;
  
  RAISE NOTICE '  ✅ Completed BOMComponents for SIDE_CHANNEL_WITH_BOTTOM_RAIL';
  RAISE NOTICE '';
  
  -- Step 7: Add additional components organized by category (if CatalogItems exist)
  RAISE NOTICE 'Step 7: Adding additional components by category...';
  
  -- Category: TUBO (TUBE) - Auto-select by width rule
  -- Add to all 3 templates
  INSERT INTO "BOMComponents" (
    organization_id,
    bom_template_id,
    component_role,
    block_type,
    block_condition,
    applies_color,
    component_item_id,
    auto_select,
    sku_resolution_rule,
    qty_per_unit,
    uom,
    sequence_order,
    created_at,
    updated_at,
    deleted
  ) VALUES 
  (
    v_organization_id,
    v_bottom_rail_only_id,
    'tube',
    NULL,
    NULL,
    false,
    NULL,
    true,
    'width_rule_42_65_80',
    1,
    'm',
    5,
    NOW(),
    NOW(),
    false
  ),
  (
    v_organization_id,
    v_side_channel_only_id,
    'tube',
    NULL,
    NULL,
    false,
    NULL,
    true,
    'width_rule_42_65_80',
    1,
    'm',
    5,
    NOW(),
    NOW(),
    false
  ),
  (
    v_organization_id,
    v_side_channel_with_bottom_rail_id,
    'tube',
    NULL,
    NULL,
    false,
    NULL,
    true,
    'width_rule_42_65_80',
    1,
    'm',
    5,
    NOW(),
    NOW(),
    false
  );
  
  RAISE NOTICE '  ✅ Added TUBO (tube) components with auto-select rule to all templates';
  
  -- Category: DRIVE (Operating System Drive)
  -- Note: Estos componentes requieren component_item_id base para HardwareColorMapping
  -- Si no tienes los SKUs base, comenta estas secciones o usa auto_select = true
  -- Motor drive (conditional - only when drive_type = 'motor')
  -- IMPORTANTE: Necesitas un SKU base de motor para que HardwareColorMapping funcione
  -- Si v_drive_motor_id es NULL, este componente no se agregará
  IF v_drive_motor_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    )
    SELECT 
      v_organization_id,
      bt.id,
      'operating_system_drive',
      'drive',
      jsonb_build_object('drive_type', 'motor'),
      true, -- Aplica color via HardwareColorMapping
      v_drive_motor_id, -- SKU base del motor (blanco por defecto)
      false,
      1,
      'ea',
      1,
      NOW(),
      NOW(),
      false
    FROM "BOMTemplates" bt
    WHERE bt.organization_id = v_organization_id
      AND bt.deleted = false
      AND bt.id IN (v_bottom_rail_only_id, v_side_channel_only_id, v_side_channel_with_bottom_rail_id);
    
    RAISE NOTICE '  ✅ Added DRIVE (motor) components with block_condition and color mapping';
  ELSE
    RAISE WARNING '  ⚠️  Motor drive SKU not found - skipping motor drive components. Set v_drive_motor_id to add motor drives.';
  END IF;
  
  -- Manual drive (conditional - only when drive_type = 'manual')
  -- IMPORTANTE: Necesitas un SKU base de manual drive
  IF v_drive_manual_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    )
    SELECT 
      v_organization_id,
      bt.id,
      'operating_system_drive',
      'drive',
      jsonb_build_object('drive_type', 'manual'),
      false,
      v_drive_manual_id, -- SKU del manual drive
      false,
      1,
      'ea',
      2,
      NOW(),
      NOW(),
      false
    FROM "BOMTemplates" bt
    WHERE bt.organization_id = v_organization_id
      AND bt.deleted = false
      AND bt.id IN (v_bottom_rail_only_id, v_side_channel_only_id, v_side_channel_with_bottom_rail_id);
    
    RAISE NOTICE '  ✅ Added DRIVE (manual) components with block_condition';
  ELSE
    RAISE WARNING '  ⚠️  Manual drive SKU not found - skipping manual drive components. Set v_drive_manual_id to add manual drives.';
  END IF;
  
  -- Category: CASSETTE
  -- Note: Estos componentes requieren component_item_id base
  -- Round cassette (conditional - only when cassette = true AND cassette_type = 'round')
  IF v_cassette_round_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    )
    SELECT 
      v_organization_id,
      bt.id,
      'cassette',
      'cassette',
      jsonb_build_object('cassette', true, 'cassette_type', 'round'),
      false,
      v_cassette_round_id,
      false,
      1,
      'm',
      15,
      NOW(),
      NOW(),
      false
    FROM "BOMTemplates" bt
    WHERE bt.organization_id = v_organization_id
      AND bt.deleted = false
      AND bt.id IN (v_bottom_rail_only_id, v_side_channel_only_id, v_side_channel_with_bottom_rail_id);
    
    RAISE NOTICE '  ✅ Added CASSETTE (round) components with block_condition';
  ELSE
    RAISE WARNING '  ⚠️  Round cassette SKU not found - skipping round cassette components. Set v_cassette_round_id to add round cassettes.';
  END IF;
  
  -- Square cassette (conditional - only when cassette = true AND cassette_type = 'square')
  IF v_cassette_square_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    )
    SELECT 
      v_organization_id,
      bt.id,
      'cassette',
      'cassette',
      jsonb_build_object('cassette', true, 'cassette_type', 'square'),
      false,
      v_cassette_square_id,
      false,
      1,
      'm',
      16,
      NOW(),
      NOW(),
      false
    FROM "BOMTemplates" bt
    WHERE bt.organization_id = v_organization_id
      AND bt.deleted = false
      AND bt.id IN (v_bottom_rail_only_id, v_side_channel_only_id, v_side_channel_with_bottom_rail_id);
    
    RAISE NOTICE '  ✅ Added CASSETTE (square) components with block_condition';
  ELSE
    RAISE WARNING '  ⚠️  Square cassette SKU not found - skipping square cassette components. Set v_cassette_square_id to add square cassettes.';
  END IF;
  
  -- L-shape cassette (conditional - only when cassette = true AND cassette_type = 'l-shape')
  IF v_cassette_l_id IS NOT NULL THEN
    INSERT INTO "BOMComponents" (
      organization_id,
      bom_template_id,
      component_role,
      block_type,
      block_condition,
      applies_color,
      component_item_id,
      auto_select,
      qty_per_unit,
      uom,
      sequence_order,
      created_at,
      updated_at,
      deleted
    )
    SELECT 
      v_organization_id,
      bt.id,
      'cassette',
      'cassette',
      jsonb_build_object('cassette', true, 'cassette_type', 'l-shape'),
      false,
      v_cassette_l_id,
      false,
      1,
      'm',
      17,
      NOW(),
      NOW(),
      false
    FROM "BOMTemplates" bt
    WHERE bt.organization_id = v_organization_id
      AND bt.deleted = false
      AND bt.id IN (v_bottom_rail_only_id, v_side_channel_only_id, v_side_channel_with_bottom_rail_id);
    
    RAISE NOTICE '  ✅ Added CASSETTE (l-shape) components with block_condition';
  ELSE
    RAISE WARNING '  ⚠️  L-shape cassette SKU not found - skipping l-shape cassette components. Set v_cassette_l_id to add l-shape cassettes.';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✨ BOM MODULE REBUILD COMPLETED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE '';
  RAISE NOTICE 'Summary:';
  RAISE NOTICE '  - 3 BOMTemplates created';
  RAISE NOTICE '  - Components organized by category:';
  RAISE NOTICE '    • TUBO (tube)';
  RAISE NOTICE '    • CASSETTE';
  RAISE NOTICE '    • DRIVE (operating_system_drive)';
  RAISE NOTICE '    • BRACKET';
  RAISE NOTICE '    • BOTTOM_RAIL (bottom_channel)';
  RAISE NOTICE '    • SIDE_CHANNEL (side_channel_profile, side_channel_cover)';
  RAISE NOTICE '    • ACCESSORY';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '  1. Verify CatalogItem IDs are correctly resolved';
  RAISE NOTICE '  2. Update component_item_id for components that need direct mapping';
  RAISE NOTICE '  3. Test BOM generation by configuring a quote line';
  RAISE NOTICE '';
  
END $$;

-- Verification query
SELECT 
  'Verification: BOMTemplates' as check_name,
  bt.name as template_name,
  bt.active,
  COUNT(bc.id) as component_count,
  STRING_AGG(DISTINCT bc.block_type, ', ' ORDER BY bc.block_type) as categories,
  STRING_AGG(DISTINCT bc.component_role, ', ' ORDER BY bc.component_role) as component_roles
FROM "BOMTemplates" bt
LEFT JOIN "BOMComponents" bc ON bc.bom_template_id = bt.id AND bc.deleted = false
WHERE bt.organization_id = (
  SELECT id FROM "Organizations" WHERE deleted = false ORDER BY created_at ASC LIMIT 1
)
  AND bt.deleted = false
GROUP BY bt.id, bt.name, bt.active
ORDER BY bt.name;

