-- ====================================================
-- Migration: Add Cassette and Side Channel BOM Components with types
-- ====================================================
-- This adds BOMComponents for different cassette types and side channel positions
-- to the existing BOMTemplates
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
  v_bom_template_id uuid;
  v_cassette_standard_white_sku_id uuid := NULL;
  v_cassette_standard_black_sku_id uuid := NULL;
  v_cassette_recessed_white_sku_id uuid := NULL;
  v_cassette_recessed_black_sku_id uuid := NULL;
  v_cassette_surface_white_sku_id uuid := NULL;
  v_cassette_surface_black_sku_id uuid := NULL;
  v_cassette_end_cap_white_sku_id uuid := NULL;
  v_cassette_end_cap_black_sku_id uuid := NULL;
  v_side_channel_left_white_sku_id uuid := NULL;
  v_side_channel_left_black_sku_id uuid := NULL;
  v_side_channel_right_white_sku_id uuid := NULL;
  v_side_channel_right_black_sku_id uuid := NULL;
  v_side_channel_both_white_sku_id uuid := NULL;
  v_side_channel_both_black_sku_id uuid := NULL;
BEGIN
  RAISE NOTICE '🔧 Adding Cassette and Side Channel BOM Components with types...';
  RAISE NOTICE '';

  -- Get organization ID
  SELECT id INTO v_org_id
  FROM "Organizations"
  WHERE deleted = false
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'No active organization found';
  END IF;

  -- Process all BOMTemplates for Roller, Dual, and Triple Shades
  FOR v_bom_template_id IN
    SELECT bt.id
    FROM "BOMTemplates" bt
    INNER JOIN "ProductTypes" pt ON bt.product_type_id = pt.id
    WHERE bt.organization_id = v_org_id
    AND bt.deleted = false
    AND pt.deleted = false
    AND (pt.name ILIKE '%roller%shade%' 
         OR pt.name ILIKE '%dual%shade%' 
         OR pt.name ILIKE '%triple%shade%')
  LOOP
    RAISE NOTICE '  Processing BOMTemplate: %', v_bom_template_id;

    -- ====================================================
    -- CASSETTE COMPONENTS (with types)
    -- ====================================================
    
    -- Cassette Standard - White
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'cassette', '{"cassette": true, "cassette_type": "standard"}'::jsonb,
      'cassette_profile', v_cassette_standard_white_sku_id, 1, 'linear_m',
      true, 'white', 'direct', CASE WHEN v_cassette_standard_white_sku_id IS NULL THEN true ELSE false END, 1, false
    )
    ON CONFLICT DO NOTHING;

    -- Cassette Standard - Black
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'cassette', '{"cassette": true, "cassette_type": "standard"}'::jsonb,
      'cassette_profile', v_cassette_standard_black_sku_id, 1, 'linear_m',
      true, 'black', 'direct', CASE WHEN v_cassette_standard_black_sku_id IS NULL THEN true ELSE false END, 1, false
    )
    ON CONFLICT DO NOTHING;

    -- Cassette Recessed - White
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'cassette', '{"cassette": true, "cassette_type": "recessed"}'::jsonb,
      'cassette_profile', v_cassette_recessed_white_sku_id, 1, 'linear_m',
      true, 'white', 'direct', CASE WHEN v_cassette_recessed_white_sku_id IS NULL THEN true ELSE false END, 1, false
    )
    ON CONFLICT DO NOTHING;

    -- Cassette Recessed - Black
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'cassette', '{"cassette": true, "cassette_type": "recessed"}'::jsonb,
      'cassette_profile', v_cassette_recessed_black_sku_id, 1, 'linear_m',
      true, 'black', 'direct', CASE WHEN v_cassette_recessed_black_sku_id IS NULL THEN true ELSE false END, 1, false
    )
    ON CONFLICT DO NOTHING;

    -- Cassette Surface - White
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'cassette', '{"cassette": true, "cassette_type": "surface"}'::jsonb,
      'cassette_profile', v_cassette_surface_white_sku_id, 1, 'linear_m',
      true, 'white', 'direct', CASE WHEN v_cassette_surface_white_sku_id IS NULL THEN true ELSE false END, 1, false
    )
    ON CONFLICT DO NOTHING;

    -- Cassette Surface - Black
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'cassette', '{"cassette": true, "cassette_type": "surface"}'::jsonb,
      'cassette_profile', v_cassette_surface_black_sku_id, 1, 'linear_m',
      true, 'black', 'direct', CASE WHEN v_cassette_surface_black_sku_id IS NULL THEN true ELSE false END, 1, false
    )
    ON CONFLICT DO NOTHING;

    -- Cassette End Caps (apply to all cassette types) - White
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'cassette', '{"cassette": true}'::jsonb,
      'cassette_end_cap', v_cassette_end_cap_white_sku_id, 2, 'unit',
      true, 'white', 'direct', CASE WHEN v_cassette_end_cap_white_sku_id IS NULL THEN true ELSE false END, 2, false
    )
    ON CONFLICT DO NOTHING;

    -- Cassette End Caps - Black
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'cassette', '{"cassette": true}'::jsonb,
      'cassette_end_cap', v_cassette_end_cap_black_sku_id, 2, 'unit',
      true, 'black', 'direct', CASE WHEN v_cassette_end_cap_black_sku_id IS NULL THEN true ELSE false END, 2, false
    )
    ON CONFLICT DO NOTHING;

    -- ====================================================
    -- SIDE CHANNEL COMPONENTS (with positions)
    -- ====================================================
    
    -- Side Channel Left - White
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'side_channel', '{"side_channel": true, "side_channel_type": "left"}'::jsonb,
      'side_channel_profile', v_side_channel_left_white_sku_id, 1, 'linear_m',
      true, 'white', 'direct', CASE WHEN v_side_channel_left_white_sku_id IS NULL THEN true ELSE false END, 1, false
    )
    ON CONFLICT DO NOTHING;

    -- Side Channel Left - Black
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'side_channel', '{"side_channel": true, "side_channel_type": "left"}'::jsonb,
      'side_channel_profile', v_side_channel_left_black_sku_id, 1, 'linear_m',
      true, 'black', 'direct', CASE WHEN v_side_channel_left_black_sku_id IS NULL THEN true ELSE false END, 1, false
    )
    ON CONFLICT DO NOTHING;

    -- Side Channel Right - White
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'side_channel', '{"side_channel": true, "side_channel_type": "right"}'::jsonb,
      'side_channel_profile', v_side_channel_right_white_sku_id, 1, 'linear_m',
      true, 'white', 'direct', CASE WHEN v_side_channel_right_white_sku_id IS NULL THEN true ELSE false END, 1, false
    )
    ON CONFLICT DO NOTHING;

    -- Side Channel Right - Black
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'side_channel', '{"side_channel": true, "side_channel_type": "right"}'::jsonb,
      'side_channel_profile', v_side_channel_right_black_sku_id, 1, 'linear_m',
      true, 'black', 'direct', CASE WHEN v_side_channel_right_black_sku_id IS NULL THEN true ELSE false END, 1, false
    )
    ON CONFLICT DO NOTHING;

    -- Side Channel Both - White (2x quantity for both sides)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'side_channel', '{"side_channel": true, "side_channel_type": "both"}'::jsonb,
      'side_channel_profile', v_side_channel_both_white_sku_id, 2, 'linear_m',
      true, 'white', 'direct', CASE WHEN v_side_channel_both_white_sku_id IS NULL THEN true ELSE false END, 1, false
    )
    ON CONFLICT DO NOTHING;

    -- Side Channel Both - Black (2x quantity for both sides)
    INSERT INTO "BOMComponents" (
      bom_template_id, organization_id, block_type, block_condition,
      component_role, component_item_id, qty_per_unit, uom,
      applies_color, hardware_color, sku_resolution_rule, auto_select, sequence_order, deleted
    )
    VALUES (
      v_bom_template_id, v_org_id, 'side_channel', '{"side_channel": true, "side_channel_type": "both"}'::jsonb,
      'side_channel_profile', v_side_channel_both_black_sku_id, 2, 'linear_m',
      true, 'black', 'direct', CASE WHEN v_side_channel_both_black_sku_id IS NULL THEN true ELSE false END, 1, false
    )
    ON CONFLICT DO NOTHING;

  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Added Cassette and Side Channel BOM Components with types!';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  IMPORTANT: Update the SKU IDs (v_*_sku_id variables)';
  RAISE NOTICE '   with actual CatalogItem IDs from your CatalogItems table.';

END $$;

