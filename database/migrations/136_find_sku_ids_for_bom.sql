-- ====================================================
-- Helper Script: Find SKU IDs for BOM Components
-- ====================================================
-- Run this script to find CatalogItem IDs that you need
-- to update in migration 135_create_block_based_bom_templates.sql
-- ====================================================

DO $$
DECLARE
  v_org_id uuid;
BEGIN
  -- Get organization ID
  SELECT id INTO v_org_id
  FROM "Organizations"
  WHERE deleted = false
  LIMIT 1;

  IF v_org_id IS NULL THEN
    RAISE EXCEPTION 'No active organization found';
  END IF;

  RAISE NOTICE '🔍 Finding SKU IDs for organization: %', v_org_id;
  RAISE NOTICE '';

  -- Motor components
  RAISE NOTICE '=== MOTOR COMPONENTS ===';
  RAISE NOTICE 'Motor SKU:';
  PERFORM id, sku, item_name FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku ILIKE '%motor%' OR item_name ILIKE '%motor%')
  ORDER BY sku;

  RAISE NOTICE '';
  RAISE NOTICE 'Motor Adapter SKU:';
  PERFORM id, sku, item_name FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku ILIKE '%adapter%motor%' OR item_name ILIKE '%adapter%motor%')
  ORDER BY sku;

  -- Manual components
  RAISE NOTICE '';
  RAISE NOTICE '=== MANUAL COMPONENTS ===';
  RAISE NOTICE 'Clutch SKU:';
  PERFORM id, sku, item_name FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku ILIKE '%clutch%' OR item_name ILIKE '%clutch%')
  ORDER BY sku;

  -- Brackets
  RAISE NOTICE '';
  RAISE NOTICE '=== BRACKETS ===';
  RAISE NOTICE 'Bracket SKUs (White):';
  PERFORM id, sku, item_name FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku ILIKE '%bracket%white%' OR sku ILIKE '%bracket%WH%' OR item_name ILIKE '%bracket%white%')
  ORDER BY sku;

  RAISE NOTICE '';
  RAISE NOTICE 'Bracket SKUs (Black):';
  PERFORM id, sku, item_name FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku ILIKE '%bracket%black%' OR sku ILIKE '%bracket%BK%' OR item_name ILIKE '%bracket%black%')
  ORDER BY sku;

  -- Tubes
  RAISE NOTICE '';
  RAISE NOTICE '=== TUBES ===';
  RAISE NOTICE 'Tube SKUs (42mm):';
  PERFORM id, sku, item_name FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku ILIKE '%tube%42%' OR sku ILIKE '%TUBE-42%' OR item_name ILIKE '%tube%42%')
  ORDER BY sku;

  RAISE NOTICE '';
  RAISE NOTICE 'Tube SKUs (65mm):';
  PERFORM id, sku, item_name FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku ILIKE '%tube%65%' OR sku ILIKE '%TUBE-65%' OR item_name ILIKE '%tube%65%')
  ORDER BY sku;

  RAISE NOTICE '';
  RAISE NOTICE 'Tube SKUs (80mm):';
  PERFORM id, sku, item_name FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku ILIKE '%tube%80%' OR sku ILIKE '%TUBE-80%' OR item_name ILIKE '%tube%80%')
  ORDER BY sku;

  -- Bottom Rails
  RAISE NOTICE '';
  RAISE NOTICE '=== BOTTOM RAILS ===';
  RAISE NOTICE 'Bottom Rail Profile SKUs:';
  PERFORM id, sku, item_name FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku ILIKE '%bottom%rail%' OR sku ILIKE '%bottomrail%' OR item_name ILIKE '%bottom%rail%')
  ORDER BY sku;

  -- Cassettes
  RAISE NOTICE '';
  RAISE NOTICE '=== CASSETTES ===';
  RAISE NOTICE 'Cassette Profile SKUs:';
  PERFORM id, sku, item_name FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku ILIKE '%cassette%' OR item_name ILIKE '%cassette%')
  ORDER BY sku;

  -- End Caps
  RAISE NOTICE '';
  RAISE NOTICE '=== END CAPS ===';
  RAISE NOTICE 'End Cap SKUs:';
  PERFORM id, sku, item_name FROM "CatalogItems"
  WHERE organization_id = v_org_id
  AND deleted = false
  AND (sku ILIKE '%end%cap%' OR sku ILIKE '%endcap%' OR item_name ILIKE '%end%cap%')
  ORDER BY sku;

  RAISE NOTICE '';
  RAISE NOTICE '✅ Search complete!';
  RAISE NOTICE '';
  RAISE NOTICE '📝 Copy the UUIDs from the results above and update';
  RAISE NOTICE '   the v_*_sku_id variables in migration 135.';

END $$;

