-- ============================================================================
-- Phase 8: Seed FabricRules for all product types
-- Only inserts if no rules exist for a given product type + org combo.
-- Uses the first organization found as target.
-- ============================================================================

DO $$
DECLARE
  v_org_id uuid;
  v_pt_roller uuid;
  v_pt_dual uuid;
  v_pt_triple uuid;
  v_pt_awning uuid;
  v_count int;
BEGIN
  -- Get first active organization
  SELECT id INTO v_org_id
  FROM "Organizations"
  WHERE deleted = false
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE NOTICE 'No organization found, skipping FabricRules seeds.';
    RETURN;
  END IF;

  -- Resolve product type IDs
  SELECT id INTO v_pt_roller FROM "ProductTypes" WHERE code = 'roller_shade' OR code = 'roller-shade' LIMIT 1;
  SELECT id INTO v_pt_dual FROM "ProductTypes" WHERE code = 'dual_shade' OR code = 'dual-shade' LIMIT 1;
  SELECT id INTO v_pt_triple FROM "ProductTypes" WHERE code = 'triple_shade' OR code = 'triple-shade' LIMIT 1;
  SELECT id INTO v_pt_awning FROM "ProductTypes" WHERE code = 'awning' LIMIT 1;

  -- Roller Shade: single drop, 15% waste, no hems
  IF v_pt_roller IS NOT NULL THEN
    SELECT COUNT(*) INTO v_count FROM "FabricRules" WHERE organization_id = v_org_id AND product_type_id = v_pt_roller;
    IF v_count = 0 THEN
      INSERT INTO "FabricRules" (
        organization_id, product_type_id, style_code, display_name, product_line,
        formula_code, height_multiplier, width_multiplier, fullness_factor,
        extra_height_m, extra_width_m, pricing_output_uom, waste_pct,
        round_to_increment, min_qty, top_hem_cm, bottom_hem_cm, side_hem_cm,
        fabric_orientation, is_active
      ) VALUES (
        v_org_id, v_pt_roller, NULL, 'Roller Drop', NULL,
        'ROLLER_DROPS', 1, 1, 1,
        0, 0, 'm', 0.15,
        0.01, 0, 0, 0, 0,
        'vertical', true
      );
      RAISE NOTICE 'Inserted FabricRule for Roller Shade.';
    ELSE
      RAISE NOTICE 'FabricRules already exist for Roller Shade (%), skipping.', v_count;
    END IF;
  END IF;

  -- Dual Shade: 2x width multiplier (two fabric layers), 15% waste
  IF v_pt_dual IS NOT NULL THEN
    SELECT COUNT(*) INTO v_count FROM "FabricRules" WHERE organization_id = v_org_id AND product_type_id = v_pt_dual;
    IF v_count = 0 THEN
      INSERT INTO "FabricRules" (
        organization_id, product_type_id, style_code, display_name, product_line,
        formula_code, height_multiplier, width_multiplier, fullness_factor,
        extra_height_m, extra_width_m, pricing_output_uom, waste_pct,
        round_to_increment, min_qty, top_hem_cm, bottom_hem_cm, side_hem_cm,
        fabric_orientation, is_active
      ) VALUES (
        v_org_id, v_pt_dual, NULL, 'Dual Shade Drop', NULL,
        'ROLLER_DROPS', 1, 2, 1,
        0, 0, 'm', 0.15,
        0.01, 0, 0, 0, 0,
        'vertical', true
      );
      RAISE NOTICE 'Inserted FabricRule for Dual Shade.';
    ELSE
      RAISE NOTICE 'FabricRules already exist for Dual Shade (%), skipping.', v_count;
    END IF;
  END IF;

  -- Triple Shade: 3x width multiplier (three fabric layers), 15% waste
  IF v_pt_triple IS NOT NULL THEN
    SELECT COUNT(*) INTO v_count FROM "FabricRules" WHERE organization_id = v_org_id AND product_type_id = v_pt_triple;
    IF v_count = 0 THEN
      INSERT INTO "FabricRules" (
        organization_id, product_type_id, style_code, display_name, product_line,
        formula_code, height_multiplier, width_multiplier, fullness_factor,
        extra_height_m, extra_width_m, pricing_output_uom, waste_pct,
        round_to_increment, min_qty, top_hem_cm, bottom_hem_cm, side_hem_cm,
        fabric_orientation, is_active
      ) VALUES (
        v_org_id, v_pt_triple, NULL, 'Triple Shade Drop', NULL,
        'ROLLER_DROPS', 1, 3, 1,
        0, 0, 'm', 0.15,
        0.01, 0, 0, 0, 0,
        'vertical', true
      );
      RAISE NOTICE 'Inserted FabricRule for Triple Shade.';
    ELSE
      RAISE NOTICE 'FabricRules already exist for Triple Shade (%), skipping.', v_count;
    END IF;
  END IF;

  -- Awning: area-based, 10% waste
  IF v_pt_awning IS NOT NULL THEN
    SELECT COUNT(*) INTO v_count FROM "FabricRules" WHERE organization_id = v_org_id AND product_type_id = v_pt_awning;
    IF v_count = 0 THEN
      INSERT INTO "FabricRules" (
        organization_id, product_type_id, style_code, display_name, product_line,
        formula_code, height_multiplier, width_multiplier, fullness_factor,
        extra_height_m, extra_width_m, pricing_output_uom, waste_pct,
        round_to_increment, min_qty, top_hem_cm, bottom_hem_cm, side_hem_cm,
        fabric_orientation, is_active
      ) VALUES (
        v_org_id, v_pt_awning, NULL, 'Awning Area', NULL,
        'AREA_BASED', 1, 1, 1,
        0, 0, 'm2', 0.10,
        0.01, 0, 0, 0, 0,
        'vertical', true
      );
      RAISE NOTICE 'Inserted FabricRule for Awning.';
    ELSE
      RAISE NOTICE 'FabricRules already exist for Awning (%), skipping.', v_count;
    END IF;
  END IF;
END $$;
