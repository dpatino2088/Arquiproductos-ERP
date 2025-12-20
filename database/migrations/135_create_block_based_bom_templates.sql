-- ====================================================
-- Migration: Create Block-Based BOM Templates
-- ====================================================
-- This creates BOMTemplates with block-based structure
-- Each template has multiple components per color (Option B)
-- Blocks: Drive, Brackets, Bottom Rail, Cassette, Side Channel
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
  v_roller_shade_product_type_id uuid;
  v_dual_shade_product_type_id uuid;
  v_triple_shade_product_type_id uuid;
  v_roller_white_template_id uuid;
  v_roller_black_template_id uuid;
  v_dual_white_template_id uuid;
  v_dual_black_template_id uuid;
  v_triple_white_template_id uuid;
  v_triple_black_template_id uuid;
  
  -- Placeholder SKU IDs (you'll need to replace these with actual CatalogItem IDs)
  -- For now, we'll use NULL and let the system resolve them by rules or manual assignment
  v_motor_sku_id uuid := NULL;
  v_motor_adapter_sku_id uuid := NULL;
  v_adapter_end_plug_sku_id uuid := NULL;
  v_end_plug_sku_id uuid := NULL;
  v_clutch_sku_id uuid := NULL;
  v_clutch_adapter_sku_id uuid := NULL;
  v_bracket_white_sku_id uuid := NULL;
  v_bracket_black_sku_id uuid := NULL;
  v_bracket_end_cap_white_sku_id uuid := NULL;
  v_bracket_end_cap_black_sku_id uuid := NULL;
  v_screw_end_cap_sku_id uuid := NULL;
  v_bottom_rail_standard_white_sku_id uuid := NULL;
  v_bottom_rail_standard_black_sku_id uuid := NULL;
  v_bottom_rail_wrapped_white_sku_id uuid := NULL;
  v_bottom_rail_wrapped_black_sku_id uuid := NULL;
  v_bottom_rail_end_cap_white_sku_id uuid := NULL;
  v_bottom_rail_end_cap_black_sku_id uuid := NULL;
  v_cassette_white_sku_id uuid := NULL;
  v_cassette_black_sku_id uuid := NULL;
  v_cassette_end_cap_white_sku_id uuid := NULL;
  v_cassette_end_cap_black_sku_id uuid := NULL;
BEGIN
  RAISE NOTICE '🔧 Creating Block-Based BOM Templates...';
  RAISE NOTICE '';

  -- Get organization ID (assuming first active organization)
  SELECT id INTO v_org_id
  FROM "Organizations"
  WHERE deleted = false
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'No active organization found';
  END IF;

  RAISE NOTICE '  ✅ Using organization: %', v_org_id;

  -- Find ProductTypes
  SELECT id INTO v_roller_shade_product_type_id
  FROM "ProductTypes"
  WHERE organization_id = v_org_id
  AND (name ILIKE '%roller%shade%' OR code ILIKE '%roller-shade%')
  AND deleted = false
  LIMIT 1;

  SELECT id INTO v_dual_shade_product_type_id
  FROM "ProductTypes"
  WHERE organization_id = v_org_id
  AND (name ILIKE '%dual%shade%' OR code ILIKE '%dual-shade%')
  AND deleted = false
  LIMIT 1;

  SELECT id INTO v_triple_shade_product_type_id
  FROM "ProductTypes"
  WHERE organization_id = v_org_id
  AND (name ILIKE '%triple%shade%' OR code ILIKE '%triple-shade%')
  AND deleted = false
  LIMIT 1;

  IF v_roller_shade_product_type_id IS NULL THEN
    RAISE WARNING 'Roller Shade ProductType not found - creating template will be skipped';
  END IF;

  IF v_dual_shade_product_type_id IS NULL THEN
    RAISE WARNING 'Dual Shade ProductType not found - creating template will be skipped';
  END IF;

  IF v_triple_shade_product_type_id IS NULL THEN
    RAISE WARNING 'Triple Shade ProductType not found - creating template will be skipped';
  END IF;

  -- ====================================================
  -- STEP 1: Create BOMTemplates (mark old ones as deleted)
  -- ====================================================
  RAISE NOTICE 'STEP 1: Creating BOMTemplates...';

  -- Mark existing templates as deleted (optional - comment out if you want to keep them)
  -- UPDATE "BOMTemplates" SET deleted = true WHERE organization_id = v_org_id;

  -- Roller Shade - White
  IF v_roller_shade_product_type_id IS NOT NULL THEN
    INSERT INTO "BOMTemplates" (
      organization_id,
      product_type_id,
      name,
      description,
      active,
      deleted
    )
    VALUES (
      v_org_id,
      v_roller_shade_product_type_id,
      'Roller Shade - White',
      'Block-based BOM template for Roller Shade with White hardware',
      true,
      false
    )
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_roller_white_template_id;

    IF v_roller_white_template_id IS NULL THEN
      SELECT id INTO v_roller_white_template_id
      FROM "BOMTemplates"
      WHERE organization_id = v_org_id
      AND product_type_id = v_roller_shade_product_type_id
      AND name = 'Roller Shade - White'
      AND deleted = false;
    END IF;

    RAISE NOTICE '  ✅ Created Roller Shade - White template: %', v_roller_white_template_id;
  END IF;

  -- Roller Shade - Black
  IF v_roller_shade_product_type_id IS NOT NULL THEN
    INSERT INTO "BOMTemplates" (
      organization_id,
      product_type_id,
      name,
      description,
      active,
      deleted
    )
    VALUES (
      v_org_id,
      v_roller_shade_product_type_id,
      'Roller Shade - Black',
      'Block-based BOM template for Roller Shade with Black hardware',
      true,
      false
    )
    ON CONFLICT DO NOTHING
    RETURNING id INTO v_roller_black_template_id;

    IF v_roller_black_template_id IS NULL THEN
      SELECT id INTO v_roller_black_template_id
      FROM "BOMTemplates"
      WHERE organization_id = v_org_id
      AND product_type_id = v_roller_shade_product_type_id
      AND name = 'Roller Shade - Black'
      AND deleted = false;
    END IF;

    RAISE NOTICE '  ✅ Created Roller Shade - Black template: %', v_roller_black_template_id;
  END IF;

  -- Similar for Dual and Triple Shades...
  -- (I'll create a helper function to avoid repetition)

  -- ====================================================
  -- STEP 2: Create BOMComponents for Roller Shade - White
  -- ====================================================
  IF v_roller_white_template_id IS NOT NULL THEN
    RAISE NOTICE '';
    RAISE NOTICE 'STEP 2: Creating BOMComponents for Roller Shade - White...';

    -- BLOCK 1: Drive (Motor)
    -- Motor SKU
    -- NOTE: If component_item_id is NULL, auto_select must be true
    INSERT INTO "BOMComponents" (
      bom_template_id,
      organization_id,
      block_type,
      block_condition,
      component_role,
      component_item_id,
      qty_per_unit,
      uom,
      applies_color,
      hardware_color,
      sku_resolution_rule,
      auto_select,
      sequence_order,
      deleted
    )
    VALUES (
      v_roller_white_template_id,
      v_org_id,
      'drive',
      '{"drive_type": "motor"}'::jsonb,
      'motor',
      v_motor_sku_id,
      1,
      'unit',
      false,
      NULL,
      'direct',
      CASE WHEN v_motor_sku_id IS NULL THEN true ELSE false END,
      1,
      false
    );

    -- Motor Adapter SKU
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'drive', '{"drive_type": "motor"}'::jsonb,
      'motor_adapter', v_motor_adapter_sku_id, 1, 'unit',
      false, NULL, 'direct', CASE WHEN v_motor_adapter_sku_id IS NULL THEN true ELSE false END, 2, false
    );

    -- Adapter End Plug SKU
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'drive', '{"drive_type": "motor"}'::jsonb,
      'adapter_end_plug', v_adapter_end_plug_sku_id, 1, 'unit',
      false, NULL, 'direct', CASE WHEN v_adapter_end_plug_sku_id IS NULL THEN true ELSE false END, 3, false
    );

    -- End Plug SKU
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'drive', '{"drive_type": "motor"}'::jsonb,
      'end_plug', v_end_plug_sku_id, 1, 'unit',
      false, NULL, 'direct', CASE WHEN v_end_plug_sku_id IS NULL THEN true ELSE false END, 4, false
    );

    -- Tube SKU (resolved by width rule)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'drive', '{"drive_type": "motor"}'::jsonb,
      'tube', NULL, 1, 'linear_m',
      false, NULL, 'width_rule_42_65_80', true, 5, false
    );

    -- BLOCK 1: Drive (Manual)
    -- Clutch SKU
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'drive', '{"drive_type": "manual"}'::jsonb,
      'clutch', v_clutch_sku_id, 1, 'unit',
      false, NULL, 'direct', CASE WHEN v_clutch_sku_id IS NULL THEN true ELSE false END, 1, false
    );

    -- Clutch Adapter SKU
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'drive', '{"drive_type": "manual"}'::jsonb,
      'clutch_adapter', v_clutch_adapter_sku_id, 1, 'unit',
      false, NULL, 'direct', CASE WHEN v_clutch_adapter_sku_id IS NULL THEN true ELSE false END, 2, false
    );

    -- End Plug SKU
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'drive', '{"drive_type": "manual"}'::jsonb,
      'end_plug', v_end_plug_sku_id, 1, 'unit',
      false, NULL, 'direct', CASE WHEN v_end_plug_sku_id IS NULL THEN true ELSE false END, 3, false
    );

    -- Tube SKU (resolved by width rule)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'drive', '{"drive_type": "manual"}'::jsonb,
      'tube', NULL, 1, 'linear_m',
      false, NULL, 'width_rule_42_65_80', true, 4, false
    );

    -- BLOCK 2: Brackets (always active, multiple colors)
    -- Bracket White
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'brackets', NULL,
      'bracket', v_bracket_white_sku_id, 2, 'unit',
      true, 'white', 'direct', CASE WHEN v_bracket_white_sku_id IS NULL THEN true ELSE false END, 1, false
    );

    -- Bracket Black
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'brackets', NULL,
      'bracket', v_bracket_black_sku_id, 2, 'unit',
      true, 'black', 'direct', CASE WHEN v_bracket_black_sku_id IS NULL THEN true ELSE false END, 1, false
    );

    -- Bracket End Cap White
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'brackets', NULL,
      'bracket_end_cap', v_bracket_end_cap_white_sku_id, 2, 'unit',
      true, 'white', 'direct', CASE WHEN v_bracket_end_cap_white_sku_id IS NULL THEN true ELSE false END, 2, false
    );

    -- Bracket End Cap Black
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'brackets', NULL,
      'bracket_end_cap', v_bracket_end_cap_black_sku_id, 2, 'unit',
      true, 'black', 'direct', CASE WHEN v_bracket_end_cap_black_sku_id IS NULL THEN true ELSE false END, 2, false
    );

    -- Screw End Cap (no color)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'brackets', NULL,
      'screw_end_cap', v_screw_end_cap_sku_id, 2, 'unit',
      false, NULL, 'direct', CASE WHEN v_screw_end_cap_sku_id IS NULL THEN true ELSE false END, 3, false
    );

    -- BLOCK 3: Bottom Rail (Standard - White)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'bottom_rail', '{"bottom_rail_type": "standard"}'::jsonb,
      'bottom_rail_profile', v_bottom_rail_standard_white_sku_id, 1, 'linear_m',
      true, 'white', 'direct', CASE WHEN v_bottom_rail_standard_white_sku_id IS NULL THEN true ELSE false END, 1, false
    );

    -- Bottom Rail (Standard - Black)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'bottom_rail', '{"bottom_rail_type": "standard"}'::jsonb,
      'bottom_rail_profile', v_bottom_rail_standard_black_sku_id, 1, 'linear_m',
      true, 'black', 'direct', CASE WHEN v_bottom_rail_standard_black_sku_id IS NULL THEN true ELSE false END, 1, false
    );

    -- Bottom Rail End Caps (Standard - White)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'bottom_rail', '{"bottom_rail_type": "standard"}'::jsonb,
      'bottom_rail_end_cap', v_bottom_rail_end_cap_white_sku_id, 2, 'unit',
      true, 'white', 'direct', CASE WHEN v_bottom_rail_end_cap_white_sku_id IS NULL THEN true ELSE false END, 2, false
    );

    -- Bottom Rail End Caps (Standard - Black)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'bottom_rail', '{"bottom_rail_type": "standard"}'::jsonb,
      'bottom_rail_end_cap', v_bottom_rail_end_cap_black_sku_id, 2, 'unit',
      true, 'black', 'direct', CASE WHEN v_bottom_rail_end_cap_black_sku_id IS NULL THEN true ELSE false END, 2, false
    );

    -- Bottom Rail (Wrapped - White)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'bottom_rail', '{"bottom_rail_type": "wrapped"}'::jsonb,
      'bottom_rail_profile', v_bottom_rail_wrapped_white_sku_id, 1, 'linear_m',
      true, 'white', 'direct', CASE WHEN v_bottom_rail_wrapped_white_sku_id IS NULL THEN true ELSE false END, 1, false
    );

    -- Bottom Rail (Wrapped - Black)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'bottom_rail', '{"bottom_rail_type": "wrapped"}'::jsonb,
      'bottom_rail_profile', v_bottom_rail_wrapped_black_sku_id, 1, 'linear_m',
      true, 'black', 'direct', CASE WHEN v_bottom_rail_wrapped_black_sku_id IS NULL THEN true ELSE false END, 1, false
    );

    -- BLOCK 4: Cassette (optional - White)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'cassette', '{"cassette": true}'::jsonb,
      'cassette_profile', v_cassette_white_sku_id, 1, 'linear_m',
      true, 'white', 'direct', CASE WHEN v_cassette_white_sku_id IS NULL THEN true ELSE false END, 1, false
    );

    -- Cassette (optional - Black)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'cassette', '{"cassette": true}'::jsonb,
      'cassette_profile', v_cassette_black_sku_id, 1, 'linear_m',
      true, 'black', 'direct', CASE WHEN v_cassette_black_sku_id IS NULL THEN true ELSE false END, 1, false
    );

    -- Cassette End Caps (White)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'cassette', '{"cassette": true}'::jsonb,
      'cassette_end_cap', v_cassette_end_cap_white_sku_id, 2, 'unit',
      true, 'white', 'direct', CASE WHEN v_cassette_end_cap_white_sku_id IS NULL THEN true ELSE false END, 2, false
    );

    -- Cassette End Caps (Black)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_roller_white_template_id, v_org_id, 'cassette', '{"cassette": true}'::jsonb,
      'cassette_end_cap', v_cassette_end_cap_black_sku_id, 2, 'unit',
      true, 'black', 'direct', CASE WHEN v_cassette_end_cap_black_sku_id IS NULL THEN true ELSE false END, 2, false
    );

    RAISE NOTICE '  ✅ Created BOMComponents for Roller Shade - White';
  END IF;

  -- NOTE: Repeat similar structure for:
  -- - Roller Shade - Black (v_roller_black_template_id)
  -- - Dual Shade - White/Black
  -- - Triple Shade - White/Black
  -- For brevity, I'm showing the pattern. You can duplicate and modify for other templates.

  RAISE NOTICE '';
  RAISE NOTICE '✅ Block-Based BOM Templates created!';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  IMPORTANT: You need to update the SKU IDs (v_*_sku_id variables)';
  RAISE NOTICE '   with actual CatalogItem IDs from your CatalogItems table.';
  RAISE NOTICE '';
  RAISE NOTICE '   You can find SKU IDs by running:';
  RAISE NOTICE '   SELECT id, sku, item_name FROM "CatalogItems" WHERE organization_id = ''%'' AND deleted = false;', v_org_id;

END $$;

